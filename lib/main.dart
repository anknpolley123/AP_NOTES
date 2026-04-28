import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const APNotesApp());
}

class APNotesApp extends StatefulWidget {
  const APNotesApp({super.key});
  @override
  State<APNotesApp> createState() => _APNotesAppState();
}

class _APNotesAppState extends State<APNotesApp> {
  bool _dark = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance()
        .then((p) => setState(() => _dark = p.getBool('dark') ?? false));
  }

  void _toggleTheme() async {
    final p = await SharedPreferences.getInstance();
    setState(() => _dark = !_dark);
    p.setBool('dark', _dark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AP NOTES',
      debugShowCheckedModeBanner: false,
      themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: HomeScreen(onToggleTheme: _toggleTheme, isDark: _dark),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2D6A4F),
        brightness: brightness,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        color: dark ? const Color(0xFF1E1E1E) : const Color(0xFFF8F8F5),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: dark ? const Color(0xFF121212) : const Color(0xFFF0F0EB),
        foregroundColor: dark ? Colors.white : const Color(0xFF1A1A1A),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: dark ? const Color(0xFF2A2A2A) : const Color(0xFFFFFFFF),
      ),
    );
  }
}

class Note {
  String id;
  String title;
  String content;
  String category;
  String colorHex;
  List<String> tags;
  bool isPinned;
  bool isFavorite;
  bool isArchived;
  DateTime createdAt;
  DateTime updatedAt;
  List<Map<String, dynamic>> history;

  Note({
    required this.id,
    this.title = '',
    this.content = '',
    this.category = 'General',
    this.colorHex = '#FFFFFF',
    this.tags = const [],
    this.isPinned = false,
    this.isFavorite = false,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
    this.history = const [],
  });

  Note copyWith({
    String? title,
    String? content,
    String? category,
    String? colorHex,
    List<String>? tags,
    bool? isPinned,
    bool? isFavorite,
    bool? isArchived,
    DateTime? updatedAt,
    List<Map<String, dynamic>>? history,
  }) =>
      Note(
        id: id,
        title: title ?? this.title,
        content: content ?? this.content,
        category: category ?? this.category,
        colorHex: colorHex ?? this.colorHex,
        tags: tags ?? List.from(this.tags),
        isPinned: isPinned ?? this.isPinned,
        isFavorite: isFavorite ?? this.isFavorite,
        isArchived: isArchived ?? this.isArchived,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        history: history ?? List.from(this.history),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'category': category,
        'colorHex': colorHex,
        'tags': tags,
        'isPinned': isPinned,
        'isFavorite': isFavorite,
        'isArchived': isArchived,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'history': history,
      };

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: j['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: j['title'] ?? '',
        content: j['content'] ?? '',
        category: j['category'] ?? 'General',
        colorHex: j['colorHex'] ?? '#FFFFFF',
        tags: List<String>.from(j['tags'] ?? []),
        isPinned: j['isPinned'] ?? false,
        isFavorite: j['isFavorite'] ?? false,
        isArchived: j['isArchived'] ?? false,
        createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(j['updatedAt'] ?? '') ?? DateTime.now(),
        history: List<Map<String, dynamic>>.from(j['history'] ?? []),
      );

  int get wordCount =>
      content.trim().isEmpty ? 0 : content.trim().split(RegExp(r'\s+')).length;
  int get charCount => content.length;
  int get readingMinutes => (wordCount / 200).ceil();
}

class NoteStorage {
  static const _key = 'ap_notes_v3';

  static Future<List<Note>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_key) ?? [];
    return raw.map((e) {
      try {
        return Note.fromJson(jsonDecode(e));
      } catch (_) {
        return null;
      }
    }).whereType<Note>().toList();
  }

  static Future<void> save(List<Note> notes) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
        _key, notes.map((n) => jsonEncode(n.toJson())).toList());
  }
}

class HomeScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;
  const HomeScreen({super.key, required this.onToggleTheme, required this.isDark});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  List<Note> _all = [];
  List<Note> _shown = [];
  final _search = TextEditingController();
  String _cat = 'All';
  String _sort = 'updated';
  bool _grid = false;
  bool _showArchived = false;
  bool _showFavorites = false;

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(_filter);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _all = await NoteStorage.load();
    _filter();
  }

  Future<void> _persist() async {
    await NoteStorage.save(_all);
    _filter();
  }

  void _filter() {
    final q = _search.text.toLowerCase();
    setState(() {
      _shown = _all.where((n) {
        if (!_showArchived && n.isArchived) return false;
        if (_showFavorites && !n.isFavorite) return false;
        if (_cat != 'All' && n.category != _cat) return false;
        if (q.isEmpty) return true;
        return n.title.toLowerCase().contains(q) ||
            n.content.toLowerCase().contains(q) ||
            n.tags.any((t) => t.toLowerCase().contains(q)) ||
            n.category.toLowerCase().contains(q);
      }).toList();

      _shown.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        switch (_sort) {
          case 'title':
            return a.title.toLowerCase().compareTo(b.title.toLowerCase());
          case 'created':
            return b.createdAt.compareTo(a.createdAt);
          case 'words':
            return b.wordCount.compareTo(a.wordCount);
          default:
            return b.updatedAt.compareTo(a.updatedAt);
        }
      });
    });
  }

  List<String> get _categories {
    final s = _all.map((n) => n.category).toSet().toList()..sort();
    return ['All', ...s];
  }

  Note _newNote() => Note(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  Future<void> _openEditor(Note note, {bool isNew = false}) async {
    final result = await Navigator.push<Note>(
      context,
      MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note, isNew: isNew)),
    );
    if (result != null) {
      if (isNew) {
        _all.insert(0, result);
      } else {
        final i = _all.indexWhere((n) => n.id == result.id);
        if (i != -1) _all[i] = result;
      }
      await _persist();
    }
  }

  Future<void> _deleteNote(Note note) async {
    final ok = await _confirmDialog('Delete "${note.title}"?', 'This cannot be undone.');
    if (ok) {
      _all.removeWhere((n) => n.id == note.id);
      await _persist();
    }
  }

  Future<void> _archiveNote(Note note) async {
    final i = _all.indexWhere((n) => n.id == note.id);
    if (i != -1) {
      _all[i] = note.copyWith(isArchived: !note.isArchived);
      await _persist();
    }
  }

  Future<void> _togglePin(Note note) async {
    final i = _all.indexWhere((n) => n.id == note.id);
    if (i != -1) {
      _all[i] = note.copyWith(isPinned: !note.isPinned);
      await _persist();
    }
  }

  Future<void> _toggleFavorite(Note note) async {
    final i = _all.indexWhere((n) => n.id == note.id);
    if (i != -1) {
      _all[i] = note.copyWith(isFavorite: !note.isFavorite);
      await _persist();
    }
  }

  Future<bool> _confirmDialog(String title, String body) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirm')),
            ],
          ),
        ) ??
        false;
  }

Future<void> _exportAllPDF() async {
    if (_all.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No notes to export.')));
      return;
    }
    final pdf = pw.Document();
    for (final n in _all.where((n) => !n.isArchived)) {
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (_) => [
          pw.Text(n.title.isEmpty ? 'Untitled' : n.title,
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Category: ${n.category}  •  Tags: ${n.tags.isEmpty ? 'none' : n.tags.join(', ')}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          pw.Text('Created: ${_fmt(n.createdAt)}  •  Updated: ${_fmt(n.updatedAt)}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          pw.Divider(height: 20),
          pw.Text(n.content, style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 30),
        ],
      ));
    }
    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  Future<void> _exportSinglePdf(Note n) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (_) => [
        pw.Text(n.title.isEmpty ? 'Untitled' : n.title,
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text('Category: ${n.category}  •  Tags: ${n.tags.isEmpty ? 'none' : n.tags.join(', ')}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.Text('Words: ${n.wordCount}  •  Chars: ${n.charCount}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.Divider(height: 24),
        pw.Text(n.content, style: const pw.TextStyle(fontSize: 13)),
      ],
    ));
    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  void _showCommandPalette() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _CommandPalette(
        onAction: (action) {
          Navigator.pop(context);
          switch (action) {
            case 'new':
              _openEditor(_newNote(), isNew: true);
              break;
            case 'export_all':
              _exportAllPDF();
              break;
            case 'theme':
              widget.onToggleTheme();
              break;
            case 'favorites':
              setState(() => _showFavorites = !_showFavorites);
              _filter();
              break;
            case 'archived':
              setState(() => _showArchived = !_showArchived);
              _filter();
              break;
            case 'grid':
              setState(() => _grid = !_grid);
              break;
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pinned = _shown.where((n) => n.isPinned).toList();
    final unpinned = _shown.where((n) => !n.isPinned).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('AP NOTES',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Command Palette',
            onPressed: _showCommandPalette,
          ),
          IconButton(
            icon: Icon(_grid ? Icons.view_list_rounded : Icons.grid_view_rounded),
            onPressed: () => setState(() => _grid = !_grid),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune),
            onSelected: (v) {
              if (v.startsWith('sort_')) {
                setState(() => _sort = v.replaceFirst('sort_', ''));
                _filter();
              } else if (v == 'favorites') {
                setState(() => _showFavorites = !_showFavorites);
                _filter();
              } else if (v == 'archived') {
                setState(() => _showArchived = !_showArchived);
                _filter();
              } else if (v == 'export_all') {
                _exportAllPDF();
              } else if (v == 'theme') {
                widget.onToggleTheme();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'sort_updated', child: Text('Sort: Last Modified')),
              const PopupMenuItem(value: 'sort_created', child: Text('Sort: Date Created')),
              const PopupMenuItem(value: 'sort_title', child: Text('Sort: Title A-Z')),
              const PopupMenuItem(value: 'sort_words', child: Text('Sort: Word Count')),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'favorites',
                  child: Text(_showFavorites ? '✓ Favorites Only' : 'Show Favorites')),
              PopupMenuItem(value: 'archived',
                  child: Text(_showArchived ? '✓ Show Archived' : 'Show Archived')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'export_all', child: Text('Export All as PDF')),
              PopupMenuItem(value: 'theme',
                  child: Text(widget.isDark ? 'Light Mode' : 'Dark Mode')),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: 'Search notes, tags, content...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _search.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () { _search.clear(); _filter(); })
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              SizedBox(
                height: 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _categories.length,
                  itemBuilder: (_, i) {
                    final c = _categories[i];
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(c, style: const TextStyle(fontSize: 12)),
                        selected: _cat == c,
                        onSelected: (_) { setState(() => _cat = c); _filter(); },
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
      body: _shown.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sticky_note_2_outlined,
                      size: 72, color: theme.colorScheme.primary.withAlpha(80)),
                  const SizedBox(height: 16),
                  Text('No notes here', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text('Tap + New Note to get started',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            )
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text('${_shown.length} note${_shown.length == 1 ? '' : 's'}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                  ),
                ),
                if (pinned.isNotEmpty) ...[
                  const SliverToBoxAdapter(child: _SectionHeader(label: '📌 Pinned')),
                  _buildNoteSliver(pinned),
                ],
                if (unpinned.isNotEmpty) ...[
                  if (pinned.isNotEmpty)
                    const SliverToBoxAdapter(child: _SectionHeader(label: 'Notes')),
                  _buildNoteSliver(unpinned),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(_newNote(), isNew: true),
        icon: const Icon(Icons.edit_note),
        label: const Text('New Note'),
      ),
    );
  }

  Widget _buildNoteSliver(List<Note> list) {
    if (_grid) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate(
            (_, i) => _GridCard(
              note: list[i],
              onTap: () => _openEditor(list[i]),
              onPin: () => _togglePin(list[i]),
              onFavorite: () => _toggleFavorite(list[i]),
              onArchive: () => _archiveNote(list[i]),
              onDelete: () => _deleteNote(list[i]),
              onExportPdf: () => _exportSinglePdf(list[i]),
            ),
            childCount: list.length,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.8,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) => _ListCard(
            note: list[i],
            onTap: () => _openEditor(list[i]),
            onPin: () => _togglePin(list[i]),
            onFavorite: () => _toggleFavorite(list[i]),
            onArchive: () => _archiveNote(list[i]),
            onDelete: () => _deleteNote(list[i]),
            onExportPdf: () => _exportSinglePdf(list[i]),
            fmt: _fmt,
          ),
          childCount: list.length,
        ),
      ),
    );
  }
}

class _CommandPalette extends StatefulWidget {
  final void Function(String action) onAction;
  const _CommandPalette({required this.onAction});
  @override
  State<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<_CommandPalette> {
  final _ctrl = TextEditingController();
  final _actions = [
    {'id': 'new', 'label': '+ New Note', 'icon': Icons.add},
    {'id': 'export_all', 'label': 'Export All as PDF', 'icon': Icons.picture_as_pdf},
    {'id': 'favorites', 'label': 'Toggle Favorites Filter', 'icon': Icons.favorite_outline},
    {'id': 'archived', 'label': 'Toggle Archived Notes', 'icon': Icons.archive_outlined},
    {'id': 'grid', 'label': 'Toggle Grid / List View', 'icon': Icons.grid_view},
    {'id': 'theme', 'label': 'Toggle Dark / Light Mode', 'icon': Icons.contrast},
  ];
  List<Map<String, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = List.from(_actions);
    _ctrl.addListener(() {
      final q = _ctrl.text.toLowerCase();
      setState(() {
        _filtered = q.isEmpty
            ? List.from(_actions)
            : _actions
                .where((a) => (a['label'] as String).toLowerCase().contains(q))
                .toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 80),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Type an action… (e.g. Export, Dark Mode)',
                prefixIcon: Icon(Icons.terminal),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const Divider(height: 0),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final a = _filtered[i];
                return ListTile(
                  leading: Icon(a['icon'] as IconData, size: 20),
                  title: Text(a['label'] as String),
                  onTap: () => widget.onAction(a['id'] as String),
                  dense: true,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8)),
      );
}

Color _hex(String hex) {
  try {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  } catch (_) {
    return Colors.white;
  }
}

class _ListCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap, onPin, onFavorite, onArchive, onDelete, onExportPdf;
  final String Function(DateTime) fmt;

  const _ListCard({
    required this.note,
    required this.onTap,
    required this.onPin,
    required this.onFavorite,
    required this.onArchive,
    required this.onDelete,
    required this.onExportPdf,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final bg = _hex(note.colorHex);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? bg.withAlpha(30) : bg.withAlpha(200);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: cardBg,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (note.isPinned)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.push_pin, size: 14, color: Colors.deepOrange),
                          ),
                        if (note.isFavorite)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.favorite, size: 14, color: Colors.pink),
                          ),
                        Expanded(
                          child: Text(
                            note.title.isEmpty ? 'Untitled' : note.title,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(note.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface.withAlpha(160))),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: [
                        _Pill(note.category),
                        ...note.tags.take(2).map((t) => _Pill('#$t')),
                        if (note.tags.length > 2) _Pill('+${note.tags.length - 2}'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${note.wordCount} words  •  ${fmt(note.updatedAt)}',
                      style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outline),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (v) {
                  if (v == 'pin') onPin();
                  if (v == 'fav') onFavorite();
                  if (v == 'pdf') onExportPdf();
                  if (v == 'archive') onArchive();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'pin', child: Text(note.isPinned ? 'Unpin' : 'Pin')),
                  PopupMenuItem(value: 'fav',
                      child: Text(note.isFavorite ? 'Unfavorite' : 'Add to Favorites')),
                  const PopupMenuItem(value: 'pdf', child: Text('Export as PDF')),
                  PopupMenuItem(value: 'archive',
                      child: Text(note.isArchived ? 'Unarchive' : 'Archive')),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'delete',
                      child: Text('Delete', style: TextStyle(color: Colors.red))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap, onPin, onFavorite, onArchive, onDelete, onExportPdf;
  const _GridCard({
    required this.note,
    required this.onTap,
    required this.onPin,
    required this.onFavorite,
    required this.onArchive,
    required this.onDelete,
    required this.onExportPdf,
  });

  @override
  Widget build(BuildContext context) {
    final bg = _hex(note.colorHex);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? bg.withAlpha(30) : bg.withAlpha(200),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDark ? Colors.white12 : Colors.black12, width: 0.5),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (note.isPinned)
                const Icon(Icons.push_pin, size: 12, color: Colors.deepOrange),
              if (note.isFavorite)
                const Icon(Icons.favorite, size: 12, color: Colors.pink),
              Expanded(
                child: Text(
                  note.title.isEmpty ? 'Untitled' : note.title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Expanded(
              child: Text(note.content,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(150)),
                  overflow: TextOverflow.fade),
            ),
            const SizedBox(height: 6),
            _Pill(note.category),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${note.wordCount}w',
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, size: 16),
                  padding: EdgeInsets.zero,
                  onSelected: (v) {
                    if (v == 'pin') onPin();
                    if (v == 'fav') onFavorite();
                    if (v == 'pdf') onExportPdf();
                    if (v == 'archive') onArchive();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'pin', child: Text(note.isPinned ? 'Unpin' : 'Pin')),
                    PopupMenuItem(value: 'fav',
                        child: Text(note.isFavorite ? 'Unfavorite' : 'Favorite')),
                    const PopupMenuItem(value: 'pdf', child: Text('Export PDF')),
                    PopupMenuItem(value: 'archive',
                        child: Text(note.isArchived ? 'Unarchive' : 'Archive')),
                    const PopupMenuItem(value: 'delete',
                        child: Text('Delete', style: TextStyle(color: Colors.red))),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  const _Pill(this.label);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withAlpha(25),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600)),
      );
}

const List<String> kCategories = [
  'General', 'Work', 'Study', 'Personal',
  'Ideas', 'Todo', 'Health', 'Finance', 'Travel',
];

const List<Map<String, dynamic>> kColors = [
  {'hex': '#FFFFFF', 'name': 'White'},
  {'hex': '#FFF3E0', 'name': 'Peach'},
  {'hex': '#E8F5E9', 'name': 'Mint'},
  {'hex': '#E3F2FD', 'name': 'Sky'},
  {'hex': '#F3E5F5', 'name': 'Lavender'},
  {'hex': '#FCE4EC', 'name': 'Rose'},
  {'hex': '#FFFDE7', 'name': 'Lemon'},
  {'hex': '#E0F2F1', 'name': 'Teal'},
];

class NoteEditorScreen extends StatefulWidget {
  final Note note;
  final bool isNew;
  const NoteEditorScreen({super.key, required this.note, required this.isNew});
  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late TextEditingController _title;
  late TextEditingController _body;
  late TextEditingController _tagInput;
  late String _category;
  late String _colorHex;
  late List<String> _tags;
  late List<Map<String, dynamic>> _history;
  bool _focusMode = false;
  bool _changed = false;
  bool _showMeta = true;

  @override
  void initState() {
    super.initState();
    final n = widget.note;
    _title = TextEditingController(text: n.title);
    _body = TextEditingController(text: n.content);
    _tagInput = TextEditingController();
    _category = n.category;
    _colorHex = n.colorHex;
    _tags = List.from(n.tags);
    _history = List.from(n.history);
    _title.addListener(() => _changed = true);
    _body.addListener(() { _changed = true; setState(() {}); });
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _tagInput.dispose();
    super.dispose();
  }

  Note _buildNote() => widget.note.copyWith(
        title: _title.text.trim().isEmpty ? 'Untitled' : _title.text.trim(),
        content: _body.text,
        category: _category,
        colorHex: _colorHex,
        tags: _tags,
        updatedAt: DateTime.now(),
        history: _history,
      );

  void _save() {
    if (_changed && widget.note.content.isNotEmpty) {
      _history = [
        {
          'content': widget.note.content,
          'title': widget.note.title,
          'savedAt': DateTime.now().toIso8601String(),
        },
        ..._history.take(9),
      ];
    }
    Navigator.pop(context, _buildNote());
  }

  Future<bool> _onBack() async {
    if (!_changed) return true;
    final res = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Unsaved Changes'),
        content: const Text('Would you like to save your note?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, 'discard'),
              child: const Text('Discard')),
          FilledButton(
              onPressed: () => Navigator.pop(context, 'save'),
              child: const Text('Save')),
        ],
      ),
    );
    if (res == 'save') { _save(); return false; }
    return res == 'discard';
  }

  void _addTag() {
    final t = _tagInput.text.trim();
    if (t.isNotEmpty && !_tags.contains(t)) {
      setState(() { _tags.add(t); _tagInput.clear(); _changed = true; });
    }
  }

  void _copyContent() {
    Clipboard.setData(ClipboardData(text: _body.text));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Copied to clipboard.')));
  }

  void _showHistory() {
    if (_history.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No version history yet.')));
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Version History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _history.length,
              itemBuilder: (_, i) {
                final v = _history[i];
                final dt = DateTime.tryParse(v['savedAt'] ?? '');
                return ListTile(
                  title: Text(v['title'] ?? 'Untitled',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(dt != null
                      ? '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}'
                      : 'Unknown time'),
                  trailing: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        _body.text = v['content'] ?? '';
                        _title.text = v['title'] ?? '';
                        _changed = true;
                      });
                    },
                    child: const Text('Restore'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPDF() async {
    final n = _buildNote();
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (_) => [
        pw.Text(n.title,
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text('Category: ${n.category}  •  Tags: ${n.tags.isEmpty ? 'none' : n.tags.join(', ')}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.Text('Words: ${n.wordCount}  •  Chars: ${n.charCount}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.Divider(height: 24),
        pw.Text(n.content, style: const pw.TextStyle(fontSize: 13)),
      ],
    ));
    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

@override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = _hex(_colorHex);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? bg.withAlpha(20) : bg.withAlpha(220);
    final wordCount = _body.text.trim().isEmpty
        ? 0 : _body.text.trim().split(RegExp(r'\s+')).length;
    final charCount = _body.text.length;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final ok = await _onBack();
        if (ok && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: cardBg,
        appBar: _focusMode
            ? null
            : AppBar(
                backgroundColor: cardBg,
                title: TextField(
                  controller: _title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(
                    hintText: 'Note title…',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.visibility_off_outlined),
                    tooltip: 'Focus Mode',
                    onPressed: () => setState(() => _focusMode = true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.history),
                    tooltip: 'Version History',
                    onPressed: _showHistory,
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_outlined),
                    tooltip: 'Copy Content',
                    onPressed: _copyContent,
                  ),
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    tooltip: 'Export PDF',
                    onPressed: _exportPDF,
                  ),
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline),
                    tooltip: 'Save',
                    onPressed: _save,
                  ),
                ],
              ),
        body: Column(
          children: [
            if (_focusMode)
              GestureDetector(
                onTap: () => setState(() => _focusMode = false),
                child: Container(
                  color: theme.colorScheme.surface.withAlpha(200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.visibility_outlined,
                          size: 16, color: theme.colorScheme.outline),
                      const SizedBox(width: 6),
                      Text('Focus Mode — tap to exit',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.outline)),
                      const Spacer(),
                      TextButton(onPressed: _save, child: const Text('Save & Exit')),
                    ],
                  ),
                ),
              ),
            if (!_focusMode && _showMeta)
              Container(
                color: cardBg,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        DropdownButton<String>(
                          value: _category,
                          isDense: true,
                          underline: const SizedBox(),
                          borderRadius: BorderRadius.circular(8),
                          items: kCategories
                              .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c, style: const TextStyle(fontSize: 13))))
                              .toList(),
                          onChanged: (v) => setState(() { _category = v!; _changed = true; }),
                        ),
                        const SizedBox(width: 12),
                        const Text('Color:', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 6),
                        ...kColors.map((c) {
                          final selected = _colorHex == c['hex'];
                          return GestureDetector(
                            onTap: () => setState(() { _colorHex = c['hex'] as String; _changed = true; }),
                            child: Container(
                              width: 20, height: 20,
                              margin: const EdgeInsets.only(right: 5),
                              decoration: BoxDecoration(
                                color: _hex(c['hex'] as String),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selected
                                      ? theme.colorScheme.primary
                                      : Colors.grey.shade400,
                                  width: selected ? 2.5 : 1,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        ..._tags.map((t) => InputChip(
                              label: Text('#$t', style: const TextStyle(fontSize: 11)),
                              onDeleted: () => setState(() { _tags.remove(t); _changed = true; }),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            )),
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: _tagInput,
                            decoration: const InputDecoration(
                              hintText: '+ add tag',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            style: const TextStyle(fontSize: 12),
                            onSubmitted: (_) => _addTag(),
                          ),
                        ),
                        GestureDetector(
                          onTap: _addTag,
                          child: const Icon(Icons.add_circle_outline, size: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (!_focusMode) const Divider(height: 0),
            if (!_focusMode) _AdaptiveToolbar(controller: _body),
            if (!_focusMode) const Divider(height: 0),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: _focusMode ? 24 : 16,
                    vertical: _focusMode ? 24 : 10),
                child: TextField(
                  controller: _body,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: TextStyle(
                      fontSize: _focusMode ? 17 : 15,
                      height: _focusMode ? 1.9 : 1.65),
                  decoration: InputDecoration(
                    hintText: _focusMode ? 'Write freely…' : 'Start writing your note…',
                    border: InputBorder.none,
                    filled: false,
                  ),
                ),
              ),
            ),
            Container(
              color: theme.colorScheme.surface.withAlpha(180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text('$wordCount words',
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.outline)),
                  const SizedBox(width: 10),
                  Text('$charCount chars',
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.outline)),
                  const SizedBox(width: 10),
                  Text('~${(wordCount / 200).ceil()} min read',
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.outline)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _showMeta = !_showMeta),
                    child: Text(_showMeta ? 'Hide details' : 'Show details',
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.primary)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdaptiveToolbar extends StatelessWidget {
  final TextEditingController controller;
  const _AdaptiveToolbar({required this.controller});

  void _insertWrap(String before, String after) {
    final text = controller.text;
    final sel = controller.selection;
    if (!sel.isValid) return;
    final selected = sel.textInside(text);
    final newText = text.replaceRange(sel.start, sel.end, '$before$selected$after');
    controller.value = controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(
          offset: sel.start + before.length + selected.length + after.length),
    );
  }

  void _insertLine(String prefix) {
    final text = controller.text;
    final sel = controller.selection;
    if (!sel.isValid) return;
    final lineStart = text.lastIndexOf('\n', sel.start - 1) + 1;
    final newText = text.replaceRange(lineStart, lineStart, prefix);
    controller.value = controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: sel.start + prefix.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _ToolBtn('B', tooltip: 'Bold', onTap: () => _insertWrap('**', '**')),
          _ToolBtn('I', tooltip: 'Italic', onTap: () => _insertWrap('_', '_')),
          _ToolBtn('S̶', tooltip: 'Strikethrough', onTap: () => _insertWrap('~~', '~~')),
          _ToolBtn('`', tooltip: 'Inline code', onTap: () => _insertWrap('`', '`')),
          const VerticalDivider(width: 10),
          _ToolBtn('H1', tooltip: 'Heading 1', onTap: () => _insertLine('# ')),
          _ToolBtn('H2', tooltip: 'Heading 2', onTap: () => _insertLine('## ')),
          _ToolBtn('H3', tooltip: 'Heading 3', onTap: () => _insertLine('### ')),
          const VerticalDivider(width: 10),
          _ToolBtn('• ', tooltip: 'Bullet List', onTap: () => _insertLine('- ')),
          _ToolBtn('1.', tooltip: 'Numbered List', onTap: () => _insertLine('1. ')),
          _ToolBtn('☐', tooltip: 'Checkbox', onTap: () => _insertLine('- [ ] ')),
          const VerticalDivider(width: 10),
          _ToolBtn('—', tooltip: 'Divider', onTap: () {
            final pos = controller.selection.end;
            if (pos < 0) return;
            final text = controller.text;
            controller.value = controller.value.copyWith(
              text: text.replaceRange(pos, pos, '\n---\n'),
              selection: TextSelection.collapsed(offset: pos + 5),
            );
          }),
          _ToolBtn('"…"', tooltip: 'Blockquote', onTap: () => _insertLine('> ')),
        ],
      ),
    );
  }
}

class _ToolBtn extends StatelessWidget {
  final String label;
  final String tooltip;
  final VoidCallback onTap;
  const _ToolBtn(this.label, {required this.tooltip, required this.onTap});
  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      );
}


import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signature/signature.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AP NOTES',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      home: const NotesDashboard(),
    );
  }
}

// ── Model ──────────────────────────────────────────────────────────────────────

class NoteModel {
  String id;
  String title;
  String content;
  String folder;
  List<String> tags;
  DateTime createdAt;
  DateTime updatedAt;
  bool isPinned;
  List<String> history;

  NoteModel({
    required this.id,
    required this.title,
    required this.content,
    this.folder = 'General',
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isPinned = false,
    List<String>? history,
  })  : tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        history = history ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'folder': folder,
        'tags': tags,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isPinned': isPinned,
        'history': history,
      };

  factory NoteModel.fromJson(Map<String, dynamic> j) => NoteModel(
        id: j['id'] ?? '',
        title: j['title'] ?? '',
        content: j['content'] ?? '',
        folder: j['folder'] ?? 'General',
        tags: List<String>.from(j['tags'] ?? []),
        createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(j['updatedAt'] ?? '') ?? DateTime.now(),
        isPinned: j['isPinned'] ?? false,
        history: List<String>.from(j['history'] ?? []),
      );
}

// ── Dashboard ──────────────────────────────────────────────────────────────────

class NotesDashboard extends StatefulWidget {
  const NotesDashboard({super.key});

  @override
  State<NotesDashboard> createState() => _NotesDashboardState();
}

class _NotesDashboardState extends State<NotesDashboard> {
  List<NoteModel> _notes = [];
  List<NoteModel> _filtered = [];
  String _selectedFolder = 'All';
  String _searchQuery = '';
  bool _gridView = false;
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(() {
      _searchQuery = _search.text;
      _applyFilter();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<String> get _folders {
    final f = _notes.map((n) => n.folder).toSet().toList()..sort();
    return ['All', ...f];
  }

  void _applyFilter() {
    setState(() {
      _filtered = _notes.where((n) {
        final matchFolder =
            _selectedFolder == 'All' || n.folder == _selectedFolder;
        final q = _searchQuery.toLowerCase();
        final matchSearch = q.isEmpty ||
            n.title.toLowerCase().contains(q) ||
            n.content.toLowerCase().contains(q) ||
            n.tags.any((t) => t.toLowerCase().contains(q));
        return matchFolder && matchSearch;
      }).toList()
        ..sort((a, b) {
          if (a.isPinned && !b.isPinned) return -1;
          if (!a.isPinned && b.isPinned) return 1;
          return b.updatedAt.compareTo(a.updatedAt);
        });
    });
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList('notes_v2') ?? [];
    _notes = raw.map((e) => NoteModel.fromJson(jsonDecode(e))).toList();
    _applyFilter();
  }

  Future<void> _saveAll() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
        'notes_v2', _notes.map((n) => jsonEncode(n.toJson())).toList());
  }

  Future<void> _upsertNote(NoteModel note) async {
    final idx = _notes.indexWhere((n) => n.id == note.id);
    if (idx >= 0) {
      _notes[idx] = note;
    } else {
      _notes.insert(0, note);
    }
    await _saveAll();
    _applyFilter();
  }

  Future<void> _deleteNote(String id) async {
    _notes.removeWhere((n) => n.id == id);
    await _saveAll();
    _applyFilter();
  }

  void _togglePin(NoteModel note) {
    note.isPinned = !note.isPinned;
    _upsertNote(note);
  }

  Future<void> _openEditor({NoteModel? note}) async {
    final result = await Navigator.push<NoteModel>(
      context,
      MaterialPageRoute(builder: (_) => Editor(existing: note)),
    );
    if (result != null) await _upsertNote(result);
  }

  Future<void> _addFolder() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Folder name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Create')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      setState(() => _selectedFolder = name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        title: const Text('AP NOTES',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
        actions: [
          IconButton(
            icon: Icon(_gridView ? Icons.list : Icons.grid_view),
            onPressed: () => setState(() => _gridView = !_gridView),
          ),
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: _addFolder,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _search,
              style: TextStyle(color: scheme.onPrimary),
              decoration: InputDecoration(
                hintText: 'Search notes, tags...',
                hintStyle:
                    TextStyle(color: scheme.onPrimary.withOpacity(0.6)),
                prefixIcon: Icon(Icons.search, color: scheme.onPrimary),
                filled: true,
                fillColor: scheme.primary.withOpacity(0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              itemCount: _folders.length,
              itemBuilder: (_, i) {
                final f = _folders[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(f),
                    selected: _selectedFolder == f,
                    onSelected: (_) {
                      setState(() => _selectedFolder = f);
                      _applyFilter();
                    },
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.note_outlined,
                            size: 64,
                            color: scheme.onSurface.withOpacity(0.3)),
                        const SizedBox(height: 12),
                        Text('No notes found',
                            style: TextStyle(
                                color: scheme.onSurface.withOpacity(0.5))),
                      ],
                    ),
                  )
                : _gridView
                    ? GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) => _NoteCard(
                          note: _filtered[i],
                          onTap: () => _openEditor(note: _filtered[i]),
                          onDelete: () => _deleteNote(_filtered[i].id),
                          onPin: () => _togglePin(_filtered[i]),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) => _NoteCard(
                          note: _filtered[i],
                          onTap: () => _openEditor(note: _filtered[i]),
                          onDelete: () => _deleteNote(_filtered[i].id),
                          onPin: () => _togglePin(_filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('New Note'),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final NoteModel note;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onPin;

  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.onDelete,
    required this.onPin,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fmt = DateFormat('MMM d, yyyy');
    return Card(
      elevation: note.isPinned ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: note.isPinned
            ? BorderSide(color: scheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.title.isEmpty ? 'Untitled' : note.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (note.isPinned)
                    Icon(Icons.push_pin, size: 14, color: scheme.primary),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                note.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withOpacity(0.6)),
              ),
              const Spacer(),
              if (note.tags.isNotEmpty)
                Wrap(
                  spacing: 4,
                  children: note.tags
                      .take(3)
                      .map((t) => Chip(
                            label: Text(t,
                                style: const TextStyle(fontSize: 9)),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ))
                      .toList(),
                ),
              Row(
                children: [
                  Text(
                    fmt.format(note.updatedAt),
                    style: TextStyle(
                        fontSize: 10,
                        color: scheme.onSurface.withOpacity(0.4)),
                  ),
                  const Spacer(),
                  InkWell(
                      onTap: onPin,
                      child: const Icon(Icons.push_pin_outlined, size: 16)),
                  const SizedBox(width: 4),
                  InkWell(
                      onTap: onDelete,
                      child: const Icon(Icons.delete_outline, size: 16)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Editor extends StatefulWidget {
  final NoteModel? existing;
  const Editor({super.key, this.existing});

  @override
  State<Editor> createState() => _EditorState();
}

class _EditorState extends State<Editor> with SingleTickerProviderStateMixin {
  final TextEditingController _contentCtrl = TextEditingController();
  final SignatureController _sign =
      SignatureController(penStrokeWidth: 3, penColor: Colors.black);

  late TabController _tabs;
  late TextEditingController _titleCtrl;
  late TextEditingController _tagsCtrl;
  late TextEditingController _folderCtrl;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
    _tagsCtrl =
        TextEditingController(text: widget.existing?.tags.join(', ') ?? '');
    _folderCtrl =
        TextEditingController(text: widget.existing?.folder ?? 'General');
    _contentCtrl = TextEditingController(text: widget.existing?.content ?? '');
  }

  @override
  void dispose() {
    _tabs.dispose();
    _sign.dispose();
    _titleCtrl.dispose();
    _tagsCtrl.dispose();
    _folderCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final plain = _contentCtrl.text.trim();
    final existing = widget.existing;

    final note = NoteModel(
      id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleCtrl.text.trim().isEmpty
          ? (plain.length > 40 ? '${plain.substring(0, 40)}...' : plain)
          : _titleCtrl.text.trim(),
      content: plain,
      folder: _folderCtrl.text.trim().isEmpty
          ? 'General'
          : _folderCtrl.text.trim(),
      tags: _tagsCtrl.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList(),
      updatedAt: DateTime.now(),
      createdAt: existing?.createdAt ?? DateTime.now(),
      isPinned: existing?.isPinned ?? false,
      history: [plain, ...(existing?.history ?? [])].take(20).toList(),
    );

    Navigator.pop(context, note);
  }

  Future<void> _exportPDF() async {
    final doc = pw.Document();
    final title =
        _titleCtrl.text.trim().isEmpty ? 'Untitled' : _titleCtrl.text.trim();
    final plain = _contentCtrl.text.trim();

    doc.addPage(
      pw.MultiPage(
        build: (ctx) => [
          pw.Header(
              level: 0,
              child: pw.Text(title,
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 12),
          pw.Text(plain),
          pw.SizedBox(height: 12),
          pw.Text('Folder: ${_folderCtrl.text}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
          if (_tagsCtrl.text.isNotEmpty)
            pw.Text('Tags: ${_tagsCtrl.text}',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
        ],
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('AP NOTES — Ankon Polley',
                style: const pw.TextStyle(fontSize: 10)),
            pw.Text('Page ${ctx.pageNumber}/${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  void _showHistory() {
    final history = widget.existing?.history ?? [];
    if (history.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No version history yet')));
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView.builder(
        itemCount: history.length,
        itemBuilder: (_, i) {
          final ver = history[i];
          final preview = ver.length > 60 ? '${ver.substring(0, 60)}...' : ver;
          return ListTile(
            leading: CircleAvatar(child: Text('${history.length - i}')),
            title: Text(preview),
            subtitle: Text('Version ${history.length - i}'),
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _contentCtrl.text = ver;
              });
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _titleCtrl,
          decoration: const InputDecoration(
            hintText: 'Note title...',
            border: InputBorder.none,
          ),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.edit), text: 'Write'),
            Tab(icon: Icon(Icons.draw), text: 'Draw'),
            Tab(icon: Icon(Icons.info_outline), text: 'Meta'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Version History',
            onPressed: _showHistory,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export PDF',
            onPressed: _exportPDF,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save',
            onPressed: _save,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          Expanded(
            child: TextField(
              controller: _contentCtrl,
              maxLines: null,
              expands: true,
              decoration: const InputDecoration(
                hintText: 'Start writing your note...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _sign.clear,
                      icon: const Icon(Icons.delete_sweep),
                      label: const Text('Clear'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final bytes = await _sign.toPngBytes();
                        if (bytes == null) return;

                        showDialog(
                          context: context,
                          builder: (_) => Dialog(
                            child: Image.memory(bytes),
                          ),
                        );

                        final idx = _contentCtrl.selection.baseOffset < 0
                            ? 0
                            : _contentCtrl.selection.baseOffset;
                        _contentCtrl.text = _contentCtrl.text.substring(0, idx) +
                            '\n[Drawing inserted - ${DateTime.now().toIso8601String()}]\n' +
                            _contentCtrl.text.substring(idx);

                        _tabs.animateTo(0);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Drawing added to note')),
                          );
                        }
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Insert to Note'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Signature(
                  controller: _sign,
                  backgroundColor: Colors.white,
                ),
              ),
            ],
          ),
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Folder',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: _folderCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Work, Study, Personal',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.folder_outlined),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Tags (comma-separated)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: _tagsCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. flutter, dart, important',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.tag),
                ),
              ),
              const SizedBox(height: 20),
              if (widget.existing != null) ...[
                const Text('Info',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                ListTile(
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('Created'),
                  subtitle: Text(DateFormat('MMM d, yyyy – HH:mm')
                      .format(widget.existing!.createdAt)),
                  dense: true,
                ),
                ListTile(
                  leading: const Icon(Icons.update),
                  title: const Text('Last Updated'),
                  subtitle: Text(DateFormat('MMM d, yyyy – HH:mm')
                      .format(widget.existing!.updatedAt)),
                  dense: true,
                ),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Versions saved'),
                  subtitle:
                      Text('${widget.existing!.history.length} snapshots'),
                  dense: true,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signature/signature.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

void main() {
  runApp(const MyApp());
}

const String GEMINI_API_KEY = 'AIzaSyDemP8-WKTz1rrE7T8-f5QJLqYGMJj9YqY';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _darkMode = false;
  bool _focusMode = false;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkMode = prefs.getBool('darkMode') ?? false;
    });
  }

  void _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkMode = !_darkMode;
    });
    await prefs.setBool('darkMode', _darkMode);
  }

  void _toggleFocusMode() {
    setState(() {
      _focusMode = !_focusMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AP NOTES',
      debugShowCheckedModeBanner: false,
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      home: NotesDashboard(
        onToggleTheme: _toggleTheme,
        onToggleFocusMode: _toggleFocusMode,
        focusMode: _focusMode,
      ),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFD32F2F),
        brightness: Brightness.light,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFD32F2F),
        brightness: Brightness.dark,
      ),
    );
  }
}

// ==================== MODELS ====================

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
  List<String> linkedNotes;
  String? pdfPath;
  List<PDFAnnotation> annotations;
  bool isInfiniteCanvas;

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
    List<String>? linkedNotes,
    this.pdfPath,
    List<PDFAnnotation>? annotations,
    this.isInfiniteCanvas = false,
  })  : tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        history = history ?? [],
        linkedNotes = linkedNotes ?? [],
        annotations = annotations ?? [];

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
        'linkedNotes': linkedNotes,
        'pdfPath': pdfPath,
        'annotations': annotations.map((a) => a.toJson()).toList(),
        'isInfiniteCanvas': isInfiniteCanvas,
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
        linkedNotes: List<String>.from(j['linkedNotes'] ?? []),
        pdfPath: j['pdfPath'],
        annotations: (j['annotations'] as List?)
                ?.map((a) => PDFAnnotation.fromJson(a))
                .toList() ??
            [],
        isInfiniteCanvas: j['isInfiniteCanvas'] ?? false,
      );
}

class PDFAnnotation {
  String id;
  String text;
  int pageNumber;
  double xOffset;
  double yOffset;
  String annotationType;
  DateTime createdAt;

  PDFAnnotation({
    required this.id,
    required this.text,
    required this.pageNumber,
    this.xOffset = 0,
    this.yOffset = 0,
    this.annotationType = 'highlight',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'pageNumber': pageNumber,
        'xOffset': xOffset,
        'yOffset': yOffset,
        'annotationType': annotationType,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PDFAnnotation.fromJson(Map<String, dynamic> j) => PDFAnnotation(
        id: j['id'] ?? '',
        text: j['text'] ?? '',
        pageNumber: j['pageNumber'] ?? 0,
        xOffset: j['xOffset'] ?? 0,
        yOffset: j['yOffset'] ?? 0,
        annotationType: j['annotationType'] ?? 'highlight',
        createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
      );
}

// ==================== DASHBOARD ====================

class NotesDashboard extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final VoidCallback onToggleFocusMode;
  final bool focusMode;

  const NotesDashboard({
    super.key,
    required this.onToggleTheme,
    required this.onToggleFocusMode,
    required this.focusMode,
  });

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
    final raw = p.getStringList('notes_v3') ?? [];
    _notes = raw.map((e) => NoteModel.fromJson(jsonDecode(e))).toList();
    _applyFilter();
  }

  Future<void> _saveAll() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
        'notes_v3', _notes.map((n) => jsonEncode(n.toJson())).toList());
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
      MaterialPageRoute(
        builder: (_) => Editor(
          existing: note,
          onToggleFocusMode: widget.onToggleFocusMode,
          focusMode: widget.focusMode,
        ),
      ),
    );
    if (result != null) await _upsertNote(result);
  }

  void _showCommandPalette() {
    showSearch(
      context: context,
      delegate: CommandPaletteDelegate(
        notes: _notes,
        onNoteSelected: _openEditor,
        onCreateNew: () => _openEditor(),
        onToggleDarkMode: widget.onToggleTheme,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.focusMode) {
      return Scaffold(
        body: _buildNotesList(),
        floatingActionButton: FloatingActionButton(
          mini: true,
          onPressed: () => _openEditor(),
          child: const Icon(Icons.add),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        title: const Row(
          children: [
            Icon(Icons.note_outlined, size: 32),
            SizedBox(width: 8),
            Text('AP NOTES',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showCommandPalette,
            tooltip: 'Command Palette',
          ),
          IconButton(
            icon: Icon(_gridView ? Icons.list : Icons.grid_view),
            onPressed: () => setState(() => _gridView = !_gridView),
            tooltip: 'Toggle View',
          ),
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: widget.onToggleTheme,
            tooltip: 'Toggle Theme',
          ),
          IconButton(
            icon: const Icon(Icons.fullscreen),
            onPressed: widget.onToggleFocusMode,
            tooltip: 'Focus Mode',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search notes...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: scheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                for (final folder in _folders)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(folder),
                      selected: _selectedFolder == folder,
                      onSelected: (_) {
                        setState(() => _selectedFolder = folder);
                        _applyFilter();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _buildNotesList()),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add),
            label: const Text('New Note'),
            tooltip: 'Create new note',
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            mini: true,
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['pdf'],
              );
              if (result != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PDF import feature in beta')),
                );
              }
            },
            tooltip: 'Import PDF',
            child: const Icon(Icons.picture_as_pdf),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesList() {
    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.note_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No notes yet', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            const Text('Create your first note to get started'),
          ],
        ),
      );
    }

    if (_gridView) {
      return GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.85,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        padding: const EdgeInsets.all(8),
        itemCount: _filtered.length,
        itemBuilder: (_, i) => _buildNoteCard(_filtered[i]),
      );
    }

    return ListView.builder(
      itemCount: _filtered.length,
      itemBuilder: (_, i) => _buildNoteListItem(_filtered[i]),
    );
  }

  Widget _buildNoteCard(NoteModel note) {
    return GestureDetector(
      onTap: () => _openEditor(note: note),
      onLongPress: () => _showNoteMenu(note),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      note.title.isEmpty ? 'Untitled' : note.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      size: 16,
                    ),
                    onPressed: () => _togglePin(note),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  note.content,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: note.tags
                    .take(2)
                    .map((t) => Chip(
                        label: Text(t),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap))
                    .toList(),
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('MMM d, yyyy').format(note.updatedAt),
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoteListItem(NoteModel note) {
    return ListTile(
      leading: note.isPinned ? const Icon(Icons.push_pin) : null,
      title: Text(note.title.isEmpty ? 'Untitled' : note.title),
      subtitle: Text(
        note.content.length > 60
            ? '${note.content.substring(0, 60)}...'
            : note.content,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: PopupMenuButton(
        itemBuilder: (ctx) => [
          PopupMenuItem(
            onTap: () => _togglePin(note),
            child: Row(
              children: [
                Icon(note.isPinned ? Icons.push_pin : Icons.push_pin_outlined),
                const SizedBox(width: 8),
                Text(note.isPinned ? 'Unpin' : 'Pin'),
              ],
            ),
          ),
          PopupMenuItem(
            onTap: () => _openEditor(note: note),
            child: const Row(
              children: [
                Icon(Icons.edit),
                SizedBox(width: 8),
                Text('Edit'),
              ],
            ),
          ),
          PopupMenuItem(
            onTap: () => _deleteNote(note.id),
            child: const Row(
              children: [
                Icon(Icons.delete, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
      ),
      onTap: () => _openEditor(note: note),
    );
  }

  void _showNoteMenu(NoteModel note) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit'),
            onTap: () {
              Navigator.pop(context);
              _openEditor(note: note);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Delete'),
            onTap: () {
              Navigator.pop(context);
              _deleteNote(note.id);
            },
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Share'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

// ==================== COMMAND PALETTE ====================

class CommandPaletteDelegate extends SearchDelegate {
  final List<NoteModel> notes;
  final Function(NoteModel?) onNoteSelected;
  final VoidCallback onCreateNew;
  final VoidCallback onToggleDarkMode;

  CommandPaletteDelegate({
    required this.notes,
    required this.onNoteSelected,
    required this.onCreateNew,
    required this.onToggleDarkMode,
  });

  @override
  String get searchFieldLabel => 'Search notes or commands...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context);
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _buildSuggestions(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSuggestions(context);

  Widget _buildSuggestions(BuildContext context) {
    final q = query.toLowerCase();

    final commands = [
      ('Create new note', 'new', Icons.add),
      ('Toggle dark mode', 'dark', Icons.dark_mode),
      ('Export all as PDF', 'export', Icons.picture_as_pdf),
      ('View all tags', 'tags', Icons.tag),
    ];

    final filteredCommands = commands
        .where((c) => c.$0.toLowerCase().contains(q) || c.$1.contains(q))
        .toList();

    final filteredNotes = notes
        .where((n) =>
            n.title.toLowerCase().contains(q) ||
            n.content.toLowerCase().contains(q) ||
            n.tags.any((t) => t.toLowerCase().contains(q)))
        .toList();

    return ListView(
      children: [
        if (filteredCommands.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Commands',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          for (final (name, cmd, icon) in filteredCommands)
            ListTile(
              leading: Icon(icon),
              title: Text(name),
              onTap: () {
                close(context, null);
                switch (cmd) {
                  case 'new':
                    onCreateNew();
                    break;
                  case 'dark':
                    onToggleDarkMode();
                    break;
                }
              },
            ),
          const Divider(),
        ],
        if (filteredNotes.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Notes',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          for (final note in filteredNotes)
            ListTile(
              title: Text(note.title.isEmpty ? 'Untitled' : note.title),
              subtitle: Text(
                note.content.length > 50
                    ? '${note.content.substring(0, 50)}...'
                    : note.content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                close(context, null);
                onNoteSelected(note);
              },
            ),
        ],
      ],
    );
  }
}

// ==================== EDITOR ====================

class Editor extends StatefulWidget {
  final NoteModel? existing;
  final VoidCallback onToggleFocusMode;
  final bool focusMode;

  const Editor({
    super.key,
    this.existing,
    required this.onToggleFocusMode,
    required this.focusMode,
  });

  @override
  State<Editor> createState() => _EditorState();
}

class _EditorState extends State<Editor> with TickerProviderStateMixin {
  late final TabController _tabs;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  late final TextEditingController _folderCtrl;
  late final TextEditingController _tagsCtrl;
  late final SignatureController _sign;
  String? _selectedLayoutMode;
  bool _showFormatToolbar = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _titleCtrl = TextEditingController(text: widget.existing?.title ?? '');
    _contentCtrl = TextEditingController(text: widget.existing?.content ?? '');
    _folderCtrl = TextEditingController(text: widget.existing?.folder ?? '');
    _tagsCtrl = TextEditingController(
        text: (widget.existing?.tags ?? []).join(', '));
    _sign = SignatureController(
      penStrokeWidth: 2,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    _selectedLayoutMode =
        widget.existing?.isInfiniteCanvas ?? false ? 'infinite' : 'paged';
  }

  @override
  void dispose() {
    _tabs.dispose();
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _folderCtrl.dispose();
    _tagsCtrl.dispose();
    _sign.dispose();
    super.dispose();
  }

  Future<void> _generateAISummary() async {
    try {
      final content = _contentCtrl.text.trim();
      if (content.isEmpty) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating summary...')),
      );

      final model = GenerativeModel(
        model: 'gemini-pro',
        apiKey: GEMINI_API_KEY,
      );

      final prompt = '''Summarize the following text in 5 bullet points:

$content

Format as bullet points only.''';

      final response = await model.generateContent([Content.text(prompt)]);

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('AI Summary'),
            content: SelectableText(response.text ?? 'No summary generated'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _generateAIExplanation(String selectedText) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating explanation...')),
      );

      final model = GenerativeModel(
        model: 'gemini-pro',
        apiKey: GEMINI_API_KEY,
      );

      final prompt = '''Explain the following text in simple, layman\'s terms:

$selectedText

Keep it concise and easy to understand.''';

      final response = await model.generateContent([Content.text(prompt)]);

      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('AI Explanation'),
            content: SelectableText(response.text ?? 'No explanation generated'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    final plain = _contentCtrl.text.trim();
    final id =
        widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

    final note = NoteModel(
      id: id,
      title: title.isEmpty ? 'Untitled' : title,
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
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      isPinned: widget.existing?.isPinned ?? false,
      history: [plain, ...(widget.existing?.history ?? [])].take(20).toList(),
      isInfiniteCanvas: _selectedLayoutMode == 'infinite',
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
            pw.Text('AP NOTES — Advanced Note Taking',
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
          final preview =
              ver.length > 60 ? '${ver.substring(0, 60)}...' : ver;
          return ListTile(
            leading: CircleAvatar(child: Text('v${history.length - i}')),
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

  void _showLinkedNotesDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Link Notes (Bi-directional)'),
        content: const Text('Bi-directional linking feature coming soon'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.focusMode) {
      return Scaffold(
        body: GestureDetector(
          onTap: () => setState(() => _showFormatToolbar = !_showFormatToolbar),
          child: Column(
            children: [
              if (_showFormatToolbar)
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.black12,
                  child: Row(
                    children: [
                      IconButton(
                          icon: const Icon(Icons.bold), onPressed: () {}),
                      IconButton(
                          icon: const Icon(Icons.italic), onPressed: () {}),
                      IconButton(
                          icon: const Icon(Icons.underline), onPressed: () {}),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () =>
                            setState(() => _showFormatToolbar = false),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: TextField(
                  controller: _contentCtrl,
                  maxLines: null,
                  expands: true,
                  decoration: const InputDecoration(
                    hintText: 'Start writing...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
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
            Tab(icon: Icon(Icons.extension), text: 'AI'),
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
            icon: const Icon(Icons.link),
            tooltip: 'Link Notes',
            onPressed: _showLinkedNotesDialog,
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
          // Write Tab
          Column(
            children: [
              if (_showFormatToolbar)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      IconButton(
                          icon: const Icon(Icons.format_bold),
                          tooltip: 'Bold',
                          onPressed: () {}),
                      IconButton(
                          icon: const Icon(Icons.format_italic),
                          tooltip: 'Italic',
                          onPressed: () {}),
                      IconButton(
                          icon: const Icon(Icons.format_underlined),
                          tooltip: 'Underline',
                          onPressed: () {}),
                      IconButton(
                          icon: const Icon(Icons.format_color_text),
                          tooltip: 'Text Color',
                          onPressed: () {}),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () =>
                            setState(() => _showFormatToolbar = false),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: TextField(
                  controller: _contentCtrl,
                  maxLines: null,
                  expands: true,
                  onTap: () => setState(() => _showFormatToolbar = true),
                  decoration: const InputDecoration(
                    hintText: 'Start writing your note...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ),
            ],
          ),
          // Draw Tab
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
                            '\n[Drawing - ${DateTime.now().toIso8601String()}]\n' +
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
                      label: const Text('Insert'),
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
          // AI Tab
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('AI Features',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.summarize),
                  title: const Text('Generate Summary'),
                  subtitle:
                      const Text('Summarize your note in 5 bullet points'),
                  onTap: _generateAISummary,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.lightbulb),
                  title: const Text('AI Explanation'),
                  subtitle:
                      const Text('Get layman\'s explanation of concepts'),
                  onTap: () => _generateAIExplanation(_contentCtrl.text),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.auto_fix_high),
                  title: const Text('Smart Search'),
                  subtitle: const Text(
                      'Search by meaning, not just keywords'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Semantic search coming soon')),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.image),
                  title: const Text('OCR from Image'),
                  subtitle: const Text(
                      'Convert image text to editable text'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('OCR coming soon')),
                    );
                  },
                ),
              ),
            ],
          ),
          // Meta Tab
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
              const Text('Layout',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'paged',
                    label: Text('Paged (A4)'),
                    icon: Icon(Icons.description),
                  ),
                  ButtonSegment(
                    value: 'infinite',
                    label: Text('Infinite Canvas'),
                    icon: Icon(Icons.crop_landscape),
                  ),
                ],
                selected: {_selectedLayoutMode ?? 'paged'},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(
                      () => _selectedLayoutMode = newSelection.first);
                },
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
                  subtitle: Text(
                      '${widget.existing!.history.length} snapshots'),
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
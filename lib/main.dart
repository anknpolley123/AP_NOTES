// --- AI REMOVED VERSION (BUILD SAFE) ---

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signature/signature.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const MyApp());
}

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
      theme: ThemeData(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: NotesDashboard(
        onToggleTheme: _toggleTheme,
        onToggleFocusMode: _toggleFocusMode,
        focusMode: _focusMode,
      ),
    );
  }
}

// ------------------ MODEL ------------------

class NoteModel {
  String id;
  String title;
  String content;
  DateTime updatedAt;
  bool isPinned;

  NoteModel({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAt,
    this.isPinned = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'updatedAt': updatedAt.toIso8601String(),
        'isPinned': isPinned,
      };

  factory NoteModel.fromJson(Map<String, dynamic> j) => NoteModel(
        id: j['id'],
        title: j['title'],
        content: j['content'],
        updatedAt: DateTime.parse(j['updatedAt']),
        isPinned: j['isPinned'] ?? false,
      );
}

// ------------------ DASHBOARD ------------------

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
  List<NoteModel> notes = [];
  final TextEditingController controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('notes') ?? [];
    setState(() {
      notes = data.map((e) => NoteModel.fromJson(jsonDecode(e))).toList();
    });
  }

  Future<void> saveAll() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList(
        'notes', notes.map((e) => jsonEncode(e.toJson())).toList());
  }

  void addNote() async {
    final note = NoteModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: "New Note",
      content: "",
      updatedAt: DateTime.now(),
    );

    notes.insert(0, note);
    await saveAll();
    setState(() {});
  }

  Future<void> exportPDF(NoteModel note) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(build: (_) => pw.Text(note.content)));

    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AP NOTES"),
        actions: [
          IconButton(
              onPressed: widget.onToggleTheme,
              icon: const Icon(Icons.dark_mode)),
        ],
      ),
      floatingActionButton:
          FloatingActionButton(onPressed: addNote, child: const Icon(Icons.add)),
      body: ListView.builder(
        itemCount: notes.length,
        itemBuilder: (_, i) {
          final n = notes[i];
          return ListTile(
            title: Text(n.title),
            subtitle: Text(n.content),
            onTap: () async {
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => Editor(note: n)),
              );
              if (updated != null) {
                notes[i] = updated;
                await saveAll();
                setState(() {});
              }
            },
            trailing: IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: () => exportPDF(n),
            ),
          );
        },
      ),
    );
  }
}

// ------------------ EDITOR ------------------

class Editor extends StatefulWidget {
  final NoteModel note;

  const Editor({super.key, required this.note});

  @override
  State<Editor> createState() => _EditorState();
}

class _EditorState extends State<Editor> {
  late TextEditingController ctrl;

  @override
  void initState() {
    super.initState();
    ctrl = TextEditingController(text: widget.note.content);
  }

  void save() {
    widget.note.content = ctrl.text;
    widget.note.updatedAt = DateTime.now();
    Navigator.pop(context, widget.note);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Note"),
        actions: [
          IconButton(onPressed: save, icon: const Icon(Icons.save))
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: ctrl,
          maxLines: null,
          expands: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
      ),
    );
  }
}
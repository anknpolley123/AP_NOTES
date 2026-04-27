import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String notesKey = 'notes_v3';
  static const String settingsKey = 'app_settings';
  static const String tagsKey = 'user_tags';

  late final SharedPreferences _prefs;

  /// Initialize storage service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ────── Notes Management ──────

  /// Get all saved notes as JSON strings
  Future<List<String>> getAllNotes() async {
    return _prefs.getStringList(notesKey) ?? [];
  }

  /// Save all notes
  Future<bool> saveAllNotes(List<String> notes) async {
    return await _prefs.setStringList(notesKey, notes);
  }

  /// Add or update a single note
  Future<bool> upsertNote(String noteJson) async {
    final notes = await getAllNotes();
    final note = jsonDecode(noteJson);
    final noteId = note['id'];

    // Remove old version if exists
    notes.removeWhere((n) {
      final decoded = jsonDecode(n);
      return decoded['id'] == noteId;
    });

    // Add updated note
    notes.insert(0, noteJson);
    return await saveAllNotes(notes);
  }

  /// Delete note by ID
  Future<bool> deleteNote(String noteId) async {
    final notes = await getAllNotes();
    notes.removeWhere((n) {
      final decoded = jsonDecode(n);
      return decoded['id'] == noteId;
    });
    return await saveAllNotes(notes);
  }

  /// Get note by ID
  Future<String?> getNoteById(String noteId) async {
    final notes = await getAllNotes();
    try {
      return notes.firstWhere((n) {
        final decoded = jsonDecode(n);
        return decoded['id'] == noteId;
      });
    } catch (e) {
      return null;
    }
  }

  /// Search notes by title or content
  Future<List<String>> searchNotes(String query) async {
    final notes = await getAllNotes();
    final lowerQuery = query.toLowerCase();

    return notes.where((n) {
      final decoded = jsonDecode(n);
      final title = (decoded['title'] ?? '').toString().toLowerCase();
      final content = (decoded['content'] ?? '').toString().toLowerCase();
      final tags = decoded['tags'] ?? [];

      return title.contains(lowerQuery) ||
          content.contains(lowerQuery) ||
          tags.any((t) => t.toString().toLowerCase().contains(lowerQuery));
    }).toList();
  }

  /// Get notes by folder
  Future<List<String>> getNotesByFolder(String folder) async {
    final notes = await getAllNotes();

    return notes.where((n) {
      final decoded = jsonDecode(n);
      return (decoded['folder'] ?? 'General') == folder;
    }).toList();
  }

  /// Get notes by tag
  Future<List<String>> getNotesByTag(String tag) async {
    final notes = await getAllNotes();

    return notes.where((n) {
      final decoded = jsonDecode(n);
      final tags = List<String>.from(decoded['tags'] ?? []);
      return tags.contains(tag);
    }).toList();
  }

  // ────── Folders ──────

  /// Get all unique folders
  Future<List<String>> getAllFolders() async {
    final notes = await getAllNotes();
    final folders = <String>{};

    for (final note in notes) {
      final decoded = jsonDecode(note);
      final folder = decoded['folder'] ?? 'General';
      folders.add(folder);
    }

    return folders.toList()..sort();
  }

  /// Create a new folder (by adding a note to it)
  Future<bool> createFolder(String folderName) async {
    return true;
  }

  /// Rename folder
  Future<bool> renameFolder(String oldName, String newName) async {
    final notes = await getAllNotes();

    final updatedNotes = notes.map((n) {
      final decoded = jsonDecode(n);
      if ((decoded['folder'] ?? 'General') == oldName) {
        decoded['folder'] = newName;
      }
      return jsonEncode(decoded);
    }).toList();

    return await saveAllNotes(updatedNotes);
  }

  // ────── Tags Management ──────

  /// Get all unique tags
  Future<List<String>> getAllTags() async {
    final notes = await getAllNotes();
    final tags = <String>{};

    for (final note in notes) {
      final decoded = jsonDecode(note);
      final noteTags = List<String>.from(decoded['tags'] ?? []);
      tags.addAll(noteTags);
    }

    return tags.toList()..sort();
  }

  /// Get tag frequency
  Future<Map<String, int>> getTagFrequency() async {
    final tags = await getAllTags();
    final frequency = <String, int>{};

    for (final tag in tags) {
      final notes = await getNotesByTag(tag);
      frequency[tag] = notes.length;
    }

    return frequency;
  }

  // ────── Pinned Notes ──────

  /// Get pinned notes
  Future<List<String>> getPinnedNotes() async {
    final notes = await getAllNotes();

    return notes.where((n) {
      final decoded = jsonDecode(n);
      return decoded['isPinned'] ?? false;
    }).toList();
  }

  /// Toggle pin status
  Future<bool> togglePin(String noteId, bool isPinned) async {
    final notes = await getAllNotes();
    final updated = notes.map((n) {
      final decoded = jsonDecode(n);
      if (decoded['id'] == noteId) {
        decoded['isPinned'] = isPinned;
      }
      return jsonEncode(decoded);
    }).toList();

    return await saveAllNotes(updated);
  }

  // ────── Statistics ──────

  /// Get notes count
  Future<int> getNotesCount() async {
    final notes = await getAllNotes();
    return notes.length;
  }

  /// Get statistics
  Future<Map<String, dynamic>> getStatistics() async {
    final notes = await getAllNotes();
    final folders = await getAllFolders();
    final tags = await getAllTags();

    int totalChars = 0;
    int totalWords = 0;
    int pinnedCount = 0;

    for (final note in notes) {
      final decoded = jsonDecode(note);
      final content = decoded['content'] ?? '';
      totalChars += content.length;
      totalWords += content.split(' ').length;
      if (decoded['isPinned'] ?? false) pinnedCount++;
    }

    return {
      'totalNotes': notes.length,
      'totalFolders': folders.length,
      'totalTags': tags.length,
      'totalCharacters': totalChars,
      'totalWords': totalWords,
      'pinnedNotes': pinnedCount,
      'averageNoteLength': notes.isEmpty ? 0 : totalChars ~/ notes.length,
    };
  }

  // ────── App Settings ──────

  /// Get setting value
  Future<dynamic> getSetting(String key, dynamic defaultValue) async {
    final settings = _prefs.getString(settingsKey);
    if (settings == null) return defaultValue;

    final decoded = jsonDecode(settings) as Map<String, dynamic>;
    return decoded[key] ?? defaultValue;
  }

  /// Set setting value
  Future<bool> setSetting(String key, dynamic value) async {
    final settings = _prefs.getString(settingsKey) ?? '{}';
    final decoded = jsonDecode(settings) as Map<String, dynamic>;
    decoded[key] = value;

    return await _prefs.setString(settingsKey, jsonEncode(decoded));
  }

  /// Get all settings
  Future<Map<String, dynamic>> getSettings() async {
    final settings = _prefs.getString(settingsKey) ?? '{}';
    return jsonDecode(settings) as Map<String, dynamic>;
  }

  // ────── Export/Import ──────

  /// Export all notes as JSON
  Future<String> exportAllNotesAsJson() async {
    final notes = await getAllNotes();
    final decodedNotes = notes.map((n) => jsonDecode(n)).toList();
    return jsonEncode({
      'version': '2.0',
      'exportDate': DateTime.now().toIso8601String(),
      'noteCount': notes.length,
      'notes': decodedNotes,
    });
  }

  /// Import notes from JSON
  Future<bool> importNotesFromJson(String jsonData) async {
    try {
      final decoded = jsonDecode(jsonData) as Map<String, dynamic>;
      final notes = List<Map<String, dynamic>>.from(decoded['notes'] ?? []);

      final current = await getAllNotes();
      for (final note in notes) {
        current.add(jsonEncode(note));
      }

      return await saveAllNotes(current);
    } catch (e) {
      return false;
    }
  }

  // ────── Cleanup ──────

  /// Clear all data
  Future<bool> clearAllData() async {
    return await _prefs.clear();
  }

  /// Delete old versions of notes (keep last N)
  Future<bool> cleanupOldVersions({int keepVersions = 20}) async {
    final notes = await getAllNotes();

    final cleaned = notes.map((n) {
      final decoded = jsonDecode(n) as Map<String, dynamic>;
      final history = List<String>.from(decoded['history'] ?? []);

      if (history.length > keepVersions) {
        decoded['history'] = history.take(keepVersions).toList();
      }

      return jsonEncode(decoded);
    }).toList();

    return await saveAllNotes(cleaned);
  }
}
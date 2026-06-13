import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';

class StorageService {
  static const String _tasksKey = 'focusflow_tasks';
  static const String _categoriesKey = 'focusflow_categories';
  static const String _themeKey = 'focusflow_theme';
  static const String _isLoggedInKey = 'focusflow_logged_in';
  static const String _usernameKey = 'focusflow_username';
  static const String _clientNameKey = 'focusflow_client_name';
  static const String _hasSeededKey = 'focusflow_has_seeded';

  Future<List<Task>> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? tasksJson = prefs.getString(_tasksKey);
    if (tasksJson == null) return [];
    
    try {
      final List<dynamic> decoded = json.decode(tasksJson);
      return decoded.map((item) => Task.fromMap(item as Map<String, dynamic>)).toList();
    } catch (e) {
      print('Error loading tasks: $e');
      return [];
    }
  }

  Future<void> saveTasks(List<Task> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = json.encode(tasks.map((t) => t.toMap()).toList());
    await prefs.setString(_tasksKey, encoded);
  }

  Future<Map<String, int>> loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final String? categoriesJson = prefs.getString(_categoriesKey);
    if (categoriesJson == null) {
      // Default categories with their respective color hex codes
      return {
        'Personal': 0xFF818CF8, // Indigo Accent
        'Work': 0xFFF87171,     // Red/Coral Accent
        'Shopping': 0xFF34D399, // Emerald Accent
        'Health': 0xFFF472B6,   // Pink Accent
        'Ideas': 0xFFFB7185,    // Rose Accent
      };
    }
    try {
      final Map<String, dynamic> decoded = json.decode(categoriesJson);
      return decoded.map((key, value) => MapEntry(key, value as int));
    } catch (e) {
      print('Error loading categories: $e');
      return {};
    }
  }

  Future<void> saveCategories(Map<String, int> categories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_categoriesKey, json.encode(categories));
  }

  Future<bool> loadDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_themeKey) ?? true; // Default to Dark Mode as per premium design guidelines
  }

  Future<void> saveDarkMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isDark);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static const String _deletedTasksKey = 'focusflow_deleted_tasks';

  Future<List<String>> loadDeletedTaskIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_deletedTasksKey) ?? [];
  }

  Future<void> saveDeletedTaskIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_deletedTasksKey, ids);
  }

  Future<bool> loadLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  Future<void> saveLoginStatus(bool isLoggedIn) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, isLoggedIn);
  }

  Future<String?> loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  Future<void> saveUsername(String? username) async {
    final prefs = await SharedPreferences.getInstance();
    if (username == null) {
      await prefs.remove(_usernameKey);
    } else {
      await prefs.setString(_usernameKey, username);
    }
  }

  Future<String?> loadClientName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_clientNameKey);
  }

  Future<void> saveClientName(String? name) async {
    final prefs = await SharedPreferences.getInstance();
    if (name == null) {
      await prefs.remove(_clientNameKey);
    } else {
      await prefs.setString(_clientNameKey, name);
    }
  }

  Future<bool> hasSeeded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSeededKey) ?? false;
  }

  Future<void> setSeeded(bool seeded) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeededKey, seeded);
  }
}

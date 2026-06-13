import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task.dart';
import 'supabase_config.dart';

class SupabaseNotConfiguredException implements Exception {
  final String message;
  SupabaseNotConfiguredException([this.message = 'Supabase has not been configured yet with real credentials.']);
  
  @override
  String toString() => 'SupabaseNotConfiguredException: $message';
}

class SupabaseService {
  // Singleton instance
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient? get _client {
    if (!SupabaseConfig.isConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (e) {
      return null;
    }
  }

  /// Check if Supabase client is initialized and configured.
  bool get isActive => SupabaseConfig.isConfigured && _client != null;

  /// Get currently authenticated user.
  User? get currentUser {
    if (!isActive) return null;
    return _client!.auth.currentUser;
  }

  /// Get active user ID.
  String? get currentUserId => currentUser?.id;

  /// Check if a user session is active.
  bool get isLoggedIn => currentUser != null;

  /// Sign Up with Email and Password
  Future<AuthResponse> signUp(String email, String password) async {
    if (!isActive) throw SupabaseNotConfiguredException();
    return await _client!.auth.signUp(
      email: email,
      password: password,
    );
  }

  /// Sign In with Email and Password
  Future<AuthResponse> signIn(String email, String password) async {
    if (!isActive) throw SupabaseNotConfiguredException();
    return await _client!.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign Out
  Future<void> signOut() async {
    if (!isActive) return;
    await _client!.auth.signOut();
  }

  /// Sign In Anonymously
  Future<AuthResponse> signInAnonymously() async {
    if (!isActive) throw SupabaseNotConfiguredException();
    return await _client!.auth.signInAnonymously();
  }

  /// Check if the current user is anonymous
  bool get isAnonymous {
    if (!isActive || currentUser == null) return false;
    return currentUser!.isAnonymous;
  }

  // ==========================================
  // Task Database Operations
  // ==========================================

  /// Load tasks from Supabase
  Future<List<Task>> loadTasks() async {
    if (!isActive) throw SupabaseNotConfiguredException();
    final userId = currentUserId;
    if (userId == null) return [];

    final response = await _client!
        .from('tasks')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final List<dynamic> data = response as List<dynamic>;
    return data.map((row) => _taskFromDbMap(row as Map<String, dynamic>)).toList();
  }

  // Set to keep track of columns that the remote database doesn't support
  final Set<String> _unsupportedTaskColumns = {};

  Map<String, dynamic> _cleanTaskDbMap(Map<String, dynamic> original) {
    final cleaned = Map<String, dynamic>.from(original);
    for (var col in _unsupportedTaskColumns) {
      cleaned.remove(col);
    }
    return cleaned;
  }

  /// Insert task into Supabase
  Future<void> insertTask(Task task) async {
    if (!isActive) return;
    final userId = currentUserId;
    if (userId == null) return;

    final taskMap = _taskToDbMap(task, userId);
    var attemptMap = _cleanTaskDbMap(taskMap);
    
    while (true) {
      try {
        await _client!.from('tasks').insert(attemptMap);
        break;
      } catch (e) {
        if (e is PostgrestException) {
          String? columnName;
          
          // Case 1: PostgREST PGRST204 (Could not find the 'col_name' column...)
          final match1 = RegExp(r"Could not find the '([^']+)' column").firstMatch(e.message);
          if (match1 != null) {
            columnName = match1.group(1);
          }
          
          // Case 2: PostgreSQL 42703 (column "col_name" of relation "tasks" does not exist)
          if (columnName == null) {
            final match2 = RegExp(r'column "([^"]+)" of relation').firstMatch(e.message);
            if (match2 != null) {
              columnName = match2.group(1);
            }
          }
          
          // Case 3: Generic fallback matching quotes indicating column name
          if (columnName == null && (e.code == 'PGRST204' || e.code == '42703' || e.message.contains('does not exist'))) {
            final match3 = RegExp(r'column "([^"]+)"').firstMatch(e.message) ??
                           RegExp(r"column '([^']+)'").firstMatch(e.message);
            if (match3 != null) {
              columnName = match3.group(1);
            }
          }
          
          if (columnName != null) {
            _unsupportedTaskColumns.add(columnName);
            attemptMap.remove(columnName);
            continue; // retry
          }
        }
        rethrow;
      }
    }
  }

  /// Update task in Supabase
  Future<void> updateTask(Task task) async {
    if (!isActive) return;
    final userId = currentUserId;
    if (userId == null) return;

    final taskMap = _taskToDbMap(task, userId);
    var attemptMap = _cleanTaskDbMap(taskMap);
    
    while (true) {
      try {
        await _client!
            .from('tasks')
            .update(attemptMap)
            .eq('id', task.id)
            .eq('user_id', userId);
        break;
      } catch (e) {
        if (e is PostgrestException) {
          String? columnName;
          
          // Case 1: PostgREST PGRST204 (Could not find the 'col_name' column...)
          final match1 = RegExp(r"Could not find the '([^']+)' column").firstMatch(e.message);
          if (match1 != null) {
            columnName = match1.group(1);
          }
          
          // Case 2: PostgreSQL 42703 (column "col_name" of relation "tasks" does not exist)
          if (columnName == null) {
            final match2 = RegExp(r'column "([^"]+)" of relation').firstMatch(e.message);
            if (match2 != null) {
              columnName = match2.group(1);
            }
          }
          
          // Case 3: Generic fallback matching quotes indicating column name
          if (columnName == null && (e.code == 'PGRST204' || e.code == '42703' || e.message.contains('does not exist'))) {
            final match3 = RegExp(r'column "([^"]+)"').firstMatch(e.message) ??
                           RegExp(r"column '([^']+)'").firstMatch(e.message);
            if (match3 != null) {
              columnName = match3.group(1);
            }
          }
          
          if (columnName != null) {
            _unsupportedTaskColumns.add(columnName);
            attemptMap.remove(columnName);
            continue; // retry
          }
        }
        rethrow;
      }
    }
  }

  /// Delete task from Supabase
  Future<void> deleteTask(String id) async {
    if (!isActive) return;
    final userId = currentUserId;
    if (userId == null) return;

    await _client!
        .from('tasks')
        .delete()
        .eq('id', id)
        .eq('user_id', userId);
  }

  // ==========================================
  // Category Database Operations
  // ==========================================

  /// Load custom categories from Supabase
  Future<Map<String, int>> loadCategories() async {
    if (!isActive) throw SupabaseNotConfiguredException();
    final userId = currentUserId;
    if (userId == null) return {};

    final response = await _client!
        .from('categories')
        .select()
        .eq('user_id', userId);

    final List<dynamic> data = response as List<dynamic>;
    final Map<String, int> categoriesMap = {};
    
    for (final row in data) {
      final map = row as Map<String, dynamic>;
      final name = map['name'] as String;
      final color = map['color'] as int;
      categoriesMap[name] = color;
    }
    
    return categoriesMap;
  }

  /// Insert category into Supabase
  Future<void> insertCategory(String name, int color) async {
    if (!isActive) return;
    final userId = currentUserId;
    if (userId == null) return;

    await _client!.from('categories').upsert({
      'user_id': userId,
      'name': name,
      'color': color,
    });
  }

  /// Delete category from Supabase
  Future<void> deleteCategory(String name) async {
    if (!isActive) return;
    final userId = currentUserId;
    if (userId == null) return;

    await _client!
        .from('categories')
        .delete()
        .eq('user_id', userId)
        .eq('name', name);
  }

  // ==========================================
  // Model Data Mapping Helpers
  // ==========================================

  Map<String, dynamic> _taskToDbMap(Task task, String userId) {
    return {
      'id': task.id,
      'user_id': userId,
      'title': task.title,
      'description': task.description,
      'due_date': task.dueDate?.toIso8601String(),
      'priority': task.priority.name,
      'category': task.category,
      'tags': task.tags,
      'is_completed': task.isCompleted,
      'completed_at': task.completedAt?.toIso8601String(),
      'reminders': task.reminders.map((r) => r.toIso8601String()).toList(),
      'created_at': task.createdAt.toIso8601String(),
    };
  }

  Task _taskFromDbMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      dueDate: map['due_date'] != null ? DateTime.parse(map['due_date']) : null,
      priority: TaskPriority.values.firstWhere(
        (p) => p.name == map['priority'],
        orElse: () => TaskPriority.medium,
      ),
      category: map['category'] ?? 'Personal',
      tags: List<String>.from(map['tags'] ?? []),
      isCompleted: map['is_completed'] ?? false,
      completedAt: map['completed_at'] != null ? DateTime.parse(map['completed_at']) : null,
      reminders: (map['reminders'] as List?)
              ?.map((r) => DateTime.parse(r as String))
              .toList() ??
          [],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }
}

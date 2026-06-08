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

  /// Insert task into Supabase
  Future<void> insertTask(Task task) async {
    if (!isActive) return;
    final userId = currentUserId;
    if (userId == null) return;

    await _client!.from('tasks').insert(_taskToDbMap(task, userId));
  }

  /// Update task in Supabase
  Future<void> updateTask(Task task) async {
    if (!isActive) return;
    final userId = currentUserId;
    if (userId == null) return;

    await _client!
        .from('tasks')
        .update(_taskToDbMap(task, userId))
        .eq('id', task.id)
        .eq('user_id', userId);
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

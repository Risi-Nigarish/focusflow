import 'dart:async';
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import 'package:uuid/uuid.dart';

enum TaskSortOption { priority, dueDate, category, dateCreated }

class TaskProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  final NotificationService _notificationService = NotificationService();
  final SupabaseService _supabaseService = SupabaseService();

  List<Task> _tasks = [];
  Map<String, int> _categories = {};
  bool _isDarkMode = true;
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String? _username;
  String? _clientName;
  Timer? _cleanupTimer;
  bool _isSyncing = false;

  // Filters and Sorting
  String _searchQuery = '';
  String? _selectedCategory;
  TaskPriority? _selectedPriority;
  bool? _selectedCompletionStatus; // null for All, true for Completed, false for Pending
  TaskSortOption _sortOption = TaskSortOption.priority;

  // Getters
  List<Task> get allTasks => _tasks;
  Map<String, int> get categories => _categories;
  bool get isDarkMode => _isDarkMode;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  bool get isSyncing => _isSyncing;
  String? get username => _username;
  String? get clientName => _clientName;
  bool get isSupabaseConfigured => _supabaseService.isActive;

  String get searchQuery => _searchQuery;
  String? get selectedCategory => _selectedCategory;
  TaskPriority? get selectedPriority => _selectedPriority;
  bool? get selectedCompletionStatus => _selectedCompletionStatus;
  TaskSortOption get sortOption => _sortOption;

  // Filtered and Sorted Tasks
  List<Task> get filteredTasks {
    final list = _tasks.where((task) {
      final matchesSearch = task.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          task.description.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == null || task.category == _selectedCategory;
      final matchesPriority = _selectedPriority == null || task.priority == _selectedPriority;
      final matchesStatus = _selectedCompletionStatus == null || task.isCompleted == _selectedCompletionStatus;
      
      return matchesSearch && matchesCategory && matchesPriority && matchesStatus;
    }).toList();

    list.sort((a, b) {
      // Uncompleted tasks first
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      
      switch (_sortOption) {
        case TaskSortOption.priority:
          if (a.priority != b.priority) {
            return b.priority.index.compareTo(a.priority.index); // high priority first
          }
          break;
        case TaskSortOption.dueDate:
          if (a.dueDate != null && b.dueDate != null) {
            return a.dueDate!.compareTo(b.dueDate!);
          }
          if (a.dueDate != null) return -1;
          if (b.dueDate != null) return 1;
          break;
        case TaskSortOption.category:
          return a.category.compareTo(b.category);
        case TaskSortOption.dateCreated:
          return b.createdAt.compareTo(a.createdAt); // newest first
      }
      
      // Secondary fallback sorting: Creation Date (newest first)
      return b.createdAt.compareTo(a.createdAt);
    });

    return list;
  }

  // Initial load
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    // 1. Load local preferences and settings
    _isDarkMode = await _storageService.loadDarkMode();
    _clientName = await _storageService.loadClientName() ?? 'Default Client';
    _notificationService.initialize();

    // 2. Determine auth state
    if (_supabaseService.isActive && _supabaseService.isLoggedIn) {
      // User is logged into Supabase
      _isLoggedIn = true;
      _username = _supabaseService.currentUser?.email?.split('@').first;
      _clientName = await _storageService.loadClientName() ?? _username ?? 'Default Client';
      await _storageService.saveLoginStatus(true);
      await _storageService.saveUsername(_username);
      await _storageService.saveClientName(_clientName);

      // Load tasks and categories from Supabase, syncing to local cache
      await refreshFromSupabase();
    } else {
      // Fallback to local offline cache
      _isLoggedIn = await _storageService.loadLoginStatus();
      _username = await _storageService.loadUsername();
      _tasks = await _storageService.loadTasks();
      _categories = await _storageService.loadCategories();
    }
    
    // 3. Seed default tasks and categories if not seeded yet
    final hasSeeded = await _storageService.hasSeeded();
    if (!hasSeeded && _tasks.isEmpty && _categories.isEmpty) {
      await _seedDefaultData();
    }

    _notificationService.updateMonitoredTasks(_tasks);

    // Setup periodic task cleanup at 4 AM boundary
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      cleanupCompletedTasks();
    });
    await cleanupCompletedTasks();

    _isLoading = false;
    notifyListeners();
  }

  /// Refreshes tasks and categories from Supabase, merging local and remote data
  Future<void> refreshFromSupabase() async {
    if (!_supabaseService.isActive || !_supabaseService.isLoggedIn) return;
    _isSyncing = true;
    notifyListeners();
    
    try {
      final remoteTasks = await _supabaseService.loadTasks();
      final localTasks = await _storageService.loadTasks();
      final deletedIds = await _storageService.loadDeletedTaskIds();
      
      // 1. Process offline deletions first
      final List<String> successfullyDeleted = [];
      for (var id in deletedIds) {
        try {
          await _supabaseService.deleteTask(id);
          successfullyDeleted.add(id);
        } catch (e) {
          debugPrint('Failed to sync offline deletion for task $id: $e');
        }
      }
      if (successfullyDeleted.isNotEmpty) {
        deletedIds.removeWhere((id) => successfullyDeleted.contains(id));
        await _storageService.saveDeletedTaskIds(deletedIds);
      }
      
      final Map<String, Task> mergedTasks = {};
      
      // 2. Put all remote tasks in the map (unless they were deleted locally offline)
      for (var task in remoteTasks) {
        if (!deletedIds.contains(task.id)) {
          mergedTasks[task.id] = task;
        }
      }
      
      // 3. Process local tasks
      final List<Task> toUpload = [];
      final List<Task> toUpdateRemote = [];
      
      for (var localTask in localTasks) {
        if (deletedIds.contains(localTask.id)) {
          // This task was deleted locally, skip it
          continue;
        }
        
        if (!mergedTasks.containsKey(localTask.id)) {
          // Local-only task: user created this task while offline/guest.
          // Add it to merged tasks and mark for upload.
          mergedTasks[localTask.id] = localTask;
          toUpload.add(localTask);
        } else {
          final remoteTask = mergedTasks[localTask.id]!;
          // Task exists in both: check if they differ
          if (localTask.isCompleted != remoteTask.isCompleted ||
              localTask.title != remoteTask.title ||
              localTask.description != remoteTask.description ||
              localTask.dueDate?.millisecondsSinceEpoch != remoteTask.dueDate?.millisecondsSinceEpoch ||
              localTask.priority != remoteTask.priority ||
              localTask.category != remoteTask.category ||
              localTask.tags.join(',') != remoteTask.tags.join(',') ||
              localTask.reminders.length != remoteTask.reminders.length) {
            
            // Conflict! We will keep the local version since this is the active user device.
            // Mark for update on Supabase.
            mergedTasks[localTask.id] = localTask;
            toUpdateRemote.add(localTask);
          }
        }
      }
      
      _tasks = mergedTasks.values.toList();
      await _storageService.saveTasks(_tasks);
      
      // 4. Upload local-only tasks to Supabase in background
      for (var task in toUpload) {
        try {
          await _supabaseService.insertTask(task);
        } catch (e) {
          debugPrint('Failed to sync local-only task to Supabase: $e');
        }
      }
      
      // 5. Update conflicted tasks in Supabase in background
      for (var task in toUpdateRemote) {
        try {
          await _supabaseService.updateTask(task);
        } catch (e) {
          debugPrint('Failed to sync local-updated task to Supabase: $e');
        }
      }
      
      // 6. Merge Categories
      final remoteCategories = await _supabaseService.loadCategories();
      _categories = await _storageService.loadCategories();
      
      bool categoriesChanged = false;
      for (var entry in _categories.entries) {
        if (!remoteCategories.containsKey(entry.key)) {
          try {
            await _supabaseService.insertCategory(entry.key, entry.value);
          } catch (e) {
            debugPrint('Failed to sync local category ${entry.key} to Supabase: $e');
          }
        }
      }
      
      for (var entry in remoteCategories.entries) {
        if (!_categories.containsKey(entry.key)) {
          _categories[entry.key] = entry.value;
          categoriesChanged = true;
        }
      }
      
      if (categoriesChanged) {
        await _storageService.saveCategories(_categories);
      }
      
      // If remote and local tasks are completely empty, seed default tasks and sync them!
      final hasSeeded = await _storageService.hasSeeded();
      if (!hasSeeded && _tasks.isEmpty) {
        await _seedDefaultData();
      }
      
      _notificationService.updateMonitoredTasks(_tasks);
    } catch (e) {
      debugPrint('Failed to refresh from Supabase: $e');
      // Fallback to local cached values
      _tasks = await _storageService.loadTasks();
      _categories = await _storageService.loadCategories();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // Filter setters
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedCategory(String? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setSelectedPriority(TaskPriority? priority) {
    _selectedPriority = priority;
    notifyListeners();
  }

  void setSelectedCompletionStatus(bool? status) {
    _selectedCompletionStatus = status;
    notifyListeners();
  }

  void setSortOption(TaskSortOption option) {
    _sortOption = option;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCategory = null;
    _selectedPriority = null;
    _selectedCompletionStatus = null;
    notifyListeners();
  }

  // Task Operations
  Future<void> addTask(Task task) async {
    _tasks.add(task);
    await _storageService.saveTasks(_tasks);
    _notificationService.updateMonitoredTasks(_tasks);
    notifyListeners();
    
    // Sync to Supabase in background
    if (_supabaseService.isActive && _supabaseService.isLoggedIn) {
      try {
        await _supabaseService.insertTask(task);
      } catch (e) {
        debugPrint('Failed to sync addTask to Supabase: $e');
      }
    }
  }

  Future<void> updateTask(Task task) async {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      // Safely manage completedAt based on completion state
      Task updatedTask = task;
      if (task.isCompleted && task.completedAt == null) {
        updatedTask = task.copyWith(completedAt: DateTime.now());
      } else if (!task.isCompleted) {
        updatedTask = task.copyWith(completedAt: null);
      }
      _tasks[index] = updatedTask;
      await _storageService.saveTasks(_tasks);
      _notificationService.updateMonitoredTasks(_tasks);
      notifyListeners();
      
      // Sync to Supabase in background
      if (_supabaseService.isActive && _supabaseService.isLoggedIn) {
        try {
          await _supabaseService.updateTask(updatedTask);
        } catch (e) {
          debugPrint('Failed to sync updateTask to Supabase: $e');
        }
      }
    }
  }

  Future<void> deleteTask(String id) async {
    _tasks.removeWhere((t) => t.id == id);
    await _storageService.saveTasks(_tasks);
    _notificationService.updateMonitoredTasks(_tasks);
    
    // Track offline deletions
    final deletedIds = await _storageService.loadDeletedTaskIds();
    if (!deletedIds.contains(id)) {
      deletedIds.add(id);
      await _storageService.saveDeletedTaskIds(deletedIds);
    }
    
    notifyListeners();
    
    // Sync to Supabase in background
    if (_supabaseService.isActive && _supabaseService.isLoggedIn) {
      try {
        await _supabaseService.deleteTask(id);
        // Successful delete: remove from offline delete tracker
        final currentDeleted = await _storageService.loadDeletedTaskIds();
        currentDeleted.remove(id);
        await _storageService.saveDeletedTaskIds(currentDeleted);
      } catch (e) {
        debugPrint('Failed to sync deleteTask to Supabase: $e');
      }
    }
  }

  Future<void> toggleTaskCompletion(String id) async {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      final task = _tasks[index];
      final newCompletionStatus = !task.isCompleted;
      final updatedTask = task.copyWith(
        isCompleted: newCompletionStatus,
        completedAt: newCompletionStatus ? DateTime.now() : null,
      );
      _tasks[index] = updatedTask;
      await _storageService.saveTasks(_tasks);
      _notificationService.updateMonitoredTasks(_tasks);
      notifyListeners();
      
      // Sync to Supabase in background
      if (_supabaseService.isActive && _supabaseService.isLoggedIn) {
        try {
          await _supabaseService.updateTask(updatedTask);
        } catch (e) {
          debugPrint('Failed to sync toggleTaskCompletion to Supabase: $e');
        }
      }
    }
  }

  // Category Operations
  Future<void> addCategory(String name, int colorVal) async {
    _categories[name] = colorVal;
    await _storageService.saveCategories(_categories);
    notifyListeners();
    
    // Sync to Supabase in background
    if (_supabaseService.isActive && _supabaseService.isLoggedIn) {
      try {
        await _supabaseService.insertCategory(name, colorVal);
      } catch (e) {
        debugPrint('Failed to sync addCategory to Supabase: $e');
      }
    }
  }

  Future<void> deleteCategory(String name) async {
    _categories.remove(name);
    
    // Move tasks in deleted category to 'Personal' or the first available category
    final fallback = _categories.isNotEmpty ? _categories.keys.first : 'Personal';
    _tasks = _tasks.map((task) {
      if (task.category == name) {
        return task.copyWith(category: fallback);
      }
      return task;
    }).toList();
    
    await _storageService.saveCategories(_categories);
    await _storageService.saveTasks(_tasks);
    notifyListeners();
    
    // Sync to Supabase in background
    if (_supabaseService.isActive && _supabaseService.isLoggedIn) {
      try {
        await _supabaseService.deleteCategory(name);
        // Also update all tasks that were in this category on remote
        for (var task in _tasks) {
          if (task.category == fallback) {
            await _supabaseService.updateTask(task);
          }
        }
      } catch (e) {
        debugPrint('Failed to sync deleteCategory to Supabase: $e');
      }
    }
  }

  // Theme Toggle
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _storageService.saveDarkMode(_isDarkMode);
    notifyListeners();
  }

  // Authentication operations
  Future<void> login(String username, {String? clientName}) async {
    _isLoading = true;
    notifyListeners();
    try {
      _isLoggedIn = true;
      _username = username;
      _clientName = clientName ?? 'Default Client';
      await _storageService.saveLoginStatus(true);
      await _storageService.saveUsername(username);
      await _storageService.saveClientName(_clientName);

      // Try anonymous Supabase sign-in
      if (_supabaseService.isActive && !_supabaseService.isLoggedIn) {
        try {
          await _supabaseService.signInAnonymously();
          _username = 'Guest_${_supabaseService.currentUser?.id.substring(0, 5) ?? 'User'}';
          await _storageService.saveUsername(_username);
        } catch (e) {
          debugPrint('Failed Supabase anonymous sign-in: $e');
        }
      }

      if (_supabaseService.isActive && _supabaseService.isLoggedIn) {
        await refreshFromSupabase();
      } else {
        _tasks = await _storageService.loadTasks();
        _categories = await _storageService.loadCategories();
      }
      await cleanupCompletedTasks();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signUpWithSupabase(String email, String password, {String? clientName}) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _supabaseService.signUp(email, password);
      // If sign up doesn't require confirmation, they might get logged in immediately
      if (_supabaseService.isLoggedIn) {
        _isLoggedIn = true;
        _username = _supabaseService.currentUser?.email?.split('@').first ?? 'User';
        _clientName = clientName ?? _username ?? 'Default Client';
        await _storageService.saveLoginStatus(true);
        await _storageService.saveUsername(_username);
        await _storageService.saveClientName(_clientName);
        await refreshFromSupabase();
        await cleanupCompletedTasks();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithSupabase(String email, String password, {String? clientName}) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _supabaseService.signIn(email, password);
      if (_supabaseService.isLoggedIn) {
        _isLoggedIn = true;
        _username = _supabaseService.currentUser?.email?.split('@').first ?? 'User';
        _clientName = clientName ?? _username ?? 'Default Client';
        await _storageService.saveLoginStatus(true);
        await _storageService.saveUsername(_username);
        await _storageService.saveClientName(_clientName);
        await refreshFromSupabase();
        await cleanupCompletedTasks();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    try {
      if (_supabaseService.isActive && _supabaseService.isLoggedIn) {
        await _supabaseService.signOut();
      }
      _isLoggedIn = false;
      _username = null;
      _tasks = [];
      await _storageService.saveLoginStatus(false);
      await _storageService.saveUsername(null);
      await _storageService.saveTasks([]);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Notification Permission operations
  String get notificationPermissionStatus => _notificationService.checkPermissionStatus();

  Future<void> requestNotificationPermission() async {
    await _notificationService.requestPermission();
    notifyListeners();
  }

  Future<void> updateClientName(String? name) async {
    _clientName = name ?? 'Default Client';
    await _storageService.saveClientName(_clientName);
    notifyListeners();
  }

  Future<void> cleanupCompletedTasks() async {
    final now = DateTime.now();
    final List<Task> toDelete = [];
    
    for (var task in _tasks) {
      if (task.isCompleted && task.completedAt != null) {
        final completedAt = task.completedAt!;
        // Deletion boundary: 4:00 AM on the target day
        DateTime targetDeletionTime = DateTime(
          completedAt.year,
          completedAt.month,
          completedAt.day,
          4,
          0,
        );
        
        // If completed at or after 4 AM, it deletes at 4 AM tomorrow
        final cutOffTime = DateTime(completedAt.year, completedAt.month, completedAt.day, 4, 0);
        if (!completedAt.isBefore(cutOffTime)) {
          targetDeletionTime = targetDeletionTime.add(const Duration(days: 1));
        }
        
        if (now.isAfter(targetDeletionTime)) {
          toDelete.add(task);
        }
      } else if (task.isCompleted && task.completedAt == null) {
        // Fallback: if completedAt is missing for some reason, delete it immediately if it's completed
        toDelete.add(task);
      }
    }
    
    if (toDelete.isNotEmpty) {
      final deletedIds = await _storageService.loadDeletedTaskIds();
      for (var task in toDelete) {
        _tasks.removeWhere((t) => t.id == task.id);
        if (!deletedIds.contains(task.id)) {
          deletedIds.add(task.id);
        }
        
        // Sync delete to Supabase
        if (_supabaseService.isActive && _supabaseService.isLoggedIn) {
          try {
            await _supabaseService.deleteTask(task.id);
            deletedIds.remove(task.id);
          } catch (e) {
            debugPrint('Failed to sync auto-delete task to Supabase: $e');
          }
        }
      }
      
      await _storageService.saveDeletedTaskIds(deletedIds);
      await _storageService.saveTasks(_tasks);
      _notificationService.updateMonitoredTasks(_tasks);
      notifyListeners();
      debugPrint('Auto-deleted ${toDelete.length} completed tasks at 4:00 AM boundary.');
    }
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    super.dispose();
  }

  // Clear data
  Future<void> resetApp() async {
    await _storageService.clearAll();
    await init();
  }

  // Stats helpers
  int get totalCount => _tasks.length;
  int get completedCount => _tasks.where((t) => t.isCompleted).length;
  int get pendingCount => _tasks.where((t) => !t.isCompleted).length;
  double get completionRate => totalCount == 0 ? 0.0 : completedCount / totalCount;

  Map<String, double> get categoryCompletionRates {
    final Map<String, double> rates = {};
    for (var cat in _categories.keys) {
      final catTasks = _tasks.where((t) => t.category == cat).toList();
      if (catTasks.isEmpty) {
        rates[cat] = 0.0;
      } else {
        final completedCat = catTasks.where((t) => t.isCompleted).length;
        rates[cat] = completedCat / catTasks.length;
      }
    }
    return rates;
  }

  Map<String, int> get categoryTaskCounts {
    final Map<String, int> counts = {};
    for (var cat in _categories.keys) {
      counts[cat] = _tasks.where((t) => t.category == cat).length;
    }
    return counts;
  }

  Future<void> _seedDefaultData() async {
    // 1. Default categories
    final Map<String, int> defaultCategories = {
      'Personal': 0xFF818CF8, // Indigo Accent
      'Work': 0xFFF87171,     // Red/Coral Accent
      'Shopping': 0xFF34D399, // Emerald Accent
      'Health': 0xFFF472B6,   // Pink Accent
      'Ideas': 0xFFFB7185,    // Rose Accent
    };

    _categories = defaultCategories;
    await _storageService.saveCategories(_categories);

    // If logged into Supabase, sync categories
    if (_supabaseService.isActive && _supabaseService.isLoggedIn) {
      for (var entry in _categories.entries) {
        try {
          await _supabaseService.insertCategory(entry.key, entry.value);
        } catch (e) {
          debugPrint('Failed to sync seeded category ${entry.key}: $e');
        }
      }
    }

    // 2. Default tasks
    final now = DateTime.now();
    final List<Task> defaultTasks = [
      Task(
        id: const Uuid().v4(),
        title: 'Welcome to FocusFlow! 🚀',
        description: 'This is a pre-seeded task to help you get started. Explore the workspace features and try editing or completing this task.',
        priority: TaskPriority.high,
        category: 'Work',
        dueDate: DateTime(now.year, now.month, now.day, 17, 0), // 5 PM today
        createdAt: now,
      ),
      Task(
        id: const Uuid().v4(),
        title: 'Plan your weekly schedule 📅',
        description: 'Use the Visual Planner tab to drag, schedule, and view your tasks visually.',
        priority: TaskPriority.medium,
        category: 'Personal',
        dueDate: DateTime(now.year, now.month, now.day + 1, 10, 0), // 10 AM tomorrow
        createdAt: now,
      ),
      Task(
        id: const Uuid().v4(),
        title: 'Pick up groceries 🛒',
        description: 'Milk, eggs, fresh vegetables, and fruits.',
        priority: TaskPriority.low,
        category: 'Shopping',
        dueDate: DateTime(now.year, now.month, now.day, 19, 0), // 7 PM today
        createdAt: now,
      ),
      Task(
        id: const Uuid().v4(),
        title: 'Evening jogging session 🏃‍♂️',
        description: '30-minute cardio run around the park.',
        priority: TaskPriority.medium,
        category: 'Health',
        dueDate: DateTime(now.year, now.month, now.day, 18, 0), // 6 PM today
        reminders: [DateTime(now.year, now.month, now.day, 18, 0)],
        createdAt: now,
      ),
      Task(
        id: const Uuid().v4(),
        title: 'Brainstorm new project concepts 💡',
        description: 'Write down initial thoughts and draft a design outline.',
        priority: TaskPriority.low,
        category: 'Ideas',
        dueDate: DateTime(now.year, now.month, now.day + 3, 14, 0), // 3 days from now
        createdAt: now,
      ),
    ];

    _tasks = defaultTasks;
    await _storageService.saveTasks(_tasks);

    // If logged into Supabase, sync tasks
    if (_supabaseService.isActive && _supabaseService.isLoggedIn) {
      for (var task in _tasks) {
        try {
          await _supabaseService.insertTask(task);
        } catch (e) {
          debugPrint('Failed to sync seeded task ${task.title}: $e');
        }
      }
    }

    await _storageService.setSeeded(true);
    notifyListeners();
  }
}

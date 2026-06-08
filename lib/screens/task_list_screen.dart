import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/task_provider.dart';
import '../theme/app_theme.dart';
import '../models/task.dart';
import '../widgets/task_editor_sheet.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<TaskProvider>(context, listen: false);
    _searchController.text = provider.searchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaskProvider>(context);
    final isDark = provider.isDarkMode;
    final tasks = provider.filteredTasks;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Workspace Tasks',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              IconButton(
                icon: const Icon(Icons.add_task),
                tooltip: 'Add Task',
                onPressed: () => _showTaskEditorSheet(context, null),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Search Bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search tasks by title or description...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        provider.setSearchQuery('');
                      },
                    )
                  : null,
            ),
            onChanged: (val) => provider.setSearchQuery(val),
          ),
          const SizedBox(height: 12),

          // Filters row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Status Filter
                _buildFilterChip(
                  context: context,
                  label: provider.selectedCompletionStatus == null
                      ? 'Status: All'
                      : provider.selectedCompletionStatus!
                          ? 'Completed'
                          : 'Pending',
                  icon: Icons.filter_alt_outlined,
                  onTap: () => _showStatusFilterDialog(context, provider),
                ),
                const SizedBox(width: 8),

                // Category Filter
                _buildFilterChip(
                  context: context,
                  label: provider.selectedCategory == null
                      ? 'Category: All'
                      : provider.selectedCategory!,
                  icon: Icons.category_outlined,
                  onTap: () => _showCategoryFilterDialog(context, provider),
                ),
                const SizedBox(width: 8),

                // Priority Filter
                _buildFilterChip(
                  context: context,
                  label: provider.selectedPriority == null
                      ? 'Priority: All'
                      : provider.selectedPriority!.name.toUpperCase(),
                  icon: Icons.outlined_flag,
                  onTap: () => _showPriorityFilterDialog(context, provider),
                ),
                const SizedBox(width: 8),

                // Sort Filter
                _buildFilterChip(
                  context: context,
                  label: 'Sort: ${_getSortLabel(provider.sortOption)}',
                  icon: Icons.sort_rounded,
                  onTap: () => _showSortDialog(context, provider),
                ),
                if (provider.searchQuery.isNotEmpty ||
                    provider.selectedCategory != null ||
                    provider.selectedPriority != null ||
                    provider.selectedCompletionStatus != null) ...[
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () {
                      provider.clearFilters();
                      _searchController.clear();
                    },
                    child: const Text('Reset Filters'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Task List
          Expanded(
            child: tasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.rule,
                          size: 64,
                          color: Colors.grey.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No tasks found.',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.grey,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your search filters or add a new task.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      final catColor = Color(
                          provider.categories[task.category] ?? 0xFF818CF8);
                      
                      return Padding(
                        key: ValueKey(task.id),
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Dismissible(
                          key: Key(task.id),
                          background: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 20),
                            decoration: BoxDecoration(
                              gradient: AppTheme.successGradient,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.check, color: Colors.white),
                          ),
                          secondaryBackground: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              gradient: AppTheme.dangerGradient,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.delete_outline,
                                color: Colors.white),
                          ),
                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.startToEnd) {
                              provider.toggleTaskCompletion(task.id);
                              return false; // Toggle completes inline, don't dismiss card
                            } else {
                              return true; // Dismiss the card for delete
                            }
                          },
                          onDismissed: (direction) {
                            if (direction == DismissDirection.endToStart) {
                              provider.deleteTask(task.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Deleted "${task.title}"'),
                                  action: SnackBarAction(
                                    label: 'Undo',
                                    onPressed: () {
                                      provider.addTask(task);
                                    },
                                  ),
                                ),
                              );
                            }
                          },
                          child: InkWell(
                            onTap: () => _showTaskEditorSheet(context, task),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              decoration: AppTheme.glassDecoration(
                                isDark: isDark,
                                opacity: task.isCompleted ? 0.35 : 0.65,
                                radius: 16,
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Completion check box
                                  IconButton(
                                    icon: Icon(
                                      task.isCompleted
                                          ? Icons.check_circle
                                          : Icons.circle_outlined,
                                      color: task.isCompleted
                                          ? AppTheme.darkSecondary
                                          : catColor,
                                      size: 24,
                                    ),
                                    onPressed: () =>
                                        provider.toggleTaskCompletion(task.id),
                                  ),
                                  const SizedBox(width: 8),
                                  // Task Content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          task.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                decoration: task.isCompleted
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                                color: task.isCompleted
                                                    ? Colors.grey
                                                    : null,
                                              ),
                                        ),
                                        if (task.description.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            task.description,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  fontSize: 12,
                                                ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                        const SizedBox(height: 12),
                                        // Category and due date info badges
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          children: [
                                            // Category Tag
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: catColor.withOpacity(0.12),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: catColor.withOpacity(0.3),
                                                  width: 0.8,
                                                ),
                                              ),
                                              child: Text(
                                                task.category,
                                                style: TextStyle(
                                                  color: catColor,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            // Due Date Tag
                                            if (task.dueDate != null)
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.event,
                                                        size: 10, color: Colors.grey),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      DateFormat('MMM d, yyyy')
                                                          .format(task.dueDate!),
                                                      style: const TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            // Priority Tag
                                            _buildPriorityBadge(task.priority),
                                            // Reminder count tag
                                            if (task.reminders.isNotEmpty)
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber.withOpacity(0.08),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: Colors.amber.withOpacity(0.3),
                                                    width: 0.8,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.alarm,
                                                        size: 10,
                                                        color: Colors.amber),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${task.reminders.length}',
                                                      style: const TextStyle(
                                                        color: Colors.amber,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required BuildContext context,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final provider = Provider.of<TaskProvider>(context, listen: false);
    final isDark = provider.isDarkMode;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.grey),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(TaskPriority priority) {
    Color color;
    String label = priority.name.toUpperCase();
    switch (priority) {
      case TaskPriority.high:
        color = Colors.redAccent;
        break;
      case TaskPriority.medium:
        color = Colors.orangeAccent;
        break;
      case TaskPriority.low:
        color = Colors.blueAccent;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Filters Dialogs
  void _showStatusFilterDialog(BuildContext context, TaskProvider provider) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Filter by Status'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              provider.setSelectedCompletionStatus(null);
              Navigator.pop(context);
            },
            child: const Text('All Tasks'),
          ),
          SimpleDialogOption(
            onPressed: () {
              provider.setSelectedCompletionStatus(false);
              Navigator.pop(context);
            },
            child: const Text('Pending Tasks Only'),
          ),
          SimpleDialogOption(
            onPressed: () {
              provider.setSelectedCompletionStatus(true);
              Navigator.pop(context);
            },
            child: const Text('Completed Tasks Only'),
          ),
        ],
      ),
    );
  }

  void _showCategoryFilterDialog(BuildContext context, TaskProvider provider) {
    final categories = provider.categories.keys.toList();
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Filter by Category'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              provider.setSelectedCategory(null);
              Navigator.pop(context);
            },
            child: const Text('All Categories'),
          ),
          ...categories.map(
            (cat) => SimpleDialogOption(
              onPressed: () {
                provider.setSelectedCategory(cat);
                Navigator.pop(context);
              },
              child: Text(cat),
            ),
          ),
        ],
      ),
    );
  }

  void _showPriorityFilterDialog(BuildContext context, TaskProvider provider) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Filter by Priority'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              provider.setSelectedPriority(null);
              Navigator.pop(context);
            },
            child: const Text('All Priorities'),
          ),
          ...TaskPriority.values.map(
            (p) => SimpleDialogOption(
              onPressed: () {
                provider.setSelectedPriority(p);
                Navigator.pop(context);
              },
              child: Text(p.name.toUpperCase()),
            ),
          ),
        ],
      ),
    );
  }

  String _getSortLabel(TaskSortOption option) {
    switch (option) {
      case TaskSortOption.priority:
        return 'Priority';
      case TaskSortOption.dueDate:
        return 'Due Date';
      case TaskSortOption.category:
        return 'Category';
      case TaskSortOption.dateCreated:
        return 'Date Created';
    }
  }

  void _showSortDialog(BuildContext context, TaskProvider provider) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Sort Tasks'),
        children: TaskSortOption.values.map((option) {
          final isSelected = provider.sortOption == option;
          return SimpleDialogOption(
            onPressed: () {
              provider.setSortOption(option);
              Navigator.pop(context);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_getSortLabel(option)),
                if (isSelected)
                  Icon(Icons.check, size: 16, color: Theme.of(context).colorScheme.primary),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // BOTTOM SHEET EDITOR FOR ADDING & EDITING TASKS WITH REMINDERS
  void _showTaskEditorSheet(BuildContext context, Task? existingTask) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskEditorSheet(
        existingTask: existingTask,
      ),
    );
  }
}

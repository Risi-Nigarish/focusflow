import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../providers/task_provider.dart';
import '../theme/app_theme.dart';
import '../models/task.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _quickAddController = TextEditingController();
  String _selectedQuickCategory = 'Personal';
  TaskPriority _selectedQuickPriority = TaskPriority.medium;
  DateTime? _selectedQuickDueDate;
  final List<DateTime> _quickReminders = [];

  void _submitQuickTask(TaskProvider provider) {
    final title = _quickAddController.text.trim();
    if (title.isEmpty) return;

    final category = provider.categories.containsKey(_selectedQuickCategory)
        ? _selectedQuickCategory
        : (provider.categories.isNotEmpty ? provider.categories.keys.first : 'Personal');

    final newTask = Task(
      id: const Uuid().v4(),
      title: title,
      createdAt: DateTime.now(),
      category: category,
      priority: _selectedQuickPriority,
      dueDate: _selectedQuickDueDate,
      reminders: List.from(_quickReminders),
    );

    provider.addTask(newTask);
    _quickAddController.clear();
    setState(() {
      _selectedQuickPriority = TaskPriority.medium;
      _selectedQuickDueDate = null;
      _quickReminders.clear();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Task "$title" added successfully!'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _quickAddController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaskProvider>(context);
    final isDark = provider.isDarkMode;
    final now = DateTime.now();
    final formattedDate = DateFormat('EEEE, MMMM d').format(now);

    final completed = provider.completedCount;
    final total = provider.totalCount;

    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting & Date Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_getGreeting()},\n${provider.clientName ?? 'Workspace'}',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedDate,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Cloud Sync Status Indicator
              _buildSyncIndicator(context, provider, isDark),
              const SizedBox(width: 12),
              // Mini statistics indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: AppTheme.glassDecoration(isDark: isDark, radius: 12),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: AppTheme.darkSecondary, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '$completed/$total Completed',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Main Layout split for desktop/mobile
          isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildLeftColumn(provider, isDark)),
                    const SizedBox(width: 24),
                    Expanded(flex: 2, child: _buildRightColumn(provider, isDark)),
                  ],
                )
              : Column(
                  children: [
                    _buildLeftColumn(provider, isDark),
                    const SizedBox(height: 24),
                    _buildRightColumn(provider, isDark),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildLeftColumn(TaskProvider provider, bool isDark) {
    final rate = provider.completionRate;
    final ratePercent = (rate * 100).toStringAsFixed(0);
    final completed = provider.completedCount;
    final pending = provider.pendingCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick Add Box
        Container(
          decoration: AppTheme.glassDecoration(isDark: isDark, opacity: 0.5),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _quickAddController,
                      decoration: const InputDecoration(
                        hintText: 'Add a quick task (Press Enter)...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        fillColor: Colors.transparent,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => _submitQuickTask(provider),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, size: 28),
                    color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent,
                    onPressed: () => _submitQuickTask(provider),
                  ),
                ],
              ),
              if (provider.categories.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: provider.categories.keys.map((catName) {
                    final catColorVal = provider.categories[catName] ?? 0xFF818CF8;
                    final catColor = Color(catColorVal);
                    final isSelected = _selectedQuickCategory == catName;
                    return ChoiceChip(
                      label: Text(
                        catName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isSelected 
                              ? Colors.white 
                              : (isDark ? Colors.white60 : Colors.black87),
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: catColor,
                      backgroundColor: isDark 
                          ? AppTheme.darkBg.withOpacity(0.3) 
                          : AppTheme.lightBg.withOpacity(0.3),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedQuickCategory = catName;
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Priority:  ',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  ...TaskPriority.values.map((prio) {
                    Color color;
                    switch (prio) {
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
                    final isSelected = _selectedQuickPriority == prio;
                    return ChoiceChip(
                      label: Text(
                        prio.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected 
                              ? Colors.white 
                              : (isDark ? Colors.white60 : Colors.black87),
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: color,
                      backgroundColor: isDark 
                          ? AppTheme.darkBg.withOpacity(0.3) 
                          : AppTheme.lightBg.withOpacity(0.3),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedQuickPriority = prio;
                          });
                        }
                      },
                    );
                  }),
                ],
              ),
              const SizedBox(height: 12),
              // Due Date & Reminders Quick Controls
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Due Date Trigger
                  TextButton.icon(
                    onPressed: () async {
                      final chosen = await showDatePicker(
                        context: context,
                        initialDate: _selectedQuickDueDate ?? DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                      );
                      if (chosen != null) {
                        setState(() {
                          _selectedQuickDueDate = chosen;
                        });
                      }
                    },
                    icon: Icon(
                      Icons.event_outlined,
                      size: 16,
                      color: _selectedQuickDueDate != null 
                          ? (isDark ? AppTheme.darkAccent : AppTheme.lightAccent) 
                          : Colors.grey,
                    ),
                    label: Text(
                      _selectedQuickDueDate == null 
                          ? 'Set Due Date' 
                          : DateFormat('MMM d, yyyy').format(_selectedQuickDueDate!),
                      style: TextStyle(
                        fontSize: 11,
                        color: _selectedQuickDueDate != null 
                            ? (isDark ? Colors.white : Colors.black87) 
                            : Colors.grey,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  if (_selectedQuickDueDate != null) ...[
                    IconButton(
                      icon: const Icon(Icons.clear, size: 12, color: Colors.redAccent),
                      onPressed: () {
                        setState(() {
                          _selectedQuickDueDate = null;
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 12,
                    ),
                  ],
                  const SizedBox(width: 8),
                  
                  // Reminder Trigger
                  TextButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date == null) return;
                      if (!mounted) return;
                      
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time == null) return;
                      if (!mounted) return;

                      final reminderDateTime = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      );

                      if (reminderDateTime.isAfter(DateTime.now())) {
                        setState(() {
                          _quickReminders.add(reminderDateTime);
                          _quickReminders.sort();
                        });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cannot set reminders in the past!'),
                            backgroundColor: Colors.redAccent,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    icon: Icon(
                      Icons.alarm_add_outlined,
                      size: 16,
                      color: _quickReminders.isNotEmpty ? Colors.amber : Colors.grey,
                    ),
                    label: Text(
                      _quickReminders.isEmpty 
                          ? 'Add Alert' 
                          : '${_quickReminders.length} Alert${_quickReminders.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        color: _quickReminders.isNotEmpty 
                            ? Colors.amber 
                            : Colors.grey,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              
              // Reminders list preview
              if (_quickReminders.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _quickReminders.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final time = entry.value;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkCard.withOpacity(0.4) : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.withOpacity(0.15)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.alarm, size: 10, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MMM d, h:mm a').format(time),
                            style: const TextStyle(fontSize: 9),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _quickReminders.removeAt(idx);
                              });
                            },
                            child: const Icon(Icons.close, size: 10, color: Colors.redAccent),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Donut Chart & Overview Stats Card
        Container(
          width: double.infinity,
          decoration: AppTheme.glassDecoration(isDark: isDark),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Task Metrics',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  // Donut chart
                  SizedBox(
                    height: 140,
                    width: 140,
                    child: Stack(
                      children: [
                        PieChart(
                          PieChartData(
                            sectionsSpace: 4,
                            centerSpaceRadius: 50,
                            startDegreeOffset: -90,
                            sections: [
                              PieChartSectionData(
                                color: isDark ? AppTheme.darkSecondary : AppTheme.lightSecondary,
                                value: completed == 0 && pending == 0 ? 1 : completed.toDouble(),
                                title: '',
                                radius: 14,
                              ),
                              PieChartSectionData(
                                color: Colors.grey.withOpacity(isDark ? 0.15 : 0.25),
                                value: completed == 0 && pending == 0 ? 0 : pending.toDouble(),
                                title: '',
                                radius: 10,
                              ),
                            ],
                          ),
                        ),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$ratePercent%',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              Text(
                                'Done',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  // Legends and stats details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatIndicator(
                          color: isDark ? AppTheme.darkSecondary : AppTheme.lightSecondary,
                          label: 'Completed Tasks',
                          value: '$completed',
                        ),
                        const SizedBox(height: 12),
                        _buildStatIndicator(
                          color: Colors.grey.withOpacity(0.5),
                          label: 'Pending Tasks',
                          value: '$pending',
                        ),
                        const SizedBox(height: 12),
                        _buildStatIndicator(
                          color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent,
                          label: 'Total Active Tasks',
                          value: '${provider.totalCount}',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Categories Workload List
        Container(
          width: double.infinity,
          decoration: AppTheme.glassDecoration(isDark: isDark),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Workload by Category',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 18),
              provider.categories.isEmpty
                  ? const Text('No categories available.')
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: provider.categories.length,
                      itemBuilder: (context, index) {
                        final catName = provider.categories.keys.elementAt(index);
                        final catColorVal = provider.categories.values.elementAt(index);
                        final catColor = Color(catColorVal);
                        
                        final count = provider.categoryTaskCounts[catName] ?? 0;
                        final totalTasks = provider.totalCount;
                        final ratio = totalTasks == 0 ? 0.0 : count / totalTasks;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: catColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        catName,
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontSize: 14,
                                            ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '$count tasks (${(ratio * 100).toStringAsFixed(0)}%)',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: ratio,
                                  minHeight: 6,
                                  backgroundColor: Colors.grey.withOpacity(isDark ? 0.1 : 0.2),
                                  valueColor: AlwaysStoppedAnimation<Color>(catColor),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRightColumn(TaskProvider provider, bool isDark) {
    // Show only active, high priority, or today's tasks
    final todayTasks = provider.allTasks
        .where((t) => !t.isCompleted)
        .take(5) // Limit to top 5
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Daily Focus Card
        Container(
          width: double.infinity,
          decoration: AppTheme.glassDecoration(isDark: isDark),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Focus Tasks',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              todayTasks.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            Icon(Icons.spa, size: 48, color: Colors.grey.withOpacity(0.4)),
                            const SizedBox(height: 12),
                            Text(
                              'All caught up! Start adding tasks.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: todayTasks.length,
                      itemBuilder: (context, index) {
                        final task = todayTasks[index];
                        final catColor = Color(provider.categories[task.category] ?? 0xFF818CF8);
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: InkWell(
                            onTap: () => provider.toggleTaskCompletion(task.id),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark 
                                    ? AppTheme.darkBg.withOpacity(0.4) 
                                    : AppTheme.lightBg.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey.withOpacity(0.15),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.circle_outlined,
                                    color: catColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          task.title,
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          task.category,
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                fontSize: 11,
                                                color: catColor.withOpacity(0.8),
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (task.priority == TaskPriority.high)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'HIGH',
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Interactive Reminder Count Card
        (() {
          final activeReminders = provider.allTasks
              .where((t) => !t.isCompleted)
              .fold<int>(0, (sum, task) => sum + task.reminders.length);
          final permissionStatus = provider.notificationPermissionStatus;
          final isGranted = permissionStatus == 'granted';
          final isUnsupported = permissionStatus == 'unsupported';

          return InkWell(
            onTap: isGranted || isUnsupported
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await provider.requestNotificationPermission();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Browser Notification Permission: ${provider.notificationPermissionStatus}'),
                        backgroundColor: provider.notificationPermissionStatus == 'granted' 
                            ? AppTheme.darkSecondary 
                            : Colors.redAccent,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              decoration: AppTheme.glassDecoration(
                isDark: isDark, 
                opacity: 0.85,
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: isGranted 
                          ? AppTheme.primaryGradient 
                          : (isUnsupported ? AppTheme.primaryGradient : AppTheme.dangerGradient),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isGranted ? Icons.alarm : (isUnsupported ? Icons.alarm : Icons.notification_important_outlined), 
                      color: Colors.white, 
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Monitored Reminders',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isGranted 
                                    ? Colors.green.withOpacity(0.1) 
                                    : (isUnsupported ? Colors.grey.withOpacity(0.1) : Colors.red.withOpacity(0.1)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isGranted ? 'ACTIVE' : (isUnsupported ? 'LOCAL ONLY' : 'BLOCKED'),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isGranted 
                                      ? Colors.green 
                                      : (isUnsupported ? Colors.grey : Colors.redAccent),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isGranted
                              ? 'Monitoring $activeReminders reminders with browser notifications.'
                              : (isUnsupported 
                                  ? 'Monitoring $activeReminders reminders in-app (Local alarms only).'
                                  : 'Tap to grant browser alerts permission for $activeReminders reminders.'),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        })(),
      ],
    );
  }

  Widget _buildSyncIndicator(BuildContext context, TaskProvider provider, bool isDark) {
    IconData icon;
    Color color;
    String tooltip;
    Widget child;

    if (!provider.isSupabaseConfigured) {
      icon = Icons.cloud_off_outlined;
      color = Colors.grey;
      tooltip = 'Supabase Database Not Configured';
      child = Icon(icon, color: color, size: 16);
    } else if (provider.isSyncing) {
      color = isDark ? AppTheme.darkAccent : AppTheme.lightAccent;
      tooltip = 'Syncing tasks with Supabase Database...';
      child = SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    } else if (provider.isLoggedIn) {
      icon = Icons.cloud_done_outlined;
      color = Colors.greenAccent;
      tooltip = 'All tasks safely synced with Supabase Database';
      child = Icon(icon, color: color, size: 16);
    } else {
      icon = Icons.cloud_queue_outlined;
      color = Colors.grey;
      tooltip = 'Local Offline Cache Mode (No Database Sync)';
      child = Icon(icon, color: color, size: 16);
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: AppTheme.glassDecoration(isDark: isDark, radius: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            child,
            const SizedBox(width: 6),
            Text(
              provider.isSyncing
                  ? 'Syncing'
                  : (provider.isLoggedIn ? 'Synced' : 'Local Only'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatIndicator({
    required Color color,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }
}

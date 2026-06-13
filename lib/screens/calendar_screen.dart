import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../providers/task_provider.dart';
import '../models/task.dart';
import '../theme/app_theme.dart';
import '../widgets/task_editor_sheet.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  final TextEditingController _calendarQuickAddController = TextEditingController();
  String _selectedCalendarCategory = 'Personal';
  TaskPriority _selectedCalendarPriority = TaskPriority.medium;
  DateTime? _selectedQuickDueDate;
  TimeOfDay? _selectedQuickAlertTime;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _selectedQuickDueDate = _selectedDay;
    final provider = Provider.of<TaskProvider>(context, listen: false);
    if (provider.categories.isNotEmpty) {
      _selectedCalendarCategory = provider.categories.keys.first;
    }
  }

  @override
  void dispose() {
    _calendarQuickAddController.dispose();
    super.dispose();
  }

  void _submitCalendarTask(TaskProvider provider) {
    final title = _calendarQuickAddController.text.trim();
    if (title.isEmpty) return;

    final category = provider.categories.containsKey(_selectedCalendarCategory)
        ? _selectedCalendarCategory
        : (provider.categories.isNotEmpty ? provider.categories.keys.first : 'Personal');

    final List<DateTime> reminders = [];
    final dueDate = _selectedQuickDueDate ?? _selectedDay ?? DateTime.now();

    if (_selectedQuickAlertTime != null) {
      final reminderTime = DateTime(
        dueDate.year,
        dueDate.month,
        dueDate.day,
        _selectedQuickAlertTime!.hour,
        _selectedQuickAlertTime!.minute,
      );

      if (reminderTime.isAfter(DateTime.now())) {
        reminders.add(reminderTime);
      }
    }

    final newTask = Task(
      id: const Uuid().v4(),
      title: title,
      createdAt: DateTime.now(),
      dueDate: dueDate,
      category: category,
      priority: _selectedCalendarPriority,
      reminders: reminders,
    );

    provider.addTask(newTask);
    _calendarQuickAddController.clear();
    
    setState(() {
      _selectedQuickAlertTime = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Task "$title" scheduled for ${DateFormat('MMM d').format(dueDate)}!'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  List<Task> _getTasksForDay(DateTime day, List<Task> tasks) {
    final list = tasks.where((task) {
      final isSameDue = task.dueDate != null && isSameDay(task.dueDate, day);
      final hasReminderToday = task.reminders.any((reminder) => isSameDay(reminder, day));
      return isSameDue || hasReminderToday;
    }).toList();

    list.sort((a, b) {
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      if (a.priority != b.priority) {
        return b.priority.index.compareTo(a.priority.index); // high priority first
      }
      return b.createdAt.compareTo(a.createdAt);
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaskProvider>(context);
    final isDark = provider.isDarkMode;
    final allTasks = provider.allTasks;
    
    final selectedDayTasks = _selectedDay != null 
        ? _getTasksForDay(_selectedDay!, allTasks) 
        : <Task>[];

    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 850 && size.height > 600;


    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isDesktop ? 1200 : 800),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: isDesktop
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Text(
                      'Visual Planner',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Plan tasks and view scheduled reminders visually.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: _buildCalendarCard(isDark, allTasks),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 4,
                            child: _buildDayTaskList(isDark, selectedDayTasks, provider, isMobile: false),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Text(
                        'Visual Planner',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Plan tasks and view scheduled reminders visually.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      _buildCalendarCard(isDark, allTasks),
                      const SizedBox(height: 24),
                      _buildDayTaskList(isDark, selectedDayTasks, provider, isMobile: true),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildCalendarCard(bool isDark, List<Task> allTasks) {
    return Container(
      decoration: AppTheme.glassDecoration(isDark: isDark),
      padding: const EdgeInsets.all(16),
      child: TableCalendar<Task>(
        firstDay: DateTime.now().subtract(const Duration(days: 365)),
        lastDay: DateTime.now().add(const Duration(days: 365 * 3)),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
            _selectedQuickDueDate = selectedDay;
          });
        },
        onFormatChanged: (format) {
          if (_calendarFormat != format) {
            setState(() {
              _calendarFormat = format;
            });
          }
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
        eventLoader: (day) => _getTasksForDay(day, allTasks),
        
        // Custom styling for calendar
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          defaultTextStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
          weekendTextStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
          
          selectedDecoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: (isDark ? AppTheme.darkAccent : AppTheme.lightAccent).withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent,
              width: 1,
            ),
          ),
          
          markerSize: 5.5,
          markerMargin: const EdgeInsets.symmetric(horizontal: 1.2, vertical: 3.5),
          markersMaxCount: 4,
          markersAlignment: Alignment.bottomCenter,
        ),
        
        // Custom marker builder to represent category dots
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, day, events) {
            if (events.isEmpty) return const SizedBox();
            
            // Build colored dots matching the categories
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: events.take(4).map((task) {
                final provider = Provider.of<TaskProvider>(context, listen: false);
                final color = Color(provider.categories[task.category] ?? 0xFF818CF8);
                return Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 0.8),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                );
              }).toList(),
            );
          },
        ),

        headerStyle: HeaderStyle(
          formatButtonVisible: true,
          titleCentered: true,
          formatButtonDecoration: BoxDecoration(
            border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
            borderRadius: BorderRadius.circular(12),
          ),
          formatButtonTextStyle: TextStyle(
            color: isDark ? Colors.white70 : Colors.black87,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          titleTextStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
          leftChevronIcon: Icon(Icons.chevron_left, color: isDark ? Colors.white70 : Colors.black87),
          rightChevronIcon: Icon(Icons.chevron_right, color: isDark ? Colors.white70 : Colors.black87),
        ),
      ),
    );
  }

  Widget _buildDayTaskList(bool isDark, List<Task> dayTasks, TaskProvider provider, {required bool isMobile}) {
    final formattedSelectedDay = _selectedDay != null 
        ? DateFormat('MMMM d, yyyy').format(_selectedDay!) 
        : 'Select a day';

    return Container(
      decoration: AppTheme.glassDecoration(isDark: isDark),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_note, color: Colors.grey, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  formattedSelectedDay,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isDark ? AppTheme.darkAccent : AppTheme.lightAccent).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${dayTasks.length} Scheduled',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.add_circle_outline,
                  color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent,
                  size: 20,
                ),
                tooltip: 'Add Task to Day',
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => TaskEditorSheet(
                      existingTask: null,
                      prefilledDate: _selectedDay,
                    ),
                  );
                },
                splashRadius: 18,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const Divider(height: 16),
          // Calendar Quick Add Panel
          if (_selectedDay != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard.withOpacity(0.5) : Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _calendarQuickAddController,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Quick add task for this day...',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 6),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                          onSubmitted: (_) => _submitCalendarTask(provider),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle, size: 22),
                        color: isDark ? AppTheme.darkAccent : AppTheme.lightAccent,
                        onPressed: () => _submitCalendarTask(provider),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const Divider(height: 12),
                  // Date & Time selectors directly visible outside
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Date Selector Button
                      TextButton.icon(
                        onPressed: () async {
                          final chosen = await showDatePicker(
                            context: context,
                            initialDate: _selectedQuickDueDate ?? _selectedDay ?? DateTime.now(),
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
                          size: 14,
                          color: _selectedQuickDueDate != null
                              ? (isDark ? AppTheme.darkAccent : AppTheme.lightAccent)
                              : Colors.grey,
                        ),
                        label: Text(
                          _selectedQuickDueDate == null
                              ? 'Set Date'
                              : DateFormat('MMM d, yyyy').format(_selectedQuickDueDate!),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _selectedQuickDueDate != null
                                ? (isDark ? Colors.white : Colors.black87)
                                : Colors.grey,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      if (_selectedQuickDueDate != null && _selectedQuickDueDate != _selectedDay) ...[
                        const SizedBox(width: 2),
                        IconButton(
                          icon: const Icon(Icons.clear, size: 10, color: Colors.redAccent),
                          onPressed: () {
                            setState(() {
                              _selectedQuickDueDate = _selectedDay;
                            });
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 10,
                        ),
                      ],
                      const SizedBox(width: 8),
                      
                      // Time Selector Button
                      TextButton.icon(
                        onPressed: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: _selectedQuickAlertTime ?? TimeOfDay.now(),
                          );
                          if (time != null) {
                            setState(() {
                              _selectedQuickAlertTime = time;
                            });
                          }
                        },
                        icon: Icon(
                          Icons.alarm_add_outlined,
                          size: 14,
                          color: _selectedQuickAlertTime != null ? Colors.amber : Colors.grey,
                        ),
                        label: Text(
                          _selectedQuickAlertTime == null
                              ? 'Add Alert Time'
                              : _selectedQuickAlertTime!.format(context),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _selectedQuickAlertTime != null ? Colors.amber : Colors.grey,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      if (_selectedQuickAlertTime != null) ...[
                        const SizedBox(width: 2),
                        IconButton(
                          icon: const Icon(Icons.clear, size: 10, color: Colors.redAccent),
                          onPressed: () {
                            setState(() {
                              _selectedQuickAlertTime = null;
                            });
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 10,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Priority label
                      const Text(
                        'Priority: ',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
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
                        final isSelected = _selectedCalendarPriority == prio;
                        return ChoiceChip(
                          label: Text(
                            prio.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isSelected 
                                  ? Colors.white 
                                  : (isDark ? Colors.white60 : Colors.black87),
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: color,
                          backgroundColor: isDark 
                              ? AppTheme.darkCard.withOpacity(0.5) 
                              : Colors.white.withOpacity(0.5),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedCalendarPriority = prio;
                              });
                            }
                          },
                        );
                      }),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          '|',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ),
                      const Text(
                        'Cat: ',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      ...provider.categories.keys.map((cat) {
                        final isSelected = _selectedCalendarCategory == cat;
                        final catColor = Color(provider.categories[cat] ?? 0xFF818CF8);
                        return ChoiceChip(
                          label: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isSelected 
                                  ? Colors.white 
                                  : (isDark ? Colors.white60 : Colors.black87),
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: catColor,
                          backgroundColor: isDark 
                              ? AppTheme.darkCard.withOpacity(0.5) 
                              : Colors.white.withOpacity(0.5),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedCalendarCategory = cat;
                              });
                            }
                          },
                        );
                      }),
                    ],
                  ),

                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          isMobile
              ? (dayTasks.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.calendar_today, size: 40, color: Colors.grey.withOpacity(0.3)),
                            const SizedBox(height: 12),
                            const Text(
                              'No tasks or reminders\nscheduled for this day.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: dayTasks.length,
                      itemBuilder: (context, index) {
                        final task = dayTasks[index];
                        final catColor = Color(provider.categories[task.category] ?? 0xFF818CF8);
                        
                        return InkWell(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => TaskEditorSheet(
                                existingTask: task,
                                prefilledDate: _selectedDay,
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark 
                                  ? AppTheme.darkBg.withOpacity(0.3) 
                                  : AppTheme.lightBg.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.withOpacity(0.12)),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: Icon(
                                    task.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                                    color: task.isCompleted ? AppTheme.darkSecondary : catColor,
                                    size: 20,
                                  ),
                                  onPressed: () => provider.toggleTaskCompletion(task.id),
                                  splashRadius: 18,
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        task.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                          color: task.isCompleted ? Colors.grey : null,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  color: catColor,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                task.category,
                                                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                              ),
                                            ],
                                          ),
                                          if (task.dueDate != null)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.event, size: 10, color: Colors.grey[500]),
                                                const SizedBox(width: 3),
                                                Text(
                                                  'Due: ${DateFormat('MMM d').format(task.dueDate!)}',
                                                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                      if (task.reminders.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 4,
                                          runSpacing: 4,
                                          children: task.reminders
                                              .where((r) => isSameDay(r, _selectedDay))
                                              .map((r) => Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.amber.withOpacity(0.08),
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: Colors.amber.withOpacity(0.3), width: 0.8),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(Icons.alarm, size: 8, color: Colors.amber),
                                                        const SizedBox(width: 3),
                                                        Text(
                                                          DateFormat('h:mm a').format(r),
                                                          style: const TextStyle(
                                                            fontSize: 9,
                                                            color: Colors.amber,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ))
                                              .toList(),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildPriorityBadge(task.priority),
                              ],
                            ),
                          ),
                        );
                      },
                    ))
              : Expanded(
                  child: dayTasks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.calendar_today, size: 40, color: Colors.grey.withOpacity(0.3)),
                              const SizedBox(height: 12),
                              const Text(
                                'No tasks or reminders\nscheduled for this day.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: dayTasks.length,
                          itemBuilder: (context, index) {
                            final task = dayTasks[index];
                            final catColor = Color(provider.categories[task.category] ?? 0xFF818CF8);
                            
                            return InkWell(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => TaskEditorSheet(
                                    existingTask: task,
                                    prefilledDate: _selectedDay,
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark 
                                      ? AppTheme.darkBg.withOpacity(0.3) 
                                      : AppTheme.lightBg.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.withOpacity(0.12)),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        task.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                                        color: task.isCompleted ? AppTheme.darkSecondary : catColor,
                                        size: 20,
                                      ),
                                      onPressed: () => provider.toggleTaskCompletion(task.id),
                                      splashRadius: 18,
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            task.title,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                              color: task.isCompleted ? Colors.grey : null,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 4,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: 6,
                                                    height: 6,
                                                    decoration: BoxDecoration(
                                                      color: catColor,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    task.category,
                                                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                                  ),
                                                ],
                                              ),
                                              if (task.dueDate != null)
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.event, size: 10, color: Colors.grey[500]),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      'Due: ${DateFormat('MMM d').format(task.dueDate!)}',
                                                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                          if (task.reminders.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 4,
                                              runSpacing: 4,
                                              children: task.reminders
                                                  .where((r) => isSameDay(r, _selectedDay))
                                                  .map((r) => Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: Colors.amber.withOpacity(0.08),
                                                          borderRadius: BorderRadius.circular(4),
                                                          border: Border.all(color: Colors.amber.withOpacity(0.3), width: 0.8),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            const Icon(Icons.alarm, size: 8, color: Colors.amber),
                                                            const SizedBox(width: 3),
                                                            Text(
                                                              DateFormat('h:mm a').format(r),
                                                              style: const TextStyle(
                                                                fontSize: 9,
                                                                color: Colors.amber,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ))
                                                  .toList(),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildPriorityBadge(task.priority),
                                  ],
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
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

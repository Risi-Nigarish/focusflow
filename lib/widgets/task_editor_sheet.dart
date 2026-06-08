import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../providers/task_provider.dart';
import '../theme/app_theme.dart';
import '../models/task.dart';

class TaskEditorSheet extends StatefulWidget {
  final Task? existingTask;
  final DateTime? prefilledDate;

  const TaskEditorSheet({
    super.key,
    this.existingTask,
    this.prefilledDate,
  });

  @override
  State<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<TaskEditorSheet> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late String _selectedCategory;
  late TaskPriority _selectedPriority;
  DateTime? _selectedDueDate;
  late List<DateTime> _reminders;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<TaskProvider>(context, listen: false);
    
    _titleController = TextEditingController(text: widget.existingTask?.title ?? '');
    _descController = TextEditingController(text: widget.existingTask?.description ?? '');
    
    _selectedCategory = widget.existingTask?.category ?? 
        (provider.categories.isNotEmpty ? provider.categories.keys.first : 'Personal');
    
    _selectedPriority = widget.existingTask?.priority ?? TaskPriority.medium;
    
    // Pre-fill with calendar date if provided and creating a new task
    _selectedDueDate = widget.existingTask?.dueDate ?? widget.prefilledDate;
    
    _reminders = List.from(widget.existingTask?.reminders ?? []);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaskProvider>(context);
    final isDark = provider.isDarkMode;
    final isEditing = widget.existingTask != null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBg : AppTheme.lightBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1.5,
        ),
      ),
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sheet Drag Indicator & Title
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.5),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isEditing ? 'Edit Task' : 'Create Task',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Task Title Input
                  const Text('Task Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      hintText: 'Enter task name...',
                    ),
                    autofocus: widget.existingTask == null,
                  ),
                  const SizedBox(height: 18),

                  // Task Description Input
                  const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _descController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Add some details...',
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Category Selector
                  const Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: provider.categories.keys.map((cat) {
                        final catColorVal = provider.categories[cat] ?? 0xFF818CF8;
                        final catColor = Color(catColorVal);
                        final isSelected = _selectedCategory == cat;
                        return ChoiceChip(
                          label: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected 
                                  ? Colors.white 
                                  : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: catColor,
                          backgroundColor: isDark 
                              ? AppTheme.darkCard 
                              : Colors.white,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedCategory = cat);
                            }
                          },
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 18),

                  // Priority Selector
                  const Text('Priority', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: TaskPriority.values.map((prio) {
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
                      final isSelected = _selectedPriority == prio;
                      return ChoiceChip(
                        label: Text(
                          prio.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected 
                                ? Colors.white 
                                : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: color,
                        backgroundColor: isDark 
                            ? AppTheme.darkCard 
                            : Colors.white,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedPriority = prio);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),

                  // Due Date Picker
                  const Text('Due Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final chosen = await showDatePicker(
                        context: context,
                        initialDate: _selectedDueDate ?? DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                      );
                      if (chosen != null) {
                        setState(() => _selectedDueDate = chosen);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                        borderRadius: BorderRadius.circular(12),
                        color: isDark ? AppTheme.darkCard : Colors.white,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedDueDate == null
                                ? 'No Date Chosen'
                                : DateFormat('EEEE, MMMM d, yyyy').format(_selectedDueDate!),
                            style: TextStyle(
                              color: _selectedDueDate == null ? Colors.grey : null,
                            ),
                          ),
                          const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Scheduled Reminders Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Reminders (Multi-Schedule)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      TextButton.icon(
                        icon: const Icon(Icons.add_alarm, size: 16),
                        label: const Text('Add Time'),
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date == null) return;
                          if (!context.mounted) return;
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (time == null) return;

                          final reminderDateTime = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );

                          if (reminderDateTime.isAfter(DateTime.now())) {
                            setState(() {
                              _reminders.add(reminderDateTime);
                              _reminders.sort();
                            });
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Cannot set reminders in the past!'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _reminders.isEmpty
                      ? Text(
                          'No reminders set. Click "Add Time" to schedule alerts.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _reminders.length,
                          itemBuilder: (context, index) {
                            final rTime = _reminders[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.darkCard.withOpacity(0.5) : Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.alarm, size: 14, color: Colors.amber),
                                      const SizedBox(width: 8),
                                      Text(
                                        DateFormat('MMM d, yyyy - h:mm a').format(rTime),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                    onPressed: () {
                                      setState(() {
                                        _reminders.removeAt(index);
                                      });
                                    },
                                    splashRadius: 16,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ),
          
          // Action buttons (Save/Create)
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    final title = _titleController.text.trim();
                    if (title.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Task name cannot be empty!'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    if (isEditing) {
                      final updated = widget.existingTask!.copyWith(
                        title: title,
                        description: _descController.text.trim(),
                        category: _selectedCategory,
                        priority: _selectedPriority,
                        dueDate: _selectedDueDate,
                        reminders: _reminders,
                      );
                      provider.updateTask(updated);
                    } else {
                      final newTask = Task(
                        id: const Uuid().v4(),
                        title: title,
                        description: _descController.text.trim(),
                        category: _selectedCategory,
                        priority: _selectedPriority,
                        dueDate: _selectedDueDate,
                        reminders: _reminders,
                        createdAt: DateTime.now(),
                      );
                      provider.addTask(newTask);
                    }
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: isDark ? AppTheme.darkAccent : AppTheme.lightAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isEditing ? 'Save Changes' : 'Create Task'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

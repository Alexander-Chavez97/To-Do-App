import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:todo_app/services/notification_service.dart';
import '../models/task.dart';
import '../widgets/add_task_sheet.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;

  late final CollectionReference _tasksCollection = FirebaseFirestore.instance
      .collection('users')
      .doc(_userId ?? '')
      .collection('tasks');

  Timer? _timer;
  String _selectedFilter = 'All';

  static const List<String> _categories = [
    'All',
    'General',
    'Work',
    'School',
    'Personal',
  ];

  @override
  void initState() {
    super.initState();
    // Rebuild every minute so overdue status stays accurate
    _timer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return DateFormat.yMMMd().add_jm().format(date);
  }

  // ─── Firebase ────────────────────────────────────────────────────────────────

  Future<void> _addTaskToFirebase(Task task) async {
    // Schedule notification independently — don't let it block or fail the save
    try {
      await NotificationService.scheduleNotification(
        id: task.id.hashCode,
        title: 'Task Due!',
        body: task.title,
        scheduledDate: task.dueDate,
      );
    } catch (_) {
      // Notification permission may be missing; the task still saves
    }

    try {
      await _tasksCollection.doc(task.id).set(task.toMap());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow; // Let the caller (AddTaskSheet) know it failed
    }
  }

  Future<void> _updateTaskInFirebase(Task task) async {
    try {
      await _tasksCollection.doc(task.id).update(task.toMap());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteTask(String id, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Delete "$title"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _tasksCollection.doc(id).delete();
      NotificationService.cancelNotification(id.hashCode);
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (confirmed == true) await AuthService().logOut();
  }

  // ─── Grouping Logic ───────────────────────────────────────────────────────────

  /// Splits a filtered task list into ordered sections.
  Map<String, List<Task>> _groupTasks(List<Task> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nextWeek = today.add(const Duration(days: 7));

    final overdue = <Task>[];
    final todayList = <Task>[];
    final thisWeek = <Task>[];
    final later = <Task>[];
    final completed = <Task>[];

    for (final task in tasks) {
      if (task.isCompleted) {
        completed.add(task);
        continue;
      }
      final dueDay = DateTime(
        task.dueDate.year,
        task.dueDate.month,
        task.dueDate.day,
      );

      if (dueDay.isBefore(today)) {
        overdue.add(task);
      } else if (dueDay == today) {
        todayList.add(task);
      } else if (dueDay.isBefore(nextWeek)) {
        thisWeek.add(task);
      } else {
        later.add(task);
      }
    }

    // Only include non-empty sections, in a logical order
    return {
      if (overdue.isNotEmpty) 'Overdue': overdue,
      if (todayList.isNotEmpty) 'Today': todayList,
      if (thisWeek.isNotEmpty) 'This Week': thisWeek,
      if (later.isNotEmpty) 'Later': later,
      if (completed.isNotEmpty) 'Completed': completed,
    };
  }

  // ─── UI Helpers ───────────────────────────────────────────────────────────────

  Color _sectionColor(String section) {
    switch (section) {
      case 'Overdue':
        return Colors.red;
      case 'Today':
        return Colors.blue;
      case 'This Week':
        return Colors.orange;
      case 'Later':
        return Colors.teal;
      case 'Completed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: _categories.map((category) {
          final isSelected = _selectedFilter == category;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (_) => setState(() => _selectedFilter = category),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    final color = _sectionColor(title);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTaskDetail(Task task) {
    final isOverdue =
        task.dueDate.isBefore(DateTime.now()) && !task.isCompleted;
    final color = isOverdue
        ? Colors.red
        : Theme.of(context).colorScheme.primary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title
            Text(
              task.title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                decoration:
                    task.isCompleted ? TextDecoration.lineThrough : null,
                color: task.isCompleted ? Colors.grey : Colors.black,
              ),
            ),
            const SizedBox(height: 16),

            // Info chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _detailChip(Icons.label_outline, task.category, color),
                _detailChip(
                  Icons.schedule,
                  _formatDate(task.dueDate),
                  isOverdue ? Colors.red : Colors.grey[700]!,
                ),
                if (task.repeat != RepeatFrequency.none)
                  _detailChip(
                    Icons.repeat,
                    'Repeats ${task.repeat.name}',
                    Colors.teal,
                  ),
                if (task.isCompleted)
                  _detailChip(
                    Icons.check_circle_outline,
                    'Completed',
                    Colors.green,
                  ),
              ],
            ),

            // Notes section
            if (task.description.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'NOTES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  task.description,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Delete button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                ),
                label: const Text(
                  'Delete Task',
                  style: TextStyle(color: Colors.redAccent),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _confirmDeleteTask(task.id, task.title);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Task task) {
    final isOverdue =
        task.dueDate.isBefore(DateTime.now()) && !task.isCompleted;
    final hasNotes = task.description.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: ListTile(
        onTap: () => _showTaskDetail(task),
        leading: Checkbox(
          value: task.isCompleted,
          onChanged: (bool? value) async {
            await NotificationService.cancelNotification(task.id.hashCode);
            task.toggleComplete();
            await _updateTaskInFirebase(task);

            if (task.repeat != RepeatFrequency.none) {
              await NotificationService.scheduleNotification(
                id: task.id.hashCode,
                title: 'Task Due!',
                body: task.title,
                scheduledDate: task.dueDate,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Rescheduled to ${_formatDate(task.dueDate)}',
                    ),
                  ),
                );
              }
            }
          },
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                task.title,
                style: TextStyle(
                  decoration:
                      task.isCompleted ? TextDecoration.lineThrough : null,
                  color: task.isCompleted ? Colors.grey : Colors.black,
                ),
              ),
            ),
            if (hasNotes)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(Icons.notes, size: 16, color: Colors.grey[400]),
              ),
          ],
        ),
        subtitle: Text(
          '${task.category} • ${_formatDate(task.dueDate)}',
          style: TextStyle(
            color: isOverdue ? Colors.red : Colors.grey[600],
            fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.redAccent),
          onPressed: () => _confirmDeleteTask(task.id, task.title),
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Critter'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log Out',
            onPressed: _confirmLogout,
          ),
        ],
        centerTitle: true,
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) => AddTaskSheet(
              onAddTask: (newTask) => _addTaskToFirebase(newTask),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),

      body: Column(
        children: [
          // ── Filter Chips ──────────────────────────────────────────────────
          _buildFilterChips(),
          const Divider(height: 1),

          // ── Task List ─────────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _tasksCollection.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off, size: 60, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'Could not load tasks',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                // Parse and filter tasks
                final allTasks = snapshot.data!.docs.map((doc) {
                  return Task.fromMap(doc.data() as Map<String, dynamic>);
                }).toList();

                final filtered = _selectedFilter == 'All'
                    ? allTasks
                    : allTasks
                          .where((t) => t.category == _selectedFilter)
                          .toList();

                if (filtered.isEmpty) {
                  return _buildEmptyState(filter: _selectedFilter);
                }

                // Sort within each group by due date
                filtered.sort((a, b) => a.dueDate.compareTo(b.dueDate));

                final sections = _groupTasks(filtered);

                // Build flat list: section header + cards
                final List<Widget> listItems = [];
                for (final entry in sections.entries) {
                  listItems.add(
                    _buildSectionHeader(entry.key, entry.value.length),
                  );
                  for (final task in entry.value) {
                    listItems.add(_buildTaskCard(task));
                  }
                }
                // Bottom padding so FAB doesn't cover last item
                listItems.add(const SizedBox(height: 80));

                return ListView(children: listItems);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({String? filter}) {
    final message = filter != null && filter != 'All'
        ? 'No $filter tasks yet!'
        : 'No tasks yet!';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.checklist, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first task',
            style: TextStyle(color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}

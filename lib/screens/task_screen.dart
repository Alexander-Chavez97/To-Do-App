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
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  late final CollectionReference _tasksCollection = FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
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
    await NotificationService.scheduleNotification(
      id: task.id.hashCode,
      title: 'Task Due!',
      body: task.title,
      scheduledDate: task.dueDate,
    );
    await _tasksCollection.doc(task.id).set(task.toMap());
  }

  Future<void> _updateTaskInFirebase(Task task) async {
    await _tasksCollection.doc(task.id).update(task.toMap());
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

  Widget _buildTaskCard(Task task) {
    final isOverdue =
        task.dueDate.isBefore(DateTime.now()) && !task.isCompleted;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: ListTile(
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
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
            color: task.isCompleted ? Colors.grey : Colors.black,
          ),
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
        title: const Text('My To-Do List'),
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

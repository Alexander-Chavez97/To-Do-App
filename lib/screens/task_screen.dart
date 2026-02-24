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

  @override
  void initState() {
    super.initState();
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

  // LOGIC: Add Task to Firebase & Schedule Notification
  Future<void> _addTaskToFirebase(Task task) async {
    await NotificationService.scheduleNotification(
      id: task.id.hashCode,
      title: 'Task Due!',
      body: task.title,
      scheduledDate: task.dueDate,
    );
    await _tasksCollection.doc(task.id).set(task.toMap());
  }

  // LOGIC: Update Task in Firebase
  Future<void> _updateTaskInFirebase(Task task) async {
    await _tasksCollection.doc(task.id).update(task.toMap());
  }

  // LOGIC: Delete Task from Firebase (with confirmation)
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
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _tasksCollection.doc(id).delete();
      NotificationService.cancelNotification(id.hashCode);
    }
  }

  // LOGIC: Logout (with confirmation)
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

    if (confirmed == true) {
      await AuthService().logOut();
    }
  }

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

      body: StreamBuilder<QuerySnapshot>(
        stream: _tasksCollection.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.checklist, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No tasks yet!',
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

          final tasks = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Task.fromMap(data);
          }).toList();

          tasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));

          return ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              final isOverdue =
                  task.dueDate.isBefore(DateTime.now()) && !task.isCompleted;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: Checkbox(
                    value: task.isCompleted,
                    onChanged: (bool? value) async {
                      // Cancel the old notification before rescheduling
                      await NotificationService.cancelNotification(
                        task.id.hashCode,
                      );

                      task.toggleComplete();
                      await _updateTaskInFirebase(task);

                      // If it's a repeating task, schedule the next notification
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
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      color: task.isCompleted ? Colors.grey : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    '${task.category} • ${_formatDate(task.dueDate)}',
                    style: TextStyle(
                      color: isOverdue ? Colors.red : Colors.grey[600],
                      fontWeight:
                          isOverdue ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () => _confirmDeleteTask(task.id, task.title),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:todo_app/services/notification_service.dart';
import '../models/task.dart';
import '../widgets/add_task_sheet.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart'; // To get the user's ID
import '../services/auth_service.dart'; // To get the logout function

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  // Access the Firestore database
  // 1. Grab the unique ID of the person currently logged in
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  // 2. Point the app to: users -> [Their ID] -> tasks
  late final CollectionReference _tasksCollection = FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('tasks');

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // 2. Start a timer that rebuilds the UI every 60 seconds
    _timer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (mounted) {
        setState(() {
          // This empty setState forces the 'build' method to run again,
          // checking DateTime.now() against your due dates.
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return DateFormat.yMMMd().add_jm().format(date);
  }

  // LOGIC: Add Task to Firebase
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

  // LOGIC: Delete Task from Firebase
  Future<void> _deleteTaskFromFirebase(String id) async {
    await _tasksCollection.doc(id).delete();
    NotificationService.cancelNotification(id.hashCode);
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
            onPressed: () async {
              await AuthService().logOut();
            },
          ),
        ],
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) => AddTaskSheet(
              onAddTask: (newTask) {
                // Instead of adding to a local list, we send it to the cloud
                _addTaskToFirebase(newTask);
              },
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      // StreamBuilder listens to the database in real-time
      body: StreamBuilder<QuerySnapshot>(
        stream: _tasksCollection.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No tasks yet!'));
          }

          // Convert the "Raw Database Data" into our "Task Objects"
          final tasks = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Task.fromMap(data);
          }).toList();

          // Optional: Sort by Due Date locally
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
                    onChanged: (bool? value) {
                      // Update the object locally
                      task.toggleComplete();

                      // Push the update to Firebase
                      _updateTaskInFirebase(task);

                      if (task.repeat != RepeatFrequency.none) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Rescheduled to ${_formatDate(task.dueDate)}',
                            ),
                          ),
                        );
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
                    _formatDate(task.dueDate),
                    style: TextStyle(
                      color: isOverdue ? Colors.red : Colors.grey[600],
                      fontWeight: isOverdue
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () {
                      _deleteTaskFromFirebase(task.id);
                    },
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

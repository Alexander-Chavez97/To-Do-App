import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:todo_app/services/notification_service.dart';
import '../models/task.dart';
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
      if (mounted) {
        setState(() {});
      }
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

  // LOGIC: Delete Task from Firebase
  Future<void> _deleteTaskFromFirebase(String id) async {
    await _tasksCollection.doc(id).delete();
    NotificationService.cancelNotification(id.hashCode);
  }

  // THE NEW ADD TASK POPUP
  void _showAddTaskModal(BuildContext context) {
    final titleController = TextEditingController();
    final notesController =
        TextEditingController(); // Controls the description/notes

    DateTime selectedDate = DateTime.now();
    String selectedCategory = 'General';
    RepeatFrequency selectedRepeat = RepeatFrequency.none;

    final List<String> categories = ['General', 'Work', 'School', 'Personal'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'New Task',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Task Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes / Description (Optional)',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedCategory,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(),
                            ),
                            items: categories.map((String category) {
                              return DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setModalState(() => selectedCategory = value);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<RepeatFrequency>(
                            value: selectedRepeat,
                            decoration: const InputDecoration(
                              labelText: 'Repeat',
                              border: OutlineInputBorder(),
                            ),
                            items: RepeatFrequency.values.map((
                              RepeatFrequency freq,
                            ) {
                              return DropdownMenuItem(
                                value: freq,
                                child: Text(freq.name.toUpperCase()),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setModalState(() => selectedRepeat = value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            "${selectedDate.month}/${selectedDate.day}/${selectedDate.year}",
                          ),
                          onPressed: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              // Ask for Time after Date
                              final TimeOfDay? timePicked =
                                  await showTimePicker(
                                    context: context,
                                    initialTime: TimeOfDay.fromDateTime(
                                      selectedDate,
                                    ),
                                  );
                              if (timePicked != null) {
                                setModalState(() {
                                  selectedDate = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                    timePicked.hour,
                                    timePicked.minute,
                                  );
                                });
                              }
                            }
                          },
                        ),

                        ElevatedButton(
                          onPressed: () {
                            if (titleController.text.isNotEmpty) {
                              final newTask = Task(
                                title: titleController.text.trim(),
                                description: notesController.text.trim(),
                                dueDate: selectedDate,
                                category: selectedCategory,
                                repeat: selectedRepeat,
                              );

                              // Pass the task through the notification wrapper!
                              _addTaskToFirebase(newTask);

                              Navigator.pop(context);
                            }
                          },
                          child: const Text('Save Task'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
        onPressed: () =>
            _showAddTaskModal(context), // Replaced with our new method
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _tasksCollection.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No tasks yet!'));
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
                    onChanged: (bool? value) {
                      task.toggleComplete();
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
                  // Showing the category and the date nicely!
                  subtitle: Text(
                    '${task.category} • ${_formatDate(task.dueDate)}',
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

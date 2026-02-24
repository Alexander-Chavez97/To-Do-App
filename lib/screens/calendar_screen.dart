import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/task.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  late final CollectionReference _tasksCollection = FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('tasks');

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  // Normalize to midnight so map lookups are consistent
  DateTime _normalize(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  Map<DateTime, List<Task>> _buildEventMap(List<Task> tasks) {
    final map = <DateTime, List<Task>>{};
    for (final task in tasks) {
      final day = _normalize(task.dueDate);
      map[day] = [...(map[day] ?? []), task];
    }
    return map;
  }

  List<Task> _getTasksForDay(
    DateTime day,
    Map<DateTime, List<Task>> eventMap,
  ) {
    return eventMap[_normalize(day)] ?? [];
  }

  String _formatTime(DateTime date) => DateFormat.jm().format(date);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Calendar'), centerTitle: true),
      body: StreamBuilder<QuerySnapshot>(
        stream: _tasksCollection.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final tasks = snapshot.hasData
              ? snapshot.data!.docs
                    .map(
                      (doc) =>
                          Task.fromMap(doc.data() as Map<String, dynamic>),
                    )
                    .toList()
              : <Task>[];

          final eventMap = _buildEventMap(tasks);
          final selectedTasks = _getTasksForDay(_selectedDay, eventMap);

          return Column(
            children: [
              // ── Calendar ───────────────────────────────────────────────────
              TableCalendar<Task>(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) =>
                    isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
                eventLoader: (day) => _getTasksForDay(day, eventMap),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.25),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  markerSize: 6,
                  markersMaxCount: 4,
                ),
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                ),
              ),

              const Divider(height: 1),

              // ── Selected day label ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Text(
                      isSameDay(_selectedDay, DateTime.now())
                          ? 'TODAY'
                          : DateFormat('EEE, MMM d')
                                .format(_selectedDay)
                                .toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${selectedTasks.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Task list for selected day ─────────────────────────────────
              Expanded(child: _buildDayTaskList(selectedTasks)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDayTaskList(List<Task> tasks) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'No tasks on this day',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    // Sort by time within the day
    tasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 80),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final isOverdue =
            task.dueDate.isBefore(DateTime.now()) && !task.isCompleted;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: Icon(
              task.isCompleted
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: task.isCompleted
                  ? Colors.green
                  : (isOverdue ? Colors.red : Colors.grey),
            ),
            title: Text(
              task.title,
              style: TextStyle(
                decoration:
                    task.isCompleted ? TextDecoration.lineThrough : null,
                color: task.isCompleted ? Colors.grey : Colors.black,
              ),
            ),
            subtitle: Text(
              '${task.category} • ${_formatTime(task.dueDate)}'
              '${task.repeat != RepeatFrequency.none ? ' • Repeats ${task.repeat.name}' : ''}',
              style: TextStyle(
                color: isOverdue ? Colors.red : Colors.grey[600],
                fontWeight:
                    isOverdue ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      },
    );
  }
}

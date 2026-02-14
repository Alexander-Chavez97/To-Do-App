import 'package:uuid/uuid.dart';

enum RepeatFrequency { none, daily, weekly, monthly }

class Task {
  final String id;
  String title;
  String description;
  DateTime dueDate;
  bool isCompleted;
  RepeatFrequency repeat;

  Task({
    String? id,
    required this.title,
    this.description = '',
    required this.dueDate,
    this.isCompleted = false,
    this.repeat = RepeatFrequency.none,
  }) : id = id ?? const Uuid().v4();

  void toggleComplete() {
    if (repeat == RepeatFrequency.none) {
      isCompleted = !isCompleted;
    } else {
      _rescheduleTask();
    }
  }

  void _rescheduleTask() {
    switch (repeat) {
      case RepeatFrequency.daily:
        dueDate = dueDate.add(const Duration(days: 1));
        break;
      case RepeatFrequency.weekly:
        dueDate = dueDate.add(const Duration(days: 7));
        break;
      case RepeatFrequency.monthly:
        dueDate = DateTime(dueDate.year, dueDate.month + 1, dueDate.day);
        break;
      case RepeatFrequency.none:
        break;
    }
    isCompleted = false;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dueDate': dueDate.toIso8601String(),
      'isCompleted': isCompleted,
      'repeat': repeat.index,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'],
      description: map['description'] ?? '',
      dueDate: DateTime.parse(map['dueDate']),
      isCompleted: map['isCompleted'],
      repeat: RepeatFrequency.values[map['repeat']],
    );
  }
}

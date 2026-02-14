import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';

class AddTaskSheet extends StatefulWidget {
  final Function(Task) onAddTask; // Callback to send data back

  const AddTaskSheet({super.key, required this.onAddTask});

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final _titleController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  RepeatFrequency _selectedRepeat = RepeatFrequency.none;

  // Helper to pick a date
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  // Helper to pick a time
  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _submit() {
    if (_titleController.text.isEmpty) return;

    // Combine Date and Time into one DateTime object
    final finalDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // Create the new task
    final newTask = Task(
      title: _titleController.text,
      dueDate: finalDateTime,
      repeat: _selectedRepeat,
    );

    // Send it back to the main screen
    widget.onAddTask(newTask);
    Navigator.pop(context); // Close the sheet
  }

  @override
  Widget build(BuildContext context) {
    // padding for keyboard handling
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Shrink to fit content
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'New Task',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          // 1. Task Title Input
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              hintText: 'What needs to be done?',
            ),
            autofocus: true,
          ),
          const SizedBox(height: 20),

          // 2. Date & Time Row
          Row(
            children: [
              // Date Button
              Expanded(
                child: TextButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(DateFormat.yMMMd().format(_selectedDate)),
                  onPressed: _pickDate,
                ),
              ),
              // Time Button
              Expanded(
                child: TextButton.icon(
                  icon: const Icon(Icons.access_time),
                  label: Text(_selectedTime.format(context)),
                  onPressed: _pickTime,
                ),
              ),
            ],
          ),

          // 3. Repeat Dropdown
          DropdownButtonFormField<RepeatFrequency>(
            value: _selectedRepeat,
            decoration: const InputDecoration(labelText: 'Repeat'),
            items: RepeatFrequency.values.map((freq) {
              return DropdownMenuItem(
                value: freq,
                child: Text(freq.toString().split('.').last.toUpperCase()),
              );
            }).toList(),
            onChanged: (val) => setState(() => _selectedRepeat = val!),
          ),
          const SizedBox(height: 20),

          // 4. Save Button
          ElevatedButton(onPressed: _submit, child: const Text('Add Task')),
        ],
      ),
    );
  }
}

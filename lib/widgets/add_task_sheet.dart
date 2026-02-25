import 'package:flutter/material.dart';
import '../models/task.dart';

class AddTaskSheet extends StatefulWidget {
  final Future<void> Function(Task) onAddTask;

  const AddTaskSheet({super.key, required this.onAddTask});

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'General';
  RepeatFrequency _selectedRepeat = RepeatFrequency.none;
  bool _isSaving = false;

  final List<String> _categories = ['General', 'Work', 'School', 'Personal'];

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Task Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _notesController,
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
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: _categories.map((String category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedCategory = value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<RepeatFrequency>(
                    value: _selectedRepeat,
                    decoration: const InputDecoration(
                      labelText: 'Repeat',
                      border: OutlineInputBorder(),
                    ),
                    items: RepeatFrequency.values.map((RepeatFrequency freq) {
                      return DropdownMenuItem(
                        value: freq,
                        child: Text(freq.name.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedRepeat = value);
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
                    '${_selectedDate.month}/${_selectedDate.day}/${_selectedDate.year}',
                  ),
                  onPressed: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null && context.mounted) {
                      final TimeOfDay? timePicked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(_selectedDate),
                      );
                      if (timePicked != null) {
                        setState(() {
                          _selectedDate = DateTime(
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
                  onPressed: _isSaving
                      ? null
                      : () async {
                          if (_titleController.text.trim().isEmpty) return;
                          final newTask = Task(
                            title: _titleController.text.trim(),
                            description: _notesController.text.trim(),
                            dueDate: _selectedDate,
                            category: _selectedCategory,
                            repeat: _selectedRepeat,
                          );
                          setState(() => _isSaving = true);
                          try {
                            await widget.onAddTask(newTask);
                            if (context.mounted) Navigator.pop(context);
                          } catch (_) {
                            // Error snackbar already shown by task_screen
                            if (context.mounted) {
                              setState(() => _isSaving = false);
                            }
                          }
                        },
                  child: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Task'),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

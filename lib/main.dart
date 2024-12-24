import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

void main() async {
  await Hive.initFlutter();
  await Hive.openBox('tasks');
  runApp(const TodoApp());
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo List',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const TodoListScreen(),
    );
  }
}

class Task {
  String id;
  String title;
  String? description;
  bool isCompleted;
  DateTime? dueDate;
  Priority priority;

  Task({
    required this.id,
    required this.title,
    this.description,
    this.isCompleted = false,
    this.dueDate,
    this.priority = Priority.medium,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'isCompleted': isCompleted,
      'dueDate': dueDate?.toIso8601String(),
      'priority': priority.index,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      isCompleted: map['isCompleted'],
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
      priority: Priority.values[map['priority']],
    );
  }
}

enum Priority { low, medium, high }

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  final _box = Hive.box('tasks');
  List<Task> _tasks = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  void _loadTasks() {
    final tasks = _box.get('tasks', defaultValue: []);
    setState(() {
      _tasks = (tasks as List).map((task) => Task.fromMap(Map<String, dynamic>.from(task))).toList();
    });
  }

  void _saveTasks() {
    _box.put('tasks', _tasks.map((task) => task.toMap()).toList());
  }

  void _addTask() {
    showDialog(
      context: context,
      builder: (context) => TaskDialog(
        onSave: (title, description, dueDate, priority) {
          setState(() {
            _tasks.add(Task(
              id: DateTime.now().toString(),
              title: title,
              description: description,
              dueDate: dueDate,
              priority: priority,
            ));
            _saveTasks();
          });
        },
      ),
    );
  }

  void _editTask(Task task) {
    showDialog(
      context: context,
      builder: (context) => TaskDialog(
        task: task,
        onSave: (title, description, dueDate, priority) {
          setState(() {
            final index = _tasks.indexWhere((t) => t.id == task.id);
            _tasks[index] = Task(
              id: task.id,
              title: title,
              description: description,
              isCompleted: task.isCompleted,
              dueDate: dueDate,
              priority: priority,
            );
            _saveTasks();
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todo List'),
      ),
      body: ListView.builder(
        itemCount: _tasks.length,
        itemBuilder: (context, index) {
          final task = _tasks[index];
          return Dismissible(
            key: Key(task.id),
            onDismissed: (direction) {
              setState(() {
                _tasks.removeAt(index);
                _saveTasks();
              });
            },
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            child: ListTile(
              leading: Checkbox(
                value: task.isCompleted,
                onChanged: (value) {
                  setState(() {
                    task.isCompleted = value!;
                    _saveTasks();
                  });
                },
              ),
              title: Text(
                task.title,
                style: TextStyle(
                  decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (task.description != null) Text(task.description!),
                  if (task.dueDate != null)
                    Text('Due: ${DateFormat('MMM dd, yyyy').format(task.dueDate!)}'),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.circle,
                    color: task.priority == Priority.high
                        ? Colors.red
                        : task.priority == Priority.medium
                            ? Colors.orange
                            : Colors.green,
                    size: 12,
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _editTask(task),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTask,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class TaskDialog extends StatefulWidget {
  final Task? task;
  final Function(String title, String? description, DateTime? dueDate, Priority priority) onSave;

  const TaskDialog({
    super.key,
    this.task,
    required this.onSave,
  });

  @override
  State<TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<TaskDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  DateTime? _dueDate;
  Priority _priority = Priority.medium;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descriptionController = TextEditingController(text: widget.task?.description ?? '');
    _dueDate = widget.task?.dueDate;
    _priority = widget.task?.priority ?? Priority.medium;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.task == null ? 'Add Task' : 'Edit Task'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Priority: '),
                DropdownButton<Priority>(
                  value: _priority,
                  items: Priority.values
                      .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(p.name),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _priority = value!;
                    });
                  },
                ),
              ],
            ),
            ListTile(
              title: Text(_dueDate == null
                  ? 'No due date'
                  : DateFormat('MMM dd, yyyy').format(_dueDate!)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _dueDate ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  setState(() {
                    _dueDate = date;
                  });
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_titleController.text.isNotEmpty) {
              widget.onSave(
                _titleController.text,
                _descriptionController.text.isEmpty ? null : _descriptionController.text,
                _dueDate,
                _priority,
              );
              Navigator.pop(context);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

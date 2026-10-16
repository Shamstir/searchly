import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TodoListWidget extends StatefulWidget {
  const TodoListWidget({super.key});

  @override
  State<TodoListWidget> createState() => _TodoListWidgetState();
}

class _TodoListWidgetState extends State<TodoListWidget> {
  List<Map<String, dynamic>> todos = [];
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTodos();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? saved = prefs.getStringList('todos_v2');
    if (saved != null) {
      if (mounted) {
        setState(() {
          todos = saved
              .map((e) => jsonDecode(e) as Map<String, dynamic>)
              .toList();
        });
      }
    } else {
      if (mounted) {
        setState(() {
          todos = [
            {'task': 'Morning workout', 'done': true},
            {'task': 'Review project', 'done': false},
            {'task': 'Team sync', 'done': false},
          ];
        });
      }
    }
  }

  Future<void> _saveTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> encoded = todos.map((e) => jsonEncode(e)).toList();
    await prefs.setStringList('todos_v2', encoded);
  }

  void _addTodo(String task) {
    if (task.trim().isEmpty) return;
    setState(() {
      todos.add({'task': task.trim(), 'done': false});
    });
    _saveTodos();
    _textController.clear();
  }

  void _deleteTodo(int index) {
    if (index < 0 || index >= todos.length) return;
    setState(() {
      todos.removeAt(index);
    });
    _saveTodos();
  }

  void _editTodo(int index) {
    if (index < 0 || index >= todos.length) return;
    final taskObj = todos[index];
    _textController.text = taskObj['task'] ?? '';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Edit Task', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: _textController,
            style: const TextStyle(color: Colors.white),
            autofocus: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                setState(() {
                  taskObj['task'] = value.trim();
                });
                _saveTodos();
              }
              Navigator.pop(context);
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                _deleteTodo(index);
                Navigator.pop(context);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () {
                if (_textController.text.trim().isNotEmpty) {
                  setState(() {
                    taskObj['task'] = _textController.text.trim();
                  });
                  _saveTodos();
                }
                Navigator.pop(context);
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _toggleTodo(int index) {
    if (index < 0 || index >= todos.length) return;
    final taskObj = todos[index];
    setState(() {
      taskObj['done'] = !(taskObj['done'] as bool? ?? false);
    });
    _saveTodos();
  }

  void _showAddDialog() {
    _textController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('New Task', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: _textController,
            style: const TextStyle(color: Colors.black),
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'What needs to be done?',
              hintStyle: TextStyle(color: Colors.black38),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFDDDDDD)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.black),
              ),
            ),
            onSubmitted: (value) {
              _addTodo(value);
              Navigator.pop(context);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                _addTodo(_textController.text);
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TASKS',
                style: TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 12,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: _showAddDialog,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFDDDDDD)),
                  ),
                  child: const Icon(Icons.add, color: Color(0xFF888888), size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: todos.isEmpty
                ? const Center(
                    child: Text(
                      'All caught up!',
                      style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: todos.length,
                    itemBuilder: (context, index) {
                      bool isDone = todos[index]['done'] ?? false;
                      return GestureDetector(
                        onTap: () => _toggleTodo(index),
                        onLongPress: () => _editTodo(index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            border: index != todos.length - 1
                                ? const Border(
                                    bottom: BorderSide(color: Color(0xFFF0F0F0)),
                                  )
                                : null,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      isDone ? Colors.black : Colors.transparent,
                                  border: Border.all(
                                    color: isDone
                                        ? Colors.black
                                        : const Color(0xFFCCCCCC),
                                    width: 1.5,
                                  ),
                                ),
                                child: isDone
                                    ? const Icon(Icons.check,
                                        color: Colors.white, size: 12)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  todos[index]['task'],
                                  style: TextStyle(
                                    color: isDone
                                        ? const Color(0xFFBBBBBB)
                                        : const Color(0xFF333333),
                                    fontSize: 13,
                                    decoration: isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

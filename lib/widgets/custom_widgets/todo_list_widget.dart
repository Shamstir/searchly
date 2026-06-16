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

  Future<void> _loadTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? saved = prefs.getStringList('todos_v2');
    if (saved != null) {
      setState(() {
        todos = saved.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
      });
    } else {
      setState(() {
        todos = [
          {'task': 'Morning run', 'done': true},
          {'task': 'Review PR #42', 'done': false},
          {'task': 'Team standup', 'done': false},
        ];
      });
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
      todos.add({'task': task, 'done': false});
    });
    _saveTodos();
    _textController.clear();
  }

  void _toggleTodo(int index) {
    final taskObj = todos[index];
    setState(() {
      taskObj['done'] = !taskObj['done'];
    });
    _saveTodos();
    
    if (taskObj['done']) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && todos.contains(taskObj) && taskObj['done']) {
          setState(() {
            todos.remove(taskObj);
          });
          _saveTodos();
        }
      });
    }
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add Task', style: TextStyle(color: Colors.black)),
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
            TextButton(
              onPressed: () {
                _addTodo(_textController.text);
                Navigator.pop(context);
              },
              child: const Text('Add', style: TextStyle(color: Colors.black)),
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
                  padding: const EdgeInsets.all(2),
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
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: todos.length,
              itemBuilder: (context, index) {
                bool isDone = todos[index]['done'] ?? false;
                return GestureDetector(
                  onTap: () => _toggleTodo(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: index != todos.length - 1 
                        ? const Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))
                        : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDone ? Colors.black : Colors.transparent,
                            border: Border.all(
                              color: isDone ? Colors.black : const Color(0xFFCCCCCC),
                              width: 1.5,
                            ),
                          ),
                          child: isDone
                              ? const Icon(Icons.check, color: Colors.white, size: 12)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            todos[index]['task'],
                            style: TextStyle(
                              color: isDone ? const Color(0xFFBBBBBB) : const Color(0xFF333333),
                              fontSize: 14,
                              decoration: isDone ? TextDecoration.lineThrough : null,
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

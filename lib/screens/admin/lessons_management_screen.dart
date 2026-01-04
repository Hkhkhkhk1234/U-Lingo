import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Lessons management screen for admin content control.
/// 
/// Provides administrators with tools to manage the Mandarin course curriculum:
/// - View all lessons with engagement metrics (students reached)
/// - Add new lessons to the course progression
/// - Edit existing lesson details
/// - Delete lessons (with confirmation)
/// 
/// Data Architecture:
/// Currently uses local state for lesson data - lessons are stored in memory only.
/// TODO: Integrate with Firestore 'levels' collection for persistent storage.
/// 
/// Engagement Metrics:
/// Calculates "students reached" by counting users whose currentLevel is >= lesson ID.
/// This shows how many students have progressed to or past each lesson, helping
/// admins identify where students drop off or struggle.
class LessonsManagementScreen extends StatefulWidget {
  const LessonsManagementScreen({Key? key}) : super(key: key);

  @override
  State<LessonsManagementScreen> createState() => _LessonsManagementScreenState();
}

class _LessonsManagementScreenState extends State<LessonsManagementScreen> {
  /// Local lesson data structure.
  /// 
  /// IMPORTANT: This is currently in-memory only. Changes are lost on app restart.
  /// Each lesson requires:
  /// - id: Unique identifier matching the level progression system
  /// - title: Short descriptive name for the lesson
  /// - description: Brief explanation of lesson content
  /// 
  /// TODO: Replace with Firestore queries to 'levels' collection for persistence
  /// and real-time synchronization across admin sessions.
  final List<Map<String, dynamic>> _lessons = [
    {'id': 1, 'title': 'Basic Greetings', 'description': 'Learn common greetings'},
    {'id': 2, 'title': 'Numbers', 'description': 'Count from 1 to 100'},
    {'id': 3, 'title': 'Colors', 'description': 'Learn color names'},
    {'id': 4, 'title': 'Family Members', 'description': 'Family vocabulary'},
    {'id': 5, 'title': 'Food & Drinks', 'description': 'Common food items'},
    {'id': 6, 'title': 'Daily Activities', 'description': 'Common verbs'},
    {'id': 7, 'title': 'Time & Date', 'description': 'Tell time and date'},
    {'id': 8, 'title': 'Directions', 'description': 'Navigate around town'},
    {'id': 9, 'title': 'Shopping', 'description': 'Shopping vocabulary'},
    {'id': 10, 'title': 'Advanced Conversation', 'description': 'Complex sentences'},
  ];

  /// Shows dialog for adding a new lesson to the curriculum.
  /// 
  /// Collects lesson title (required) and description (optional) from admin.
  /// New lessons are assigned sequential IDs based on current lesson count.
  /// 
  /// Validation:
  /// - Title is required (empty titles are rejected)
  /// - Description is optional
  /// 
  /// TODO: Add validation for duplicate titles and lesson ordering controls
  void _showAddLessonDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Lesson'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Lesson Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Only proceed if title is provided
              if (titleController.text.isNotEmpty) {
                setState(() {
                  _lessons.add({
                    'id': _lessons.length + 1, // Sequential ID assignment
                    'title': titleController.text,
                    'description': descriptionController.text,
                  });
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Lesson added successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Add Lesson'),
          ),
        ],
      ),
    );
  }

  /// Deletes a lesson after admin confirmation.
  /// 
  /// Shows confirmation dialog to prevent accidental deletions.
  /// Displays the lesson title in the confirmation message for clarity.
  /// 
  /// IMPORTANT: Deleting lessons affects the course progression system.
  /// Students currently on deleted lessons may experience issues.
  /// TODO: Add logic to handle student progress when lessons are deleted,
  /// such as moving students to the next available lesson or marking as incomplete.
  void _deleteLesson(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Lesson'),
        content: Text('Are you sure you want to delete "${_lessons[index]['title']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _lessons.removeAt(index);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Lesson deleted successfully!'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lessons Management'),
        backgroundColor: Colors.orange,
        // No back button - this is a top-level admin section
        automaticallyImplyLeading: false,
        actions: [
          // Quick add button in app bar for easy access
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddLessonDialog,
            tooltip: 'Add New Lesson',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Stream user data to calculate real-time engagement metrics
        // This allows admins to see how lesson changes affect student progression
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data!.docs;

          // Calculate engagement metric: "students reached" for each lesson
          // 
          // Logic: Count students whose currentLevel >= lesson ID
          // This shows progression through the course:
          // - High numbers for early lessons indicate good retention
          // - Sudden drops indicate potential difficulty spikes or disengagement points
          // 
          // Example: If lesson 5 has 100 students reached but lesson 6 has 30,
          // admins can investigate what's causing the 70% drop-off
          Map<int, int> lessonReach = {};
          for (var lesson in _lessons) {
            int count = 0;
            for (var user in users) {
              final data = user.data() as Map<String, dynamic>;
              final currentLevel = data['currentLevel'] ?? 1; // Default to level 1 if not set
              if (currentLevel >= lesson['id']) {
                count++;
              }
            }
            lessonReach[lesson['id']] = count;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header section with title and lesson count badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Mandarin Course Lessons',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // Quick reference showing total lesson count
                    Chip(
                      label: Text('${_lessons.length} Lessons'),
                      backgroundColor: Colors.orange[100],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Lesson list with engagement metrics
                // Using ListView inside SingleChildScrollView requires shrinkWrap
                // and NeverScrollableScrollPhysics to prevent scroll conflicts
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _lessons.length,
                  itemBuilder: (context, index) {
                    final lesson = _lessons[index];
                    final studentsReached = lessonReach[lesson['id']] ?? 0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        // Circular badge showing lesson number in sequence
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange,
                          child: Text(
                            '${lesson['id']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          lesson['title'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            // Lesson description for quick reference
                            Text(lesson['description']),
                            const SizedBox(height: 8),
                            // Engagement metric showing student reach
                            // Helps admins understand lesson popularity and course completion rates
                            Row(
                              children: [
                                const Icon(Icons.people, size: 16, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  '$studentsReached students reached',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Action buttons for lesson management
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Edit button - currently placeholder functionality
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                // TODO: Implement edit dialog similar to add dialog
                                // Should pre-fill fields with current lesson data
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Edit lesson feature'),
                                  ),
                                );
                              },
                              tooltip: 'Edit Lesson',
                            ),
                            // Delete button with confirmation dialog
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteLesson(index),
                              tooltip: 'Delete Lesson',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
      // Floating action button provides secondary add access
      // Visible when scrolling through long lesson lists
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddLessonDialog,
        backgroundColor: Colors.orange,
        icon: const Icon(Icons.add),
        label: const Text('Add Lesson'),
      ),
    );
  }
}

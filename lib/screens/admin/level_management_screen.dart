import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_edit_level_screen.dart';

/// Level management screen for course structure administration.
/// 
/// Provides comprehensive CRUD operations for managing course levels with:
/// - Real-time view of all levels with their quizzes and pronunciation exercises
/// - Expandable cards showing detailed content for each level
/// - Safe deletion with automatic student progress adjustment
/// - Add/Edit navigation to dedicated level editor screen
/// 
/// Data Model:
/// Levels contain nested arrays of quizzes and pronunciations, stored in Firestore.
/// Each level has: levelId (int), title, description, quizzes[], pronunciations[]
/// 
/// Critical Feature - Cascade Deletion:
/// When a level is deleted, the system automatically updates ALL student records
/// to remove the deleted level from their progress and adjust their currentLevel.
/// This prevents orphaned references and maintains data integrity across the platform.
class LevelManagementScreen extends StatelessWidget {
  const LevelManagementScreen({Key? key}) : super(key: key);

  /// Deletes a level and updates all affected student progress records.
  /// 
  /// Cascade Deletion Process:
  /// 1. Show confirmation dialog (prevent accidental deletion)
  /// 2. Fetch level data to get levelId before deletion
  /// 3. Delete the level document from Firestore
  /// 4. Query ALL users to find affected students
  /// 5. Batch update: remove deleted level from completedLevels arrays
  /// 6. Adjust currentLevel for students who were past the deleted level
  /// 
  /// Why Batch Updates:
  /// Using Firestore batch operations ensures atomic updates - either all student
  /// records are updated successfully, or none are. This prevents partial updates
  /// that could leave the database in an inconsistent state.
  /// 
  /// Performance Note:
  /// This operation queries and potentially updates every user document.
  /// For platforms with thousands of users, consider implementing this as a
  /// Cloud Function with background processing to avoid UI blocking.
  Future<void> _deleteLevel(BuildContext context, String levelId) async {
    // Show confirmation dialog with detailed warning about cascade effects
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Level'),
        content: const Text(
          'Are you sure you want to delete this level? This will remove all quizzes and pronunciation data, and update student progress accordingly.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Show loading dialog with descriptive message
        // Non-dismissible to prevent premature cancellation during critical operations
        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Deleting level and updating student progress...'),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        // Fetch level data BEFORE deletion to preserve levelId for student updates
        // Once deleted, we lose access to this critical information
        final levelDoc = await FirebaseFirestore.instance
            .collection('levels')
            .doc(levelId)
            .get();

        final levelData = levelDoc.data();
        if (levelData == null) {
          throw Exception('Level not found');
        }

        final deletedLevelId = levelData['levelId'] as int;

        // Delete the level document from Firestore
        await FirebaseFirestore.instance
            .collection('levels')
            .doc(levelId)
            .delete();

        // Query all users to identify those affected by the deletion
        final usersSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .get();

        // Prepare batch operation for atomic updates
        // Batch writes are limited to 500 operations - for larger user bases,
        // split into multiple batches or use Cloud Functions
        final batch = FirebaseFirestore.instance.batch();
        int updatedStudents = 0;

        for (var userDoc in usersSnapshot.docs) {
          final userData = userDoc.data();
          final completedLevels = List<int>.from(userData['completedLevels'] ?? []);

          // Update user only if they were affected by the deleted level
          if (completedLevels.contains(deletedLevelId)) {
            // Remove the deleted level from their completion history
            completedLevels.remove(deletedLevelId);

            // Adjust currentLevel to prevent pointing to non-existent level
            // If student was on level 5 and we delete level 3, their currentLevel
            // should decrease by 1 to maintain correct positioning in the sequence
            int currentLevel = userData['currentLevel'] ?? 1;
            if (currentLevel > deletedLevelId) {
              currentLevel--;
            }

            // Queue the update operation in the batch
            batch.update(userDoc.reference, {
              'completedLevels': completedLevels,
              'currentLevel': currentLevel,
            });

            updatedStudents++;
          }
        }

        // Commit all student updates atomically
        // Either all updates succeed or all fail - no partial state
        await batch.commit();

        // Close loading dialog
        if (context.mounted) {
          Navigator.pop(context);
        }

        // Show success message with affected student count
        // This transparency helps admins understand the impact of their action
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Level deleted successfully! Updated $updatedStudents student(s).',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } catch (e) {
        // Close loading dialog if open
        if (context.mounted) {
          Navigator.pop(context);
        }

        // Show detailed error message for troubleshooting
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting level: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Level Management',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFF5F5F5),
        // No back button - this is a top-level admin section
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Real-time stream ordered by levelId to maintain course sequence
        // OrderBy ensures levels display in the correct pedagogical order
        stream: FirebaseFirestore.instance
            .collection('levels')
            .orderBy('levelId')
            .snapshots(),
        builder: (context, snapshot) {
          // Loading state while fetching initial data
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Empty state with helpful guidance for first-time admins
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.school_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No levels created yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Click the + button to add a new level',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          final levels = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: levels.length,
            itemBuilder: (context, index) {
              final levelDoc = levels[index];
              final levelData = levelDoc.data() as Map<String, dynamic>;
              
              // Extract nested arrays with type safety
              // Fallback to empty arrays if data is missing to prevent null errors
              final quizzes = List<Map<String, dynamic>>.from(
                levelData['quizzes'] ?? [],
              );
              final pronunciations = List<Map<String, dynamic>>.from(
                levelData['pronunciations'] ?? [],
              );

              return Card(
                color: const Color(0xFFF5F5F5),
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ExpansionTile(
                  // Level number badge for quick reference
                  leading: CircleAvatar(
                    backgroundColor: Colors.black,
                    child: Text(
                      '${levelData['levelId']}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    levelData['title'] ?? 'Untitled',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(levelData['description'] ?? 'No description'),
                      const SizedBox(height: 8),
                      // Content summary chips showing quiz and pronunciation counts
                      // Gives admins quick insight into level completeness
                      Row(
                        children: [
                          _InfoChip(
                            icon: Icons.quiz,
                            label: '${quizzes.length} quizzes',
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          _InfoChip(
                            icon: Icons.mic,
                            label: '${pronunciations.length} pronunciations',
                            color: Colors.orange,
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Action buttons for level management
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.black),
                        onPressed: () {
                          // Navigate to edit screen with existing level data
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddEditLevelScreen(
                                levelId: levelDoc.id,
                                levelData: levelData,
                              ),
                            ),
                          );
                        },
                        tooltip: 'Edit Level',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteLevel(context, levelDoc.id),
                        tooltip: 'Delete Level',
                      ),
                    ],
                  ),
                  // Expanded content showing detailed quiz and pronunciation data
                  // Hidden by default to keep the list manageable
                  children: [
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Quizzes section - shows all quiz questions and answers
                          if (quizzes.isNotEmpty) ...[
                            const Text(
                              'Quizzes:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...quizzes.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final quiz = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.blue[200]!),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          // Quiz number badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Quiz ${idx + 1}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Audio text or identifier
                                          Expanded(
                                            child: Text(
                                              quiz['audio'] ?? '',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      // Quiz question
                                      Text(
                                        quiz['question'] ?? '',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      // Correct answer highlighted in green
                                      Text(
                                        'Correct: ${quiz['correct']}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                            const SizedBox(height: 16),
                          ],
                          
                          // Pronunciation practice section - shows words with pinyin and translation
                          if (pronunciations.isNotEmpty) ...[
                            const Text(
                              'Pronunciation Practice:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...pronunciations.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final pron = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.orange[200]!),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          // Word number badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.orange,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Word ${idx + 1}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Chinese characters
                                          Text(
                                            pron['word'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Pinyin romanization for pronunciation guide
                                          Text(
                                            pron['pinyin'] ?? '',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      // English translation
                                      Text(
                                        pron['translation'] ?? '',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      // Floating action button for adding new levels
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Navigate to add screen without levelId (indicates new level creation)
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddEditLevelScreen(),
            ),
          );
        },
        backgroundColor: Colors.black,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Level',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

/// Reusable info chip widget for displaying content statistics.
/// 
/// Used to show quiz and pronunciation counts in a visually consistent way.
/// The chip color matches the content type (blue for quizzes, orange for pronunciations)
/// to help admins quickly identify content distribution at a glance.
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    Key? key,
    required this.icon,
    required this.label,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1), // Light tint for background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'level_detail_screen.dart';

/// Learning path visualization showing sequential course progression.
/// 
/// Implements linear progression model where:
/// - Users must complete levels in order (no skipping ahead)
/// - Completed levels show green background with check indicator
/// - Current level shows yellow background with person indicator
/// - Locked levels show white background with lock icon
/// 
/// Progressive unlocking design:
/// - Prevents overwhelm by limiting choices
/// - Ensures foundational knowledge before advanced content
/// - Creates clear sense of achievement as levels unlock
/// 
/// Dual StreamBuilder pattern:
/// 1. User document stream: Tracks completion status and current position
/// 2. Levels collection stream: Loads curriculum data with real-time admin updates
/// 
/// This architecture allows admins to add/modify levels without app updates.
class RoadmapScreen extends StatelessWidget {
  const RoadmapScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0), // Warm cream background
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF8F0),
        elevation: 0,
        title: const Text(
          'Roadmap',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFF6B6B), // Coral pink brand color
          ),
        ),
        // No back button - accessed via bottom navigation
        automaticallyImplyLeading: false,
        centerTitle: true,
      ),
      // First StreamBuilder: User progress data
      // Tracks which levels are completed and where user currently is
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          // completedLevels: Array of levelIds user has finished
          final completedLevels = List<int>.from(userData['completedLevels'] ?? []);
          // currentLevel: Next level user should access (gates progression)
          final currentLevel = userData['currentLevel'] ?? 1;

          // Second StreamBuilder: Course curriculum data
          // Ordered by levelId to maintain sequential presentation
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('levels')
                .orderBy('levelId')
                .snapshots(),
            builder: (context, levelsSnapshot) {
              if (levelsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // Empty state: No levels exist yet in Firestore
              // This occurs in fresh deployments before admin adds curriculum
              if (!levelsSnapshot.hasData || levelsSnapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map_outlined, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No levels available yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please wait while the admin sets up the course',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }

              final levels = levelsSnapshot.data!.docs;

              return Stack(
                children: [
                  // Decorative apple elements scattered for visual interest
                  // Positioned strategically to avoid overlapping level cards
                  Positioned(
                    top: 20,
                    right: 20,
                    child: _AppleDecor(),
                  ),
                  Positioned(
                    top: 180,
                    left: 10,
                    child: _AppleDecor(),
                  ),
                  Positioned(
                    top: 350,
                    left: 10,
                    child: _AppleDecor(),
                  ),
                  Positioned(
                    bottom: 100,
                    left: 10,
                    child: _AppleDecor(),
                  ),
                  
                  // Main content: Vertical scrolling list of levels
                  ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: levels.length,
                    itemBuilder: (context, index) {
                      final levelDoc = levels[index];
                      final levelData = levelDoc.data() as Map<String, dynamic>;
                      final levelId = levelData['levelId'] as int;
                      
                      // Calculate level state based on user progress
                      final isCompleted = completedLevels.contains(levelId);
                      // Locked: Level is beyond user's current progression point
                      final isLocked = levelId > currentLevel;
                      // Current: This is the next level user should complete
                      final isCurrent = levelId == currentLevel;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _LevelCard(
                          levelDocId: levelDoc.id,
                          levelData: levelData,
                          isCompleted: isCompleted,
                          isLocked: isLocked,
                          isCurrent: isCurrent,
                          // Locked levels are not tappable - enforces sequential progression
                          // This prevents users from accessing advanced content prematurely
                          onTap: isLocked
                              ? null
                              : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LevelDetailScreen(
                                  levelDocId: levelDoc.id,
                                  levelId: levelId,
                                  levelTitle: levelData['title'] ?? 'Untitled',
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Decorative apple illustration for brand consistency.
/// 
/// Creates simple apple shape using overlapping circles and rectangles:
/// - Outer red circle: Apple body
/// - Inner lighter circle: Adds depth/dimension
/// - Brown rectangle: Stem
/// - Green oval: Leaf
/// 
/// These decorations maintain visual theme across all screens
/// and make the learning interface more playful and engaging.
class _AppleDecor extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.red[400], // Outer apple color
        shape: BoxShape.circle,
      ),
      child: Stack(
        children: [
          // Inner circle creates depth effect
          Center(
            child: Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: Colors.red[300], // Lighter shade for dimension
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Apple stem
          Positioned(
            top: 8,
            right: 18,
            child: Container(
              width: 8,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.brown[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Apple leaf
          Positioned(
            top: 6,
            right: 22,
            child: Container(
              width: 12,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.green[600],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual level card displaying title, content counts, and progress state.
/// 
/// Visual state system:
/// - Green background: Completed (unlocks sense of achievement)
/// - Yellow background: Current level (draws attention to next action)
/// - Orange background: Available but not current (accessible backlog)
/// - White background: Locked (creates aspirational goals)
/// 
/// Content indicators show:
/// - Quiz count (blue icon): Number of knowledge check questions
/// - Pronunciation count (purple icon): Number of speaking exercises
/// 
/// This preview helps users gauge time commitment before entering level.
class _LevelCard extends StatelessWidget {
  final String levelDocId;
  final Map<String, dynamic> levelData;
  final bool isCompleted;
  final bool isLocked;
  final bool isCurrent;
  final VoidCallback? onTap;

  const _LevelCard({
    Key? key,
    required this.levelDocId,
    required this.levelData,
    required this.isCompleted,
    required this.isLocked,
    required this.isCurrent,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Color coding communicates level state at a glance
    // This reduces cognitive load - users instantly understand status
    Color cardColor;
    Color borderColor;

    if (isCompleted) {
      // Green = success, achievement, progress made
      cardColor = const Color(0xFFB8D4B8);
      borderColor = Colors.black;
    } else if (isCurrent) {
      // Yellow = attention, next action, "start here"
      cardColor = const Color(0xFFFFD966);
      borderColor = Colors.black;
    } else if (isLocked) {
      // White/grey = unavailable, future content
      cardColor = Colors.white;
      borderColor = Colors.black;
    } else {
      // Orange = available, can revisit for practice
      cardColor = const Color(0xFFFFB8A0);
      borderColor = Colors.black;
    }

    // Count content items to display activity preview
    final quizCount = (levelData['quizzes'] as List?)?.length ?? 0;
    final pronunciationCount = (levelData['pronunciations'] as List?)?.length ?? 0;

    return GestureDetector(
      // Locked levels are non-interactive
      // This provides passive feedback - user can see what's ahead but can't access yet
      onTap: isLocked ? null : onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: cardColor,
          border: Border.all(color: borderColor, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            // Level number badge in top-left
            // Provides quick reference for curriculum position
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black, width: 1.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${levelData['levelId']}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            
            // Main content area with title and activity counts
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    levelData['title'] ?? 'Untitled',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      // Grey text for locked levels creates disabled appearance
                      color: isLocked ? Colors.grey : Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  
                  // Activity count row with color-coded icons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // Quiz count indicator
                      Icon(Icons.quiz, size: 14, color: Colors.blue[700]),
                      const SizedBox(width: 4),
                      Text(
                        '$quizCount',
                        style: TextStyle(
                          fontSize: 12,
                          color: isLocked ? Colors.grey : Colors.blue[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Pronunciation count indicator
                      Icon(Icons.mic, size: 14, color: Colors.purple[700]),
                      const SizedBox(width: 4),
                      Text(
                        '$pronunciationCount',
                        style: TextStyle(
                          fontSize: 12,
                          color: isLocked ? Colors.grey : Colors.purple[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Lock icon overlay for inaccessible levels
            // Centered placement makes locked state unmistakable
            if (isLocked)
              Center(
                child: Icon(
                  Icons.lock,
                  size: 40,
                  color: Colors.grey[600],
                ),
              ),
            
            // Current level indicator in top-right
            // Person icon suggests "you are here" without text
            if (isCurrent)
              Positioned(
                top: -8,
                right: -8,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF4A4A4A), // Dark grey for contrast
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

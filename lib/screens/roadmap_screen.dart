import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'level_detail_screen.dart';

class RoadmapScreen extends StatelessWidget {
  const RoadmapScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF8F0),
        elevation: 0,
        title: const Text(
          'Roadmap',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFF6B6B),
          ),
        ),
        automaticallyImplyLeading: false,
        centerTitle: true,
      ),
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
          final completedLevels = List<int>.from(userData['completedLevels'] ?? []);
          final currentLevel = userData['currentLevel'] ?? 1;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('levels')
                .orderBy('levelId')
                .snapshots(),
            builder: (context, levelsSnapshot) {
              if (levelsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

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
                  // Decorative apples
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
                  // Vertical list
                  ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: levels.length,
                    itemBuilder: (context, index) {
                      final levelDoc = levels[index];
                      final levelData = levelDoc.data() as Map<String, dynamic>;
                      final levelId = levelData['levelId'] as int;
                      final isCompleted = completedLevels.contains(levelId);
                      final isLocked = levelId > currentLevel;
                      final isCurrent = levelId == currentLevel;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _LevelCard(
                          levelDocId: levelDoc.id,
                          levelData: levelData,
                          isCompleted: isCompleted,
                          isLocked: isLocked,
                          isCurrent: isCurrent,
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

class _AppleDecor extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.red[400],
        shape: BoxShape.circle,
      ),
      child: Stack(
        children: [
          Center(
            child: Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: Colors.red[300],
                shape: BoxShape.circle,
              ),
            ),
          ),
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
    Color cardColor;
    Color borderColor;

    if (isCompleted) {
      cardColor = const Color(0xFFB8D4B8);
      borderColor = Colors.black;
    } else if (isCurrent) {
      cardColor = const Color(0xFFFFD966);
      borderColor = Colors.black;
    } else if (isLocked) {
      cardColor = Colors.white;
      borderColor = Colors.black;
    } else {
      cardColor = const Color(0xFFFFB8A0);
      borderColor = Colors.black;
    }

    final quizCount = (levelData['quizzes'] as List?)?.length ?? 0;
    final pronunciationCount = (levelData['pronunciations'] as List?)?.length ?? 0;

    return GestureDetector(
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
            // Level number badge
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
            // Main content
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
                      color: isLocked ? Colors.grey : Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
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
            // Lock icon for locked levels
            if (isLocked)
              Center(
                child: Icon(
                  Icons.lock,
                  size: 40,
                  color: Colors.grey[600],
                ),
              ),
            // Current level indicator
            if (isCurrent)
              Positioned(
                top: -8,
                right: -8,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF4A4A4A),
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
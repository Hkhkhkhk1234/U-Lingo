import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'roadmap_screen.dart';
import 'vocabulary_screen.dart';
import 'chatbot_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _screens = [
      DashboardHome(onNavigateToRoadmap: () => _navigateToTab(1)),
      const RoadmapScreen(),
      const VocabularyScreen(levelId: 0),
      const ChatbotScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE8D5B7),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _navigateToTab,
          type: BottomNavigationBarType.fixed,
          backgroundColor: const Color(0xFFE8D5B7),
          selectedItemColor: const Color(0xFF5C4033),
          unselectedItemColor: const Color(0xFF8B7355),
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: Image.asset(
                'assets/icons/home_icon.png',
                width: 28,
                height: 28,
                color: _currentIndex == 0 ? const Color(0xFF5C4033) : const Color(0xFF8B7355),
              ),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Image.asset(
                'assets/icons/roadmap_icon.png',
                width: 28,
                height: 28,
                color: _currentIndex == 1 ? const Color(0xFF5C4033) : const Color(0xFF8B7355),
              ),
              label: 'Roadmap',
            ),
            BottomNavigationBarItem(
              icon: Image.asset(
                'assets/icons/vocabulary_icon.png',
                width: 28,
                height: 28,
                color: _currentIndex == 2 ? const Color(0xFF5C4033) : const Color(0xFF8B7355),
              ),
              label: 'Vocab',
            ),
            BottomNavigationBarItem(
              icon: Image.asset(
                'assets/icons/chatbot_icon.png',
                width: 28,
                height: 28,
                color: _currentIndex == 3 ? const Color(0xFF5C4033) : const Color(0xFF8B7355),
              ),
              label: 'Chatbot',
            ),
            BottomNavigationBarItem(
              icon: Image.asset(
                'assets/icons/account_icon.png',
                width: 28,
                height: 28,
                color: _currentIndex == 4 ? const Color(0xFF5C4033) : const Color(0xFF8B7355),
              ),
              label: 'Account',
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardHome extends StatelessWidget {
  final VoidCallback onNavigateToRoadmap;

  const DashboardHome({
    Key? key,
    required this.onNavigateToRoadmap,
  }) : super(key: key);

  Future<void> _updateStreak() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();

    final data = userDoc.data()!;
    final lastAccess = DateTime.parse(data['lastAccessDate'] ?? DateTime.now().toIso8601String());
    final today = DateTime.now();
    final difference = today.difference(lastAccess).inDays;

    int newStreak = data['streak'] ?? 0;
    if (difference == 1) {
      newStreak++;
    } else if (difference > 1) {
      newStreak = 1;
    }

    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'streak': newStreak,
      'lastAccessDate': today.toIso8601String(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF8F0),
        elevation: 0,
        title: const Text(
          'Home',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFFE07A5F),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Image.asset(
              'assets/icons/app_icon.png', // Replace with your app icon
              width: 40,
              height: 40,
            ),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final streak = userData['streak'] ?? 0;
          final currentLevel = userData['currentLevel'] ?? 1;
          final completedLevels = List<int>.from(userData['completedLevels'] ?? []);
          final achievements = List<String>.from(userData['achievements'] ?? []);

          _updateStreak();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Streak Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAE8C8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.black, width: 3),
                  ),
                  child: Row(
                    children: [
                      // Left side - Streak PNG (placeholder)
                      Image.asset(
                        'assets/icons/streak_icon.png', // Replace with your streak PNG path
                        width: 100,
                        height: 100,
                      ),
                      const Spacer(),
                      // Right side - Number and Fire Icon together
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Days Streak',
                            style: TextStyle(
                              color: Color(0xFFE07A5F),
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                '$streak',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 72,
                                  fontWeight: FontWeight.bold,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.local_fire_department,
                                size: 80,
                                color: Color(0xFFFF6B6B),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "You're doing so well!\nKeep going!",
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Continue Course Card
                const Text(
                  'Continue Course',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Colors.black, width: 3),
                  ),
                  color: Colors.white,
                  child: InkWell(
                    onTap: onNavigateToRoadmap,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Continue Learning',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Level $currentLevel',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Achievements Section
                const Text(
                  'Your Achievements',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 140,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _AchievementCard(
                        icon: Icons.star,
                        title: 'The\nAdventurer',
                        isUnlocked: achievements.contains('first_step'),
                      ),
                      _AchievementCard(
                        icon: Icons.local_fire_department,
                        title: '7 Day\nStreak',
                        isUnlocked: streak >= 7,
                      ),
                      _AchievementCard(
                        icon: Icons.emoji_events,
                        title: 'Complete\n5 Levels',
                        isUnlocked: completedLevels.length >= 5,
                      ),
                      _AchievementCard(
                        icon: Icons.school,
                        title: 'Graduate',
                        isUnlocked: completedLevels.length >= 10,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isUnlocked;

  const _AchievementCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.isUnlocked,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnlocked ? const Color(0xFFB8E6E1) : Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.black,
          width: 3,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 40,
            color: isUnlocked ? const Color(0xFF5C4033) : Colors.grey,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isUnlocked ? Colors.black : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'roadmap_screen.dart';
import 'vocabulary_screen.dart';
import 'chatbot_screen.dart';
import 'profile_screen.dart';

/// Main navigation container managing bottom tab navigation.
/// 
/// Acts as the primary navigation hub after user authentication and onboarding.
/// Implements persistent bottom navigation bar pattern where tab state is
/// preserved when switching between screens (unlike stack-based navigation).
/// 
/// Navigation structure:
/// - Index 0: Home dashboard with streak tracking and quick actions
/// - Index 1: Roadmap showing learning progression path
/// - Index 2: Vocabulary practice and review
/// - Index 3: AI chatbot for language practice
/// - Index 4: User profile and settings
/// 
/// State management approach: Local state (_currentIndex) controls which
/// screen is displayed, avoiding navigation stack complexity.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0; // Tracks active tab, defaults to Home

  /// Updates active tab index without navigation stack manipulation.
  /// 
  /// This approach maintains all screens in memory, preserving their state
  /// when users switch tabs. Prevents losing scroll position, form input,
  /// or other transient UI state that would be lost with push/pop navigation.
  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // Screen array initialized in build method to capture latest callback
    // DashboardHome needs onNavigateToRoadmap callback to trigger tab switch
    final List<Widget> _screens = [
      DashboardHome(onNavigateToRoadmap: () => _navigateToTab(1)),
      const RoadmapScreen(),
      const VocabularyScreen(levelId: 0), // levelId: 0 shows all vocabulary
      const ChatbotScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      // Display currently selected screen
      // All screens remain in memory; only visibility changes
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE8D5B7), // Warm beige matches brand palette
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2), // Shadow above navbar
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _navigateToTab,
          type: BottomNavigationBarType.fixed, // Prevents icon shifting when selected
          backgroundColor: const Color(0xFFE8D5B7),
          selectedItemColor: const Color(0xFF5C4033), // Dark brown for selected
          unselectedItemColor: const Color(0xFF8B7355), // Lighter brown for unselected
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0, // Shadow handled by container instead
          items: [
            BottomNavigationBarItem(
              // Custom PNG icons for brand consistency
              // Color property tints image based on selection state
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

/// Home dashboard displaying user progress and quick access to key features.
/// 
/// Primary engagement screen showing:
/// - Daily streak counter (gamification element encouraging consistent learning)
/// - Current level progress with quick continue action
/// - Achievement badges (unlock based on milestones)
/// 
/// Real-time data sync via StreamBuilder ensures UI reflects latest progress
/// even if updated from other devices or admin panel.
/// 
/// Streak calculation happens on every build to maintain accuracy without
/// requiring manual refresh from users.
class DashboardHome extends StatelessWidget {
  final VoidCallback onNavigateToRoadmap;

  const DashboardHome({
    Key? key,
    required this.onNavigateToRoadmap,
  }) : super(key: key);

  /// Updates user's learning streak based on last access date.
  /// 
  /// Streak logic:
  /// - Same day: No change (prevents multiple increments per day)
  /// - Next consecutive day: Increment by 1 (rewards daily consistency)
  /// - Gap of 2+ days: Reset to 1 (user broke streak, starts fresh)
  /// 
  /// This encourages daily engagement without being punitive - missing one
  /// day doesn't zero out progress, but creates urgency to maintain streak.
  /// 
  /// Called on every build, but Firestore caching minimizes API costs
  /// since lastAccessDate typically hasn't changed since last check.
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
    
    // Streak logic implementation
    if (difference == 1) {
      // Consecutive day - increment streak
      newStreak++;
    } else if (difference > 1) {
      // Streak broken - reset to day 1
      // User gets credit for today's access
      newStreak = 1;
    }
    // If difference == 0, same day access - no change to streak

    // Update both streak counter and access timestamp atomically
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'streak': newStreak,
      'lastAccessDate': today.toIso8601String(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0), // Warm cream background
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF8F0),
        elevation: 0,
        title: const Text(
          'Home',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFFE07A5F), // Coral pink brand color
          ),
        ),
        actions: [
          // App logo provides consistent branding across screens
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Image.asset(
              'assets/icons/app_icon.png',
              width: 40,
              height: 40,
            ),
          ),
        ],
      ),
      // StreamBuilder enables real-time UI updates when Firestore data changes
      // This is critical for multi-device support and admin-triggered updates
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

          // Update streak on every build
          // Firebase caching prevents excessive API calls
          _updateStreak();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Streak Card - Primary motivational element
                // Large, prominent design emphasizes importance of daily engagement
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAE8C8), // Light golden yellow
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.black, width: 3), // Bold border for emphasis
                  ),
                  child: Row(
                    children: [
                      // Visual streak icon reinforces concept
                      Image.asset(
                        'assets/icons/streak_icon.png',
                        width: 100,
                        height: 100,
                      ),
                      const Spacer(),
                      // Right-aligned streak counter with motivational message
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
                          // Large streak number with fire icon creates visual impact
                          // Fire icon is universal symbol for streak/momentum
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                '$streak',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 72,
                                  fontWeight: FontWeight.bold,
                                  height: 1, // Tight line height for visual impact
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.local_fire_department,
                                size: 80,
                                color: Color(0xFFFF6B6B), // Red-orange fire color
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Positive reinforcement message
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

                // Continue Course Card - Quick access to learning path
                // Reduces friction by eliminating need to navigate through tabs
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
                    // Triggers tab navigation to Roadmap screen
                    // This maintains bottom nav state while jumping to specific content
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
                                // Shows user's current position in curriculum
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

                // Achievements Section - Gamification badges
                // Encourages long-term engagement through milestone rewards
                const Text(
                  'Your Achievements',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                // Horizontal scrolling list allows unlimited achievement additions
                SizedBox(
                  height: 140,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      // First achievement - rewards initial engagement
                      _AchievementCard(
                        icon: Icons.star,
                        title: 'The\nAdventurer',
                        isUnlocked: achievements.contains('first_step'),
                      ),
                      // Streak milestone - encourages consistent daily practice
                      _AchievementCard(
                        icon: Icons.local_fire_department,
                        title: '7 Day\nStreak',
                        isUnlocked: streak >= 7,
                      ),
                      // Progress milestone - rewards course completion
                      _AchievementCard(
                        icon: Icons.emoji_events,
                        title: 'Complete\n5 Levels',
                        isUnlocked: completedLevels.length >= 5,
                      ),
                      // Final achievement - celebrates course mastery
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

/// Individual achievement badge card with locked/unlocked states.
/// 
/// Visual design principles:
/// - Unlocked: Teal background with black icon (celebration/reward)
/// - Locked: Grey background with grey icon (aspirational/future goal)
/// 
/// This creates clear visual distinction between earned and pending achievements,
/// motivating users to unlock remaining badges.
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
        // Color indicates unlock state
        // Teal creates positive association with earned achievements
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
            // Color contrast emphasizes unlock status
            color: isUnlocked ? const Color(0xFF5C4033) : Colors.grey,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              // Text color also reflects state
              color: isUnlocked ? Colors.black : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'language_selection_screen.dart';

/// User profile and account management screen.
/// 
/// Displays user statistics (achievements, lessons, streak) and provides
/// access to account settings. Integrates with Firebase Auth for authentication
/// and Firestore for real-time user data synchronization.
/// 
/// Critical features:
/// - Real-time statistics updates via Firestore streams
/// - Destructive actions (sign out, reset progress) require confirmation
/// - Context-mounted checks prevent setState calls after widget disposal
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  /// Handles user sign-out with confirmation dialog.
  /// 
  /// Implements two-step confirmation to prevent accidental sign-outs,
  /// which would force users to re-authenticate. Context-mounted checks
  /// ensure UI feedback occurs only if the widget is still active.
  Future<void> _signOut(BuildContext context) async {
    // Show confirmation dialog to prevent accidental sign-outs
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          // Red background emphasizes destructive action
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (shouldSignOut == true) {
      try {
        await FirebaseAuth.instance.signOut();
        
        // Context-mounted check prevents showing SnackBar after navigation
        // This avoids "setState called after dispose" errors
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Signed out successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error signing out: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  /// Resets all user progress with confirmation dialog.
  /// 
  /// This is a destructive, irreversible action that clears:
  /// - Streak count (daily learning consistency)
  /// - Current level progress
  /// - Completed levels history
  /// - Earned achievements
  /// 
  /// Updates lastAccessDate to maintain activity tracking integrity
  /// after reset. Strong confirmation dialog prevents accidental data loss.
  Future<void> _resetProgress(BuildContext context) async {
    // Explicit warning about irreversibility prevents accidental resets
    final shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Progress'),
        content: const Text(
          'This will reset all your progress including streak, levels, and achievements. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          // Red button emphasizes destructive nature
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (shouldReset == true) {
      try {
        final userId = FirebaseAuth.instance.currentUser!.uid;
        
        // Update specific fields rather than deleting document
        // This preserves user metadata like email, name, language preference
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'streak': 0,
          'currentLevel': 1, // Reset to beginning
          'completedLevels': [], // Clear all progress
          'achievements': [], // Remove all earned achievements
          'lastAccessDate': DateTime.now().toIso8601String(), // Maintain activity tracking
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Progress reset successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error resetting progress: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Navigates to language selection screen.
  /// 
  /// Allows users to change their learning language preference.
  /// Uses standard navigation to allow back navigation if user changes mind.
  Future<void> _changeLanguage(BuildContext context) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LanguageSelectionScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // User is guaranteed to exist here - ProfileScreen only accessible
    // after successful authentication via login flow
    final user = FirebaseAuth.instance.currentUser!;
    final userId = user.uid;

    return Scaffold(
      // Light cream background maintains brand consistency with welcome screen
      backgroundColor: const Color(0xFFFFF8E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF8E8),
        elevation: 0, // Flat design for modern appearance
        title: const Text(
          'Account',
          style: TextStyle(
            color: Color(0xFFE88B8B), // Coral pink for brand identity
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        // Disable back button - accessed via bottom navigation, not navigation stack
        automaticallyImplyLeading: false,
        actions: [
          // Apple icon serves as decorative brand element
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Image.asset(
              'assets/images/apple.png',
              width: 50,
              height: 50,
            ),
          ),
        ],
      ),
      // StreamBuilder enables real-time updates when user data changes
      // (e.g., completing lessons in another session, earning achievements)
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Extract user statistics from Firestore document
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final completedLevels = List<int>.from(userData['completedLevels'] ?? []);
          final streak = userData['streak'] ?? 0;
          final achievements = List.from(userData['achievements'] ?? []);

          return SingleChildScrollView(
            child: Column(
              children: [
                // Profile Card - displays user identity information
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      // Subtle shadow provides depth without overwhelming design
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Display name defaults to 'User' if not set during signup
                        Text(
                          user.displayName ?? 'User',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Email provides unique identifier for user
                        Text(
                          user.email ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Statistics Section - gamification metrics to encourage engagement
                // Three-column layout shows key progress indicators at a glance
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: _StatCard(
                          iconPath: 'assets/images/trophy_icon.png',
                          title: 'Achievements achieved',
                          value: '${achievements.length}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          iconPath: 'assets/images/Lesson_icon.png',
                          title: 'Lessons completed',
                          value: '${completedLevels.length}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          iconPath: 'assets/images/day_streak_icon.png',
                          title: 'Days Streak',
                          value: '$streak',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Account Settings Section
                // Left-aligned header follows standard settings UI patterns
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Account Settings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Edit Profile - placeholder for future feature
                _SettingsTile(
                  title: 'Edit Profile',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Edit Profile coming soon!'),
                      ),
                    );
                  },
                ),

                // Change language - functional navigation to language selection
                _SettingsTile(
                  title: 'Change language',
                  onTap: () => _changeLanguage(context),
                ),

                // Notification settings - placeholder for future push notification configuration
                _SettingsTile(
                  title: 'Notification',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notification settings coming soon!'),
                      ),
                    );
                  },
                ),

                // Password change - placeholder for future password reset flow
                _SettingsTile(
                  title: 'Change password',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Change password coming soon!'),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // About Section - informational and legal links
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'About',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                _SettingsTile(
                  title: 'FAQ',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('FAQ coming soon!'),
                      ),
                    );
                  },
                ),

                _SettingsTile(
                  title: 'Privacy Policy',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Privacy Policy coming soon!'),
                      ),
                    );
                  },
                ),

                // Terms tile reused to show app information
                // This is a workaround - ideally "About" and "Terms" would be separate
                _SettingsTile(
                  title: 'Terms and Agreements',
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('About U-Lingo'),
                        content: const Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('U-Lingo v1.0.0'),
                            SizedBox(height: 8),
                            Text('UNIMAS Language Learning Platform'),
                            SizedBox(height: 16),
                            Text(
                              'Learn languages with ease through interactive lessons, quizzes, and AI-powered assistance.',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                _SettingsTile(
                  title: 'Help',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Help & Support coming soon!'),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Destructive action buttons placed at bottom
                // Both use outlined style to reduce visual weight compared to filled buttons
                // Placement at bottom follows mobile UI conventions for dangerous actions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // Reset Progress - destructive but reversible by re-learning
                      InkWell(
                        onTap: () => _resetProgress(context),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black, width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Reset Progress',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Sign Out - removes authentication state
                      InkWell(
                        onTap: () => _signOut(context),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black, width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Sign Out',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Displays a single statistic card with icon, value, and label.
/// 
/// Used in a horizontal row to show key user metrics (achievements, lessons, streak).
/// Icon-first layout draws attention to visual elements before numerical data.
class _StatCard extends StatelessWidget {
  final String iconPath;
  final String title;
  final String value;

  const _StatCard({
    Key? key,
    required this.iconPath,
    required this.title,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Icon provides immediate visual recognition of metric type
        Image.asset(
          iconPath,
          width: 60,
          height: 60,
        ),
        const SizedBox(height: 8),
        // Bold, large value emphasizes the statistic
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        // Smaller label text provides context without overwhelming the number
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

/// Generic settings list item with title and tap handler.
/// 
/// Provides consistent styling across all settings options.
/// Minimal design focuses attention on text labels rather than decorative elements.
/// InkWell provides touch ripple feedback for better user interaction.
class _SettingsTile extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _SettingsTile({
    Key? key,
    required this.title,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      // Asymmetric margins align with section headers above
      margin: const EdgeInsets.only(left: 24, right: 16, top: 4, bottom: 4),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          // Vertical padding creates adequate touch targets (44pt minimum iOS guideline)
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

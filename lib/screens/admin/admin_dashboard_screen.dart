import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:ulingo/screens/admin/level_management_screen.dart';
import 'package:ulingo/screens/admin/reports_screen.dart';
import 'package:ulingo/screens/admin/students_management_screen.dart';

/// Main admin dashboard with sidebar navigation and content area.
/// 
/// Provides a comprehensive management interface for U-Lingo administrators with:
/// - Persistent sidebar navigation for quick access to all admin features
/// - Multiple screen sections (Dashboard, Lessons, Students, Reports)
/// - Real-time data visualization of platform statistics
/// - Responsive layout with fixed sidebar and dynamic content area
/// 
/// Architecture:
/// The dashboard uses a two-panel layout with a fixed-width sidebar (250px)
/// and an expandable content area. Navigation state is managed locally,
/// while each screen manages its own data streams from Firestore.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // Tracks which navigation item is currently selected
  // Used to display the corresponding screen in the content area
  int _selectedIndex = 0;

  // List of screen widgets corresponding to each navigation item
  // Screens are created once and reused to preserve state across navigation
  final List<Widget> _screens = [
    const DashboardHomeScreen(),
    const LevelManagementScreen(),
    const StudentsManagementScreen(),
    const ReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Row(
        children: [
          // Fixed-width sidebar for consistent navigation
          // Contains branding, navigation items, and logout button
          Container(
            width: 250,
            color: Colors.white,
            child: Column(
              children: [
                // Branding section with U-Lingo logo
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      // Logo icon with abbreviated brand name
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            'U-L',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'U-LINGO',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // Navigation items - each corresponds to a management section
                _buildNavItem(
                  icon: Icons.dashboard_outlined,
                  label: 'Dashboard',
                  index: 0,
                ),
                _buildNavItem(
                  icon: Icons.book_outlined,
                  label: 'Lessons',
                  index: 1,
                ),
                _buildNavItem(
                  icon: Icons.people_outline,
                  label: 'Students',
                  index: 2,
                ),
                _buildNavItem(
                  icon: Icons.assignment_outlined,
                  label: 'Report',
                  index: 3,
                ),
                
                // Push logout button to bottom of sidebar
                const Spacer(),
                
                // Logout button positioned at bottom for easy access
                // Placed at bottom to prevent accidental clicks during normal navigation
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        // AuthWrapper automatically detects sign out and navigates to login
                      },
                      icon: const Icon(Icons.logout, size: 20),
                      label: const Text('Log Out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[800],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Expandable content area that fills remaining horizontal space
          // Displays the screen corresponding to the selected navigation item
          Expanded(
            child: _screens[_selectedIndex],
          ),
        ],
      ),
    );
  }

  /// Builds a single navigation item with icon and label.
  /// 
  /// Visual state changes based on selection:
  /// - Selected: darker text, bolder font, light background
  /// - Unselected: lighter text, normal font, transparent background
  /// 
  /// This visual feedback helps users understand their current location
  /// in the admin interface.
  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => _selectedIndex = index);
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFF0F0F0) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.black : Colors.grey[600],
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.grey[600],
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dashboard home screen displaying platform statistics and top students.
/// 
/// Features:
/// - Real-time statistics cards (students, lessons, completion rate)
/// - Top 5 students leaderboard ranked by completed lessons
/// - Live data updates through Firestore streams
/// 
/// Data Architecture:
/// Uses nested StreamBuilders to combine data from multiple collections:
/// 1. Users collection - provides student data and completion tracking
/// 2. Levels collection - provides total lesson count for calculations
/// 
/// This approach ensures the dashboard always displays current data without
/// manual refresh, providing admins with accurate, up-to-date insights.
class DashboardHomeScreen extends StatelessWidget {
  const DashboardHomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Primary stream: monitors all student users
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, usersSnapshot) {
        if (!usersSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = usersSnapshot.data!.docs;
        final totalStudents = users.length;

        // Secondary stream: monitors all available lessons
        // Nested inside users stream to enable cross-collection calculations
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('levels').snapshots(),
          builder: (context, levelsSnapshot) {
            final totalLevels = levelsSnapshot.hasData
                ? levelsSnapshot.data!.docs.length
                : 0;

            // Calculate platform-wide average completion rate
            // Formula: (total completed lessons) / (students × available lessons) × 100
            // This metric shows overall student engagement and content progress
            int totalCompleted = 0;
            for (var user in users) {
              final data = user.data() as Map<String, dynamic>;
              final completedLevels = List<int>.from(data['completedLevels'] ?? []);
              totalCompleted += completedLevels.length;
            }
            final avgCompletionRate = totalStudents > 0 && totalLevels > 0
                ? (totalCompleted / (totalStudents * totalLevels) * 100)
                .toStringAsFixed(0)
                : '0';

            // Generate leaderboard by sorting students by completion count
            // Top performers are highlighted to recognize achievement
            final sortedUsers = users.toList()
              ..sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aCompleted =
                    List<int>.from(aData['completedLevels'] ?? []).length;
                final bCompleted =
                    List<int>.from(bData['completedLevels'] ?? []).length;
                return bCompleted.compareTo(aCompleted); // Descending order
              });
            final topStudents = sortedUsers.take(5).toList();

            return Scaffold(
              backgroundColor: const Color(0xFFF5F5F5),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with title and secondary logout option
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Dashboard',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // Secondary logout button in header for convenience
                        // Provides quick access without scrolling to sidebar bottom
                        OutlinedButton.icon(
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                          },
                          icon: const Icon(Icons.logout, size: 18),
                          label: const Text('Log Out'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[800],
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            side: BorderSide(color: Colors.grey[300]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Statistics cards displaying key platform metrics
                    // Three cards provide at-a-glance overview of platform health
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'Total Students',
                            value: totalStudents.toString(),
                            icon: Icons.people_outline,
                            change: '+12', // TODO: Calculate actual change from historical data
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _StatCard(
                            title: 'Total Lessons',
                            value: totalLevels.toString(),
                            icon: Icons.menu_book_outlined,
                            change: '+3', // TODO: Calculate actual change from historical data
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _StatCard(
                            title: 'Completion Rate',
                            value: '$avgCompletionRate%',
                            icon: Icons.emoji_events_outlined,
                            change: '+4%', // TODO: Calculate actual change from historical data
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Top students leaderboard section
                    const Text(
                      'Top Students',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Table-style leaderboard with header and rows
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          // Table header with column labels
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                              border: Border(
                                bottom: BorderSide(color: Colors.grey[200]!),
                              ),
                            ),
                            child: Row(
                              children: const [
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    'No',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    'Name',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Email',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    'Vocabulary',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Student rows displaying rank, name, email, and progress
                          // Progress shown as "completed/total" format (e.g., "5/10")
                          ...topStudents.asMap().entries.map((entry) {
                            final index = entry.key;
                            final userData =
                            entry.value.data() as Map<String, dynamic>;
                            final completedLevels =
                            List<int>.from(userData['completedLevels'] ?? []);

                            return Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    // Remove border from last row for clean appearance
                                    color: index == topStudents.length - 1
                                        ? Colors.transparent
                                        : Colors.grey[200]!,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Rank number with # prefix
                                  SizedBox(
                                    width: 60,
                                    child: Text(
                                      '#${index + 1}',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  // Student name
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      userData['name'] ?? 'Unknown',
                                      style: const TextStyle(
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  // Student email (lighter color for visual hierarchy)
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      userData['email'] ?? 'No email',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                  // Completion progress (completed/total)
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      '${completedLevels.length}/${totalLevels}',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Reusable statistic card widget displaying a single metric.
/// 
/// Features:
/// - Large numeric value for emphasis
/// - Descriptive icon and title
/// - Change indicator showing trend (e.g., "+12")
/// - Options menu (currently non-functional)
/// 
/// Design Pattern:
/// The card uses visual hierarchy to prioritize information:
/// 1. Value (largest, most prominent)
/// 2. Title (medium, descriptive)
/// 3. Change indicator (smallest, supplementary)
/// 
/// TODO: Implement change calculation based on historical data
/// Currently shows hardcoded values - should compare with previous period
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final String change; // Change indicator (e.g., "+12" or "-5%")

  const _StatCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    required this.change,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        // Subtle shadow for card elevation
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with icon and options menu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 24, color: Colors.grey[700]),
              // Options menu placeholder (currently empty)
              // TODO: Add actions like "View details", "Export data", etc.
              PopupMenuButton(
                icon: Icon(Icons.more_horiz, color: Colors.grey[400]),
                itemBuilder: (context) => [],
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Main metric value - largest and most prominent
          Text(
            value,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          // Footer row with title and change indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Descriptive title
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              // Change indicator with positive styling (green background)
              // TODO: Make color dynamic based on positive/negative change
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4F4DD), // Light green
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      change,
                      style: const TextStyle(
                        color: Color(0xFF2D7738), // Dark green
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Upward arrow indicating positive trend
                    const Icon(
                      Icons.arrow_outward,
                      color: Color(0xFF2D7738),
                      size: 12,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

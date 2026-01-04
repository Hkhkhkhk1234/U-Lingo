import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Screen for viewing and managing all registered students in the language learning app.
/// 
/// Provides real-time student list with search functionality, displaying key metrics
/// like progress, streak, and completion status. Uses Firestore streams for live updates
/// when student data changes across devices.
/// 
/// Features:
/// - Real-time student list ordered by join date (newest first)
/// - Search by name or email
/// - Detailed student information dialog
/// - Visual progress indicators (level, completed courses, streak)
class StudentsManagementScreen extends StatefulWidget {
  const StudentsManagementScreen({Key? key}) : super(key: key);

  @override
  State<StudentsManagementScreen> createState() => _StudentsManagementScreenState();
}

class _StudentsManagementScreenState extends State<StudentsManagementScreen> {
  // Search query stored in lowercase for case-insensitive comparison
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    // Prevent memory leaks by disposing controller
    _searchController.dispose();
    super.dispose();
  }

  /// Displays comprehensive student information in a modal dialog.
  /// 
  /// Shows all relevant student data including learning progress, streak,
  /// and account creation date. Uses a scrollable content area to handle
  /// varying amounts of information gracefully on different screen sizes.
  void _showStudentDetails(Map<String, dynamic> studentData, String studentId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.person, color: Colors.black),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                studentData['name'] ?? 'Unknown Student',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(
                icon: Icons.email,
                label: 'Email',
                value: studentData['email'] ?? 'N/A',
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.language,
                label: 'Learning',
                value: studentData['selectedLanguage'] ?? 'N/A',
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.trending_up,
                label: 'Current Level',
                value: '${studentData['currentLevel'] ?? 1}',
              ),
              const SizedBox(height: 12),
              // Shows completion progress out of total 10 levels
              _DetailRow(
                icon: Icons.check_circle,
                label: 'Completed Levels',
                value: '${List<int>.from(studentData['completedLevels'] ?? []).length} / 10',
              ),
              const SizedBox(height: 12),
              // Streak displayed in days to motivate consistent learning
              _DetailRow(
                icon: Icons.local_fire_department,
                label: 'Streak',
                value: '${studentData['streak'] ?? 0} days',
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.calendar_today,
                label: 'Joined',
                value: studentData['createdAt'] != null
                    ? _formatDate(studentData['createdAt'] as Timestamp)
                    : 'N/A',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.black,
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Converts Firestore Timestamp to readable date format (DD/MM/YYYY).
  /// Uses simple format for international compatibility.
  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Students',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        // No back button since this is a primary navigation screen
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Search Bar Section
          // Sticky search bar at top for easy access while scrolling
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFF5F5F5),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'lessons by title, number, or description...',
                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                // Show clear button only when search has text
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[400]!, width: 1.5),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              // Convert to lowercase immediately for case-insensitive search
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
              },
            ),
          ),

          // Students List Section
          // Uses StreamBuilder for real-time updates from Firestore
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // Order by createdAt descending shows newest students first
              // This helps administrators track recent registrations
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                // Show loading indicator while initial data loads
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.black));
                }

                // Empty state when no students exist in database
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No students registered yet',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                var students = snapshot.data!.docs;

                // Filter students based on search query
                // Searches both name and email fields for maximum flexibility
                if (_searchQuery.isNotEmpty) {
                  students = students.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    final email = (data['email'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery) || email.contains(_searchQuery);
                  }).toList();
                }

                // Show "no results" state when search yields no matches
                // Differentiated from empty database state for clarity
                if (students.isEmpty && _searchQuery.isNotEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No students found',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                // Main content display with student list and summary
                return Column(
                  children: [
                    // Summary header showing total and active student counts
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Students: ${students.length}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          // Active badge (currently all students are active)
                          // Future enhancement could track last login date
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4F4DD),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'Active: ${students.length}',
                                  style: const TextStyle(
                                    color: Color(0xFF2E7D32),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Scrollable student list with dividers for visual separation
                    Expanded(
                      child: Container(
                        color: Colors.white,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: students.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            color: Colors.grey[200],
                          ),
                          itemBuilder: (context, index) {
                            final studentDoc = students[index];
                            final studentData = studentDoc.data() as Map<String, dynamic>;
                            
                            // Extract key metrics for display
                            // Defaults prevent errors if data fields are missing
                            final completedLevels = List<int>.from(
                                studentData['completedLevels'] ?? []);
                            final currentLevel = studentData['currentLevel'] ?? 1;
                            final streak = studentData['streak'] ?? 0;

                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                children: [
                                  // Avatar shows first letter of student name
                                  // Provides visual distinction between students
                                  CircleAvatar(
                                    backgroundColor: Colors.black,
                                    radius: 20,
                                    child: Text(
                                      (studentData['name'] ?? 'U')[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Student info section with name, email, and progress badges
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          studentData['name'] ?? 'Unknown',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          studentData['email'] ?? 'No email',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        // Progress indicators as colored badges
                                        // Color coding (blue=level, green=completion, orange=streak)
                                        // helps users quickly scan important metrics
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE3F2FD),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                'Level $currentLevel',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF1976D2),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFD4F4DD),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                '${completedLevels.length} completed',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF2E7D32),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Streak indicator with fire icon
                                            // Visual metaphor reinforces gamification
                                            const Icon(Icons.local_fire_department,
                                                size: 14, color: Colors.orange),
                                            Text(
                                              '$streak',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // More button opens detailed student information dialog
                                  IconButton(
                                    icon: const Icon(Icons.more_vert, color: Colors.black),
                                    onPressed: () => _showStudentDetails(
                                      studentData,
                                      studentDoc.id,
                                    ),
                                    tooltip: 'View Details',
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable widget for displaying labeled information rows in the student details dialog.
/// 
/// Provides consistent formatting for displaying key-value pairs with icons.
/// The compact two-line layout (label above value) saves vertical space
/// while maintaining readability in the dialog.
class _DetailRow extends StatelessWidget {
  /// Icon representing the type of information (email, level, streak, etc.)
  final IconData icon;
  
  /// Label describing the information (e.g., "Email", "Current Level")
  final String label;
  
  /// The actual value to display (e.g., "user@email.com", "5")
  final String value;

  const _DetailRow({
    Key? key,
    required this.icon,
    required this.label,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.black),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label in smaller, muted text
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              // Value in larger, prominent text for easy scanning
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

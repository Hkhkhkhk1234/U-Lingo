import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class StudentsManagementScreen extends StatefulWidget {
  const StudentsManagementScreen({Key? key}) : super(key: key);


  @override
  State<StudentsManagementScreen> createState() => _StudentsManagementScreenState();
}


class _StudentsManagementScreenState extends State<StudentsManagementScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();


  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }


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
              _DetailRow(
                icon: Icons.check_circle,
                label: 'Completed Levels',
                value: '${List<int>.from(studentData['completedLevels'] ?? []).length} / 10',
              ),
              const SizedBox(height: 12),
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
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFF5F5F5),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'lessons by title, number, or description...',
                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
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
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
              },
            ),
          ),


          // Students List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.black));
                }


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
                if (_searchQuery.isNotEmpty) {
                  students = students.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    final email = (data['email'] ?? '').toString().toLowerCase();
                    return name.contains(_searchQuery) || email.contains(_searchQuery);
                  }).toList();
                }


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


                return Column(
                  children: [
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
                            final completedLevels = List<int>.from(
                                studentData['completedLevels'] ?? []);
                            final currentLevel = studentData['currentLevel'] ?? 1;
                            final streak = studentData['streak'] ?? 0;


                            return Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                children: [
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


class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
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
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
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
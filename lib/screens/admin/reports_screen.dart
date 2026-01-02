import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _selectedPeriod = '7 Days';
  final List<String> _periods = ['7 Days', '30 Days', '90 Days', 'All Time'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Reports & Analytics',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: DropdownButton<String>(
                value: _selectedPeriod,
                dropdownColor: Colors.white,
                underline: const SizedBox(),
                items: _periods.map((period) {
                  return DropdownMenuItem(
                    value: period,
                    child: Text(
                      period,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedPeriod = value!);
                },
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data!.docs;

          // Calculate registration data per day
          Map<String, int> registrationsPerDay = {};
          DateTime now = DateTime.now();
          int daysToShow = _selectedPeriod == '7 Days' ? 7
              : _selectedPeriod == '30 Days' ? 30
              : _selectedPeriod == '90 Days' ? 90
              : 365;

          // Initialize days with 0
          for (int i = daysToShow - 1; i >= 0; i--) {
            final date = now.subtract(Duration(days: i));
            final dateKey = '${date.day}/${date.month}';
            registrationsPerDay[dateKey] = 0;
          }

          // Count registrations
          for (var user in users) {
            final data = user.data() as Map<String, dynamic>;
            if (data['createdAt'] != null) {
              final createdDate = (data['createdAt'] as Timestamp).toDate();
              final daysDiff = now.difference(createdDate).inDays;

              if (daysDiff <= daysToShow) {
                final dateKey = '${createdDate.day}/${createdDate.month}';
                registrationsPerDay[dateKey] = (registrationsPerDay[dateKey] ?? 0) + 1;
              }
            }
          }

          // Calculate summary statistics
          final totalRegistrations = users.length;
          final recentRegistrations = registrationsPerDay.values.reduce((a, b) => a + b);
          final avgPerDay = recentRegistrations / daysToShow;

          // Calculate active users (users with streak > 0)
          final activeUsers = users.where((user) {
            final data = user.data() as Map<String, dynamic>;
            return (data['streak'] ?? 0) > 0;
          }).length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Stats Cards
                Row(
                  children: [
                    Expanded(
                      child: _ReportCard(
                        title: 'Total Registrations',
                        value: totalRegistrations.toString(),
                        icon: Icons.people,
                        color: Colors.blue,
                        subtitle: 'All time',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _ReportCard(
                        title: 'Recent Registrations',
                        value: recentRegistrations.toString(),
                        icon: Icons.person_add,
                        color: Colors.green,
                        subtitle: _selectedPeriod,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _ReportCard(
                        title: 'Avg Per Day',
                        value: avgPerDay.toStringAsFixed(1),
                        icon: Icons.trending_up,
                        color: Colors.orange,
                        subtitle: _selectedPeriod,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _ReportCard(
                        title: 'Active Users',
                        value: activeUsers.toString(),
                        icon: Icons.local_fire_department,
                        color: Colors.red,
                        subtitle: 'With active streak',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Registration Chart
                const Text(
                  'Student Registrations Over Time',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: SizedBox(
                      height: 300,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: 1,
                            getDrawingHorizontalLine: (value) {
                              return FlLine(
                                color: Colors.grey[200],
                                strokeWidth: 1,
                              );
                            },
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    value.toInt().toString(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  );
                                },
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: daysToShow > 30 ? 10 : 1,
                                getTitlesWidget: (value, meta) {
                                  final index = value.toInt();
                                  if (index >= 0 && index < registrationsPerDay.length) {
                                    final dateKey = registrationsPerDay.keys.elementAt(index);
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        dateKey,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    );
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(
                            show: true,
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: registrationsPerDay.entries
                                  .toList()
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                return FlSpot(
                                  entry.key.toDouble(),
                                  entry.value.value.toDouble(),
                                );
                              }).toList(),
                              isCurved: true,
                              color: Colors.black,
                              barWidth: 2,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) {
                                  return FlDotCirclePainter(
                                    radius: 3,
                                    color: Colors.black,
                                    strokeWidth: 0,
                                  );
                                },
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.black.withOpacity(0.05),
                              ),
                            ),
                          ],
                          minY: 0,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Daily Registration Table
                const Text(
                  'Detailed Registration Log',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2),
                        1: FlexColumnWidth(1),
                        2: FlexColumnWidth(2),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          children: const [
                            Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                'Date',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                'Count',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                'Status',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        ...registrationsPerDay.entries.toList().reversed.take(10).map((entry) {
                          final trend = entry.value > 0 ? 'Up' : 'Stable';
                          final trendColor = entry.value > 0 ? Colors.green : Colors.grey;

                          return TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  entry.key,
                                  style: TextStyle(
                                    color: Colors.grey[800],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  entry.value.toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Icon(
                                      trend == 'Up' ? Icons.trending_up : Icons.remove,
                                      size: 16,
                                      color: trendColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      trend,
                                      style: TextStyle(
                                        color: trendColor,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
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

class _ReportCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;

  const _ReportCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 24, color: color),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_upward, color: Color(0xFF4CAF50), size: 12),
                      const SizedBox(width: 2),
                      Text(
                        '${(value.length * 2)}%',
                        style: const TextStyle(
                          color: Color(0xFF4CAF50),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
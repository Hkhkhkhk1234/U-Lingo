import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard_screen.dart';

/// Language selection screen for new and existing users.
/// 
/// Serves dual purposes:
/// 1. Initial onboarding: New users select their learning language
/// 2. Language switching: Existing users can change language preference
/// 
/// Critical data flow:
/// - Checks for existing user document before writing to Firestore
/// - Preserves existing user data (name, streak, progress) when updating language
/// - Creates complete user profile only if document doesn't exist (rare edge case)
/// 
/// Navigation context:
/// - New users: login_screen → language_selection → dashboard
/// - Existing users: profile_screen → language_selection → dashboard (returns)
class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({Key? key}) : super(key: key);

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  bool _isLoading = false;
  String? _selectedLanguage;

  /// Validates selection and updates user's language preference in Firestore.
  /// 
  /// Implements defensive programming with two scenarios:
  /// 1. Existing user: Updates only 'selectedLanguage' field to preserve
  ///    progress data (streak, levels, achievements)
  /// 2. New user (rare): Creates complete document if somehow reached this
  ///    screen without document creation in login flow
  /// 
  /// The existence check prevents accidental data loss when users change
  /// languages after making progress in another language.
  Future<void> _confirmLanguage() async {
    // Validation ensures UI provides feedback before expensive Firestore calls
    if (_selectedLanguage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a language first')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final currentUser = FirebaseAuth.instance.currentUser!;

      // Debug logging helps troubleshoot user onboarding issues
      // These logs are critical for production debugging without user interference
      print('=== LANGUAGE SELECTION ===');
      print('User ID: $userId');
      print('Selected Language: $_selectedLanguage');

      // Check document existence before write operation
      // This determines whether to create new document or update existing
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        // Edge case: User document missing despite going through login
        // This can occur if login_screen's document creation failed
        // or user accessed this screen through unusual navigation path
        print('User document does not exist, creating new one');
        final now = DateTime.now();
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'name': currentUser.displayName ?? 'Student',
          'email': currentUser.email ?? '',
          'selectedLanguage': _selectedLanguage,
          'streak': 0, // Initialize gamification metrics
          'lastAccessDate': now.toIso8601String(),
          'currentLevel': 1, // Start at beginning
          'completedLevels': [],
          'achievements': [],
          'createdAt': Timestamp.fromDate(now),
        });
        print('✅ New user document created with name: ${currentUser.displayName}');
      } else {
        // Standard path: Update only language preference
        // Using update() instead of set() prevents overwriting existing fields
        // This is critical - set() would wipe out user's streak, progress, etc.
        print('User document exists, updating language only');
        final existingData = userDoc.data() as Map<String, dynamic>;
        print('Existing name in document: ${existingData['name']}');

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({
          'selectedLanguage': _selectedLanguage,
        });
        print('✅ Language updated to: $_selectedLanguage');
      }

      // Navigate to dashboard after successful language selection
      // pushReplacement prevents back navigation to language selection
      // This enforces forward-only flow in onboarding
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } catch (e) {
      print('❌ Error in language selection: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      // Reset loading state regardless of success/failure
      // Mounted check prevents setState after navigation
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Warm peachy background maintains brand consistency
      backgroundColor: const Color(0xFFFFF5F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFF5F0),
        elevation: 0,
        // Back button enabled by default - allows users to return
        // to profile settings if changing language preference
      ),
      // Loading overlay prevents interaction during Firestore operations
      // This avoids race conditions from multiple confirm button taps
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          // Decorative elements scattered across screen
          // Positioned strategically to avoid overlapping main content
          Positioned(
            top: 20,
            left: 20,
            child: _buildApple(),
          ),
          Positioned(
            top: 40,
            right: 30,
            child: _buildStar(),
          ),
          Positioned(
            top: 10,
            right: 100,
            child: _buildApple(),
          ),
          Positioned(
            bottom: 200,
            right: 20,
            child: _buildApple(),
          ),
          Positioned(
            bottom: 250,
            left: 30,
            child: _buildStar(),
          ),
          // Cat mascot in bottom-left creates visual anchor point
          Positioned(
            bottom: 120,
            left: 20,
            child: _buildCat(),
          ),

          // Main content area with scrollable language options
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          // Engaging title with exclamation emphasizes excitement
                          const Text(
                            'Choose the language\nyou want to learn!',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF6B6B),
                              height: 1.3,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 40),
                          
                          // Language cards use radio button pattern
                          // Selection state managed locally before Firestore commit
                          _LanguageCard(
                            language: 'Mandarin',
                            flag: '🇨🇳',
                            isSelected: _selectedLanguage == 'Mandarin',
                            onTap: () => setState(() => _selectedLanguage = 'Mandarin'),
                          ),
                          const SizedBox(height: 16),
                          _LanguageCard(
                            language: 'Korean',
                            flag: '🇰🇷',
                            isSelected: _selectedLanguage == 'Korean',
                            onTap: () => setState(() => _selectedLanguage = 'Korean'),
                          ),
                          const SizedBox(height: 16),
                          _LanguageCard(
                            language: 'Malay',
                            flag: '🇲🇾',
                            isSelected: _selectedLanguage == 'Malay',
                            onTap: () => setState(() => _selectedLanguage = 'Malay'),
                          ),
                          const SizedBox(height: 16),
                          // Iban represents Sarawak's indigenous language
                          // Important for UNIMAS students given regional context
                          _LanguageCard(
                            language: 'Iban',
                            flag: '🇲🇾', // Uses Malaysian flag as Iban is indigenous to Malaysia
                            isSelected: _selectedLanguage == 'Iban',
                            onTap: () => setState(() => _selectedLanguage = 'Iban'),
                          ),
                          const SizedBox(height: 16),
                          _LanguageCard(
                            language: 'France',
                            flag: '🇫🇷',
                            isSelected: _selectedLanguage == 'France',
                            onTap: () => setState(() => _selectedLanguage = 'France'),
                          ),
                          // Extra spacing prevents last card from being hidden by confirm button
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Floating confirm button positioned above bottom navigation zone
          // Fixed positioning ensures always visible regardless of scroll position
          Positioned(
            bottom: 30,
            left: 32,
            right: 32,
            child: GestureDetector(
              onTap: _confirmLanguage,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3D4), // Light golden yellow
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: const Color(0xFF8B6914), // Dark brown border for definition
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      offset: const Offset(0, 4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Confirm!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8B6914),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Apple icon reinforces brand identity and reward theme
                    Image.asset(
                      'assets/images/apple.png',
                      width: 24,
                      height: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Small decorative apple for visual interest.
  Widget _buildApple() {
    return Image.asset(
      'assets/images/apple.png',
      width: 32,
      height: 32,
    );
  }

  /// Star decoration element.
  Widget _buildStar() {
    return Image.asset(
      'assets/images/star.png',
      width: 24,
      height: 24,
    );
  }

  /// Cat mascot with white background container.
  /// Larger size and container create focal point in lower-left corner.
  Widget _buildCat() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Image.asset(
        'assets/images/cat.png',
        width: 120,
        height: 120,
      ),
    );
  }
}

/// Interactive language selection card with flag, name, and selection state.
/// 
/// Provides clear visual feedback with:
/// - Color change when selected (lighter yellow)
/// - Check icon appears on selection
/// - Flag emoji for quick visual recognition
/// 
/// Design follows mobile UI patterns where entire card is tappable
/// rather than requiring users to hit small radio buttons.
class _LanguageCard extends StatelessWidget {
  final String language;
  final String flag;
  final bool isSelected;
  final VoidCallback? onTap;

  const _LanguageCard({
    Key? key,
    required this.language,
    required this.flag,
    required this.isSelected,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          // Visual differentiation: lighter shade when selected
          // This provides immediate feedback without requiring check icon
          color: isSelected ? const Color(0xFFFFE8B3) : const Color(0xFFFFF3D4),
          borderRadius: BorderRadius.circular(30), // Pill shape for friendly aesthetic
          border: Border.all(
            color: const Color(0xFF8B6914),
            width: 3, // Bold border creates clear card boundaries
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              offset: const Offset(0, 4),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            // Flag emoji provides instant visual recognition
            // More engaging than generic language icons
            Text(
              flag,
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                language,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3D2817), // Dark brown for readability
                ),
              ),
            ),
            // Check icon only appears when selected
            // This redundant indicator (with color change) ensures accessibility
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFF4CAF50), // Green indicates positive selection
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

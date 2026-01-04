import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'admin/admin_login_screen.dart';

/// Entry point screen for U-Lingo application.
/// 
/// Provides role-based navigation allowing users to choose between
/// Student and Admin login paths. This separation ensures appropriate
/// access control from the application's initial entry point.
class WelcomePage extends StatelessWidget {
  const WelcomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Cream background chosen to match U-Lingo's brand identity
      backgroundColor: const Color(0xFFFAF6F0),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            // Horizontal padding ensures content doesn't touch screen edges
            // Vertical padding provides breathing room on shorter screens
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Primary branding - logo image
                // Dimensions optimized for mobile screen visibility
                Image.asset(
                  'assets/logo.png',
                  width: 300,
                  height: 100,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 40),

                // Multi-colored welcome heading creates visual interest
                // Each letter in "U-LINGO" uses brand colors to reinforce
                // the playful, educational nature of the application
                RichText(
                  textAlign: TextAlign.center,
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                      letterSpacing: 0.5,
                    ),
                    children: [
                      TextSpan(
                        text: 'Welcome to\n',
                        style: TextStyle(color: Color(0xFF9BC5A2)), // Soft green
                      ),
                      // Color scheme rotates through brand palette
                      TextSpan(
                        text: 'U',
                        style: TextStyle(color: Color(0xFFEF7A7A)), // Coral red
                      ),
                      TextSpan(
                        text: '-',
                        style: TextStyle(color: Color(0xFFF5C563)), // Golden yellow
                      ),
                      TextSpan(
                        text: 'L',
                        style: TextStyle(color: Color(0xFF9BC5A2)), // Soft green
                      ),
                      TextSpan(
                        text: 'I',
                        style: TextStyle(color: Color(0xFF8BC4D6)), // Sky blue
                      ),
                      TextSpan(
                        text: 'N',
                        style: TextStyle(color: Color(0xFF9BC5A2)), // Soft green
                      ),
                      TextSpan(
                        text: 'G',
                        style: TextStyle(color: Color(0xFFEF7A7A)), // Coral red
                      ),
                      TextSpan(
                        text: 'O',
                        style: TextStyle(color: Color(0xFF9BC5A2)), // Soft green
                      ),
                      TextSpan(
                        text: '!',
                        style: TextStyle(color: Color(0xFFEF7A7A)), // Coral red
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Institution attribution for credibility and context
                const Text(
                  'by University of Malaysia Sarawak',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 50),

                // Mascot serves as friendly visual anchor and brand element
                // Large size makes screen welcoming and less intimidating
                Image.asset(
                  'assets/mascot.png',
                  width: 280,
                  height: 280,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 60),

                // Clear instruction text guides user to next action
                const Text(
                  'Select your role to continue',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF666666),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),

                // Student role button - primary user path
                // Full width and elevated style emphasizes this as main entry point
                SizedBox(
                  width: double.infinity,
                  height: 56, // Touch-friendly height for mobile
                  child: ElevatedButton(
                    onPressed: () {
                      // Navigate to standard student login
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LoginScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF4D8A8), // Warm beige maintains brand consistency
                      foregroundColor: const Color(0xFF333333),
                      elevation: 0, // Flat design for modern appearance
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28), // Pill shape for friendly aesthetic
                        side: const BorderSide(
                          color: Color(0xFF333333),
                          width: 2, // Bold border provides clear button definition
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.school, size: 24), // School icon clearly indicates student role
                        SizedBox(width: 12),
                        Text(
                          'Student',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Admin role button - secondary access path
                // Visually similar to Student button to maintain consistency
                // but positioned below to de-emphasize admin access
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: () {
                      // Navigate to separate admin authentication flow
                      // Segregated to enforce different access controls
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminLoginScreen(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFF4D8A8), // Matching background maintains visual harmony
                      foregroundColor: const Color(0xFF333333),
                      side: const BorderSide(
                        color: Color(0xFF333333),
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.admin_panel_settings, size: 24), // Admin icon clearly distinguishes role
                        SizedBox(width: 12),
                        Text(
                          'Admin',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
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

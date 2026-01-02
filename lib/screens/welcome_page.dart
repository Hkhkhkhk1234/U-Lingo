import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'admin/admin_login_screen.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F0), // Cream background
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Image.asset(
                  'assets/logo.png',
                  width: 300,
                  height: 100,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 40),

                // Welcome to U-Lingo heading with colorful text
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
                        style: TextStyle(color: Color(0xFF9BC5A2)),
                      ),
                      TextSpan(
                        text: 'U',
                        style: TextStyle(color: Color(0xFFEF7A7A)),
                      ),
                      TextSpan(
                        text: '-',
                        style: TextStyle(color: Color(0xFFF5C563)),
                      ),
                      TextSpan(
                        text: 'L',
                        style: TextStyle(color: Color(0xFF9BC5A2)),
                      ),
                      TextSpan(
                        text: 'I',
                        style: TextStyle(color: Color(0xFF8BC4D6)),
                      ),
                      TextSpan(
                        text: 'N',
                        style: TextStyle(color: Color(0xFF9BC5A2)),
                      ),
                      TextSpan(
                        text: 'G',
                        style: TextStyle(color: Color(0xFFEF7A7A)),
                      ),
                      TextSpan(
                        text: 'O',
                        style: TextStyle(color: Color(0xFF9BC5A2)),
                      ),
                      TextSpan(
                        text: '!',
                        style: TextStyle(color: Color(0xFFEF7A7A)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle
                const Text(
                  'by University of Malaysia Sarawak',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                  ),
                ),
                const SizedBox(height: 50),

                // Mascot image
                Image.asset(
                  'assets/mascot.png',
                  width: 280,
                  height: 280,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 60),

                // Role selection text
                const Text(
                  'Select your role to continue',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF666666),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),

                // Student Button (replacing Sign Up)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LoginScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF4D8A8), // Warm beige
                      foregroundColor: const Color(0xFF333333),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                        side: const BorderSide(
                          color: Color(0xFF333333),
                          width: 2,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.school, size: 24),
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

                // Admin Button (replacing Login)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminLoginScreen(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFF4D8A8), // Same beige background
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
                        Icon(Icons.admin_panel_settings, size: 24),
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
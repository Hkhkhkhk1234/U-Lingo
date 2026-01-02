import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ulingo/screens/welcome_page.dart';
import 'screens/language_selection_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/verify_email_page.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_verify_email_page.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ULingoApp());
}

class ULingoApp extends StatelessWidget {
  const ULingoApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'U-Lingo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        print('=== AUTH WRAPPER DEBUG ===');
        print('Connection state: ${snapshot.connectionState}');
        print('Has data: ${snapshot.hasData}');

        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          print('State: WAITING');
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading...'),
                ],
              ),
            ),
          );
        }

        // User is not logged in - show welcome screen
        if (!snapshot.hasData) {
          print('State: NO USER - Showing WelcomePage');
          return const WelcomePage();
        }

        final user = snapshot.data!;
        print('User ID: ${user.uid}');
        print('User Email: ${user.email}');
        print('Email Verified: ${user.emailVerified}');

        // User is logged in - determine their role and verification status
        return FutureBuilder<Map<String, dynamic>>(
          future: _getUserRoleAndStatus(user.uid),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Checking account type...'),
                    ],
                  ),
                ),
              );
            }

            if (!roleSnapshot.hasData) {
              // No role found - sign out and return to welcome
              print('ERROR: No role data found, signing out');
              FirebaseAuth.instance.signOut();
              return const WelcomePage();
            }

            final data = roleSnapshot.data!;
            final isAdmin = data['isAdmin'] as bool;
            final hasUserDoc = data['hasUserDoc'] as bool;

            print('=== ROUTING DECISION ===');
            print('Is Admin: $isAdmin');
            print('Has User Doc: $hasUserDoc');
            print('Email Verified: ${user.emailVerified}');

            // ============================================
            // ADMIN FLOW
            // ============================================
            if (isAdmin) {
              print('🔑 ADMIN FLOW DETECTED');

              // Email not verified - show admin verification page
              if (!user.emailVerified) {
                print('→ AdminVerifyEmailPage (email not verified)');
                return const AdminVerifyEmailPage();
              }

              // Email verified - show admin dashboard
              print('→ AdminDashboardScreen ✅');
              return const AdminDashboardScreen();
            }

            // ============================================
            // STUDENT FLOW
            // ============================================
            print('🎓 STUDENT FLOW DETECTED');

            // Email not verified - show student verification page
            if (!user.emailVerified) {
              print('→ VerifyEmailPage (email not verified)');
              return const VerifyEmailPage();
            }

            // Check if user document exists (student account)
            if (!hasUserDoc) {
              // Signed in but no user document - might be incomplete signup
              print('⚠️ No user document found, signing out');
              FirebaseAuth.instance.signOut();
              return const WelcomePage();
            }

            // Check email domain
            if (!user.email!.endsWith('@siswa.unimas.my')) {
              print('❌ Invalid email domain: ${user.email}');
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 80,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Invalid Email Domain',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Only UNIMAS email addresses (@siswa.unimas.my) are allowed.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                          ),
                          child: const Text('Sign Out'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            // Check if language is selected
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading profile...'),
                        ],
                      ),
                    ),
                  );
                }

                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  print('⚠️ User document disappeared, signing out');
                  FirebaseAuth.instance.signOut();
                  return const WelcomePage();
                }

                final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                final hasSelectedLanguage = userData?['selectedLanguage'] != null &&
                    userData!['selectedLanguage'].toString().isNotEmpty;

                print('Has Selected Language: $hasSelectedLanguage');
                print('Language Value: ${userData?['selectedLanguage']}');

                // Language not selected - show language selection
                if (!hasSelectedLanguage) {
                  print('→ LanguageSelectionScreen');
                  return const LanguageSelectionScreen();
                }

                // All good - show dashboard
                print('→ DashboardScreen ✅');
                return const DashboardScreen();
              },
            );
          },
        );
      },
    );
  }

  /// Determines if user is admin or student based on Firestore documents
  /// This is the KEY function that prevents cross-role access
  Future<Map<String, dynamic>> _getUserRoleAndStatus(String uid) async {
    try {
      print('📋 Checking user role for UID: $uid');

      // Check both collections in parallel for efficiency
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('admins').doc(uid).get(),
        FirebaseFirestore.instance.collection('users').doc(uid).get(),
      ]);

      final adminDoc = results[0];
      final userDoc = results[1];

      print('Admin doc exists: ${adminDoc.exists}');
      print('User doc exists: ${userDoc.exists}');

      // 🔥 CRITICAL: Admin document takes precedence
      // If admin doc exists, user is ALWAYS treated as admin
      // This prevents admins from accessing student portal
      return {
        'isAdmin': adminDoc.exists,
        'hasAdminDoc': adminDoc.exists,
        'hasUserDoc': userDoc.exists,
      };
    } catch (e) {
      print('❌ Error checking user role: $e');
      return {
        'isAdmin': false,
        'hasAdminDoc': false,
        'hasUserDoc': false,
      };
    }
  }
}
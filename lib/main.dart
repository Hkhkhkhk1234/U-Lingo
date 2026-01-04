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

/// Application entry point.
/// 
/// Initializes Firebase before running the app to ensure all Firebase services
/// (Auth, Firestore, etc.) are ready before any widgets are built.
/// ensureInitialized() is required for async operations before runApp().
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ULingoApp());
}

/// Root widget of the U-Lingo language learning application.
/// 
/// Configures app-wide theming and routes to AuthWrapper for
/// authentication-based navigation.
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

/// Authentication router that determines which screen to display based on user state.
/// 
/// Implements a sophisticated routing system that handles:
/// 1. Authentication status (logged in vs logged out)
/// 2. User role (admin vs student) with strict separation
/// 3. Email verification requirements for both roles
/// 4. Email domain validation (UNIMAS students only)
/// 5. Onboarding flow (language selection for new students)
/// 
/// CRITICAL SECURITY FEATURES:
/// - Admin document presence takes absolute precedence over user document
/// - Prevents cross-role access (admins cannot access student portal)
/// - Enforces email verification before granting access
/// - Validates institutional email domain (@siswa.unimas.my)
/// 
/// Uses nested StreamBuilder and FutureBuilder pattern for reactive auth state
/// management with Firestore role checking.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // Listen to auth state changes for automatic re-routing on login/logout
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        print('=== AUTH WRAPPER DEBUG ===');
        print('Connection state: ${snapshot.connectionState}');
        print('Has data: ${snapshot.hasData}');

        // Loading state: initial auth check
        // Shows while Firebase determines if a user session exists
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

        // No authenticated user: show welcome/login screen
        if (!snapshot.hasData) {
          print('State: NO USER - Showing WelcomePage');
          return const WelcomePage();
        }

        // User is authenticated: now determine their role and access level
        final user = snapshot.data!;
        print('User ID: ${user.uid}');
        print('User Email: ${user.email}');
        print('Email Verified: ${user.emailVerified}');

        // Check Firestore to determine if user is admin or student
        // This check is critical for security and proper role-based routing
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

            // No role data found: security measure to prevent unauthorized access
            // Signs user out and returns to welcome screen
            if (!roleSnapshot.hasData) {
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
            // Admin document presence takes absolute precedence
            // This prevents admins from accidentally accessing student features
            if (isAdmin) {
              print('🔐 ADMIN FLOW DETECTED');

              // Enforce email verification before admin dashboard access
              // Prevents unauthorized admin account creation
              if (!user.emailVerified) {
                print('→ AdminVerifyEmailPage (email not verified)');
                return const AdminVerifyEmailPage();
              }

              // Email verified: grant full admin dashboard access
              print('→ AdminDashboardScreen ✅');
              return const AdminDashboardScreen();
            }

            // ============================================
            // STUDENT FLOW
            // ============================================
            print('🎓 STUDENT FLOW DETECTED');

            // Email verification required for students too
            // Ensures valid institutional email ownership
            if (!user.emailVerified) {
              print('→ VerifyEmailPage (email not verified)');
              return const VerifyEmailPage();
            }

            // Check for user document existence
            // Missing document indicates incomplete registration or corrupted account
            if (!hasUserDoc) {
              print('⚠️ No user document found, signing out');
              FirebaseAuth.instance.signOut();
              return const WelcomePage();
            }

            // Validate institutional email domain
            // Only UNIMAS students (@siswa.unimas.my) can access student features
            // This business rule ensures the platform serves the intended institution
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

            // Check onboarding completion: language selection
            // New students must choose a language before accessing courses
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

                // User document disappeared: data integrity issue
                // Sign out to force re-authentication and proper account setup
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

                // Language selection required: incomplete onboarding
                // Prevents students from skipping this essential setup step
                if (!hasSelectedLanguage) {
                  print('→ LanguageSelectionScreen');
                  return const LanguageSelectionScreen();
                }

                // All validations passed: grant dashboard access
                print('→ DashboardScreen ✅');
                return const DashboardScreen();
              },
            );
          },
        );
      },
    );
  }

  /// Determines user role (admin vs student) by checking Firestore documents.
  /// 
  /// CRITICAL SECURITY FUNCTION:
  /// This is the single source of truth for role-based access control.
  /// 
  /// Security model:
  /// - Checks both 'admins' and 'users' collections in parallel for efficiency
  /// - Admin document presence takes ABSOLUTE precedence
  /// - If admin doc exists, user is ALWAYS treated as admin regardless of user doc
  /// - This prevents admins from accessing student features
  /// - Prevents privilege escalation attacks
  /// 
  /// Returns a map with three booleans:
  /// - isAdmin: true if admin document exists (primary routing decision)
  /// - hasAdminDoc: duplicate of isAdmin for explicit clarity
  /// - hasUserDoc: true if student document exists
  /// 
  /// Implementation note: Using Future.wait() for parallel queries reduces latency
  /// compared to sequential checks, improving user experience on authentication.
  Future<Map<String, dynamic>> _getUserRoleAndStatus(String uid) async {
    try {
      print('🔍 Checking user role for UID: $uid');

      // Parallel queries for performance
      // Both documents checked simultaneously rather than sequentially
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('admins').doc(uid).get(),
        FirebaseFirestore.instance.collection('users').doc(uid).get(),
      ]);

      final adminDoc = results[0];
      final userDoc = results[1];

      print('Admin doc exists: ${adminDoc.exists}');
      print('User doc exists: ${userDoc.exists}');

      // 🔐 CRITICAL: Admin document takes precedence
      // If admin doc exists, user is ALWAYS treated as admin
      // This prevents admins from accessing student portal even if they have a user doc
      return {
        'isAdmin': adminDoc.exists,
        'hasAdminDoc': adminDoc.exists,
        'hasUserDoc': userDoc.exists,
      };
    } catch (e) {
      // Error in role checking: fail-safe to no access
      // Prevents partial failures from granting unintended access
      print('❌ Error checking user role: $e');
      return {
        'isAdmin': false,
        'hasAdminDoc': false,
        'hasUserDoc': false,
      };
    }
  }
}

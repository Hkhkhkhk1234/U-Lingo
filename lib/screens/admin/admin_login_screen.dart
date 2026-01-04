import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin authentication screen for U-Lingo platform management.
/// 
/// Provides secure login and registration for administrators with the following features:
/// - Email domain validation (requires @siswa.unimas.my for new registrations)
/// - Email verification enforcement before granting admin access
/// - Admin role verification through Firestore to prevent unauthorized access
/// - Two-panel design: branding on left, authentication form on right
/// 
/// Security Architecture:
/// 1. Authentication via Firebase Auth
/// 2. Admin status verified in Firestore 'admins' collection
/// 3. Email verification required before access granted
/// 4. Non-admin users automatically logged out if they attempt to use admin login
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({Key? key}) : super(key: key);

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  // Form controllers for user input
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  
  // Form validation key
  final _formKey = GlobalKey<FormState>();
  
  // UI state flags
  bool _isLogin = true; // Toggle between login and signup modes
  bool _isLoading = false; // Prevents duplicate submissions during API calls

  /// Handles both login and signup authentication flows.
  /// 
  /// Login Flow:
  /// 1. Authenticates with Firebase
  /// 2. Verifies admin status in Firestore
  /// 3. Checks email verification status
  /// 4. Logs out non-admins immediately
  /// 
  /// Signup Flow:
  /// 1. Validates UNIMAS email domain
  /// 2. Creates Firebase Auth account
  /// 3. Creates admin document in Firestore BEFORE sending verification
  /// 4. Sends verification email
  /// 
  /// The order is critical: admin document must exist before verification check
  /// to prevent race conditions in AuthWrapper's admin status verification.
  Future<void> _authenticate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        // Login: Authenticate then verify admin privileges
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        // Verify that the authenticated user has admin privileges
        // This prevents regular users from accessing admin portal
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          final adminDoc = await FirebaseFirestore.instance
              .collection('admins')
              .doc(currentUser.uid)
              .get();

          if (!adminDoc.exists) {
            // User authenticated but is not an admin - revoke access immediately
            await FirebaseAuth.instance.signOut();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('This account is not registered as an admin. Please use the Student login.'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 5),
                ),
              );
            }
            setState(() => _isLoading = false);
            return;
          }

          // Admin verified - check email verification status
          // AuthWrapper will handle routing based on verification state
          if (!currentUser.emailVerified) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please verify your email first. Check your inbox.'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 4),
                ),
              );
            }
            // Keep user logged in - AuthWrapper shows verification screen
          } else {
            // Fully authenticated and verified admin
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Welcome back, Admin!'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        }
      } else {
        // Signup: Create new admin account with email domain validation
        
        // Enforce institutional email requirement for admin accounts
        // This ensures only authorized UNIMAS personnel can create admin accounts
        if (!_emailController.text.trim().endsWith('@siswa.unimas.my')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please use a UNIMAS email address (@siswa.unimas.my)'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 4),
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }

        // Create Firebase authentication account
        final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        // Set display name in Firebase Auth profile
        await userCredential.user?.updateDisplayName(_nameController.text.trim());

        // CRITICAL: Create admin document BEFORE verification email is sent
        // This prevents race conditions where AuthWrapper checks admin status
        // before the document exists, causing unexpected behavior
        await FirebaseFirestore.instance
            .collection('admins')
            .doc(userCredential.user!.uid)
            .set({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'role': 'admin', // Explicit role identifier for future role-based access control
        });

        // Send verification email to confirm email ownership
        await userCredential.user?.sendEmailVerification();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Admin account created! Please verify your email to continue.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        }

        // AuthWrapper automatically detects the authenticated user and routes
        // to the email verification screen
      }
    } on FirebaseAuthException catch (e) {
      // Provide user-friendly error messages for common authentication failures
      String message = 'Authentication failed';

      switch (e.code) {
        case 'weak-password':
          message = 'The password is too weak. Please use at least 6 characters.';
          break;
        case 'email-already-in-use':
          message = 'An account already exists with this email.';
          break;
        case 'user-not-found':
          message = 'No admin account found with this email.';
          break;
        case 'wrong-password':
          message = 'Incorrect password.';
          break;
        case 'invalid-email':
          message = 'Invalid email address.';
          break;
        case 'invalid-credential':
          message = 'Invalid email or password.';
          break;
        default:
          message = e.message ?? 'Authentication failed';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      // Catch any unexpected errors (network issues, Firestore errors, etc.)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Reset loading state after authentication attempt completes
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Row(
          children: [
            // Left Panel - Branding and visual identity
            // Creates professional first impression for admin portal
            Expanded(
              flex: 1,
              child: Container(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // U-Lingo brand logo with bold typography
                      Text(
                        'U-LINGO',
                        style: TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.w900,
                          color: Colors.grey[900],
                          letterSpacing: -2, // Tight spacing for modern look
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Badge indicating admin portal context
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Admin Portal',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Admin settings icon for visual reinforcement
                      Icon(
                        Icons.admin_panel_settings_rounded,
                        size: 120,
                        color: Colors.grey[300],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Right Panel - Authentication form
            Expanded(
              flex: 1,
              child: Container(
                color: const Color(0xFFF5F5F5),
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(48),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 450),
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        // Subtle shadow for depth and card appearance
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Form header - dynamic based on login/signup mode
                            Text(
                              _isLogin ? 'Welcome Back' : 'Create Account',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[900],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isLogin
                                  ? 'Manage U-Lingo Platform'
                                  : 'Join the admin team',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 40),

                            // UNIMAS Email Notice - shown only during signup
                            // Clearly communicates email requirement before user attempts registration
                            if (!_isLogin)
                              Container(
                                padding: const EdgeInsets.all(16),
                                margin: const EdgeInsets.only(bottom: 24),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF4E6), // Light orange background
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFFFE0B2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      color: Colors.orange[700],
                                      size: 22,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Admin accounts require UNIMAS email (@siswa.unimas.my)',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.orange[900],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Name field - only shown during signup
                            if (!_isLogin)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Admin Name',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _nameController,
                                    decoration: InputDecoration(
                                      hintText: 'Enter your name',
                                      prefixIcon: Icon(Icons.person_outline_rounded, color: Colors.grey[600]),
                                      filled: true,
                                      fillColor: const Color(0xFFF8F9FA),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey[200]!),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Colors.black, width: 2),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Colors.red),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                    ),
                                    validator: (value) =>
                                    value?.isEmpty ?? true ? 'Enter your name' : null,
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              ),

                            // Email field - label changes based on mode
                            Text(
                              _isLogin ? 'Email' : 'UNIMAS Email',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                hintText: _isLogin ? 'Enter your email' : 'admin@siswa.unimas.my',
                                prefixIcon: Icon(Icons.email_outlined, color: Colors.grey[600]),
                                filled: true,
                                fillColor: const Color(0xFFF8F9FA),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey[200]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.black, width: 2),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.red),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                              // Multi-level validation for email format and domain
                              validator: (value) {
                                if (value?.isEmpty ?? true) {
                                  return 'Enter your email';
                                }
                                if (!value!.contains('@')) {
                                  return 'Enter a valid email';
                                }
                                // Enforce UNIMAS domain during signup only
                                // Login allows any domain to support existing admin accounts
                                if (!_isLogin && !value.endsWith('@siswa.unimas.my')) {
                                  return 'Use UNIMAS email (@siswa.unimas.my)';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Password field
                            Text(
                              'Password',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true, // Hide password input for security
                              decoration: InputDecoration(
                                hintText: 'Enter your password',
                                prefixIcon: Icon(Icons.lock_outline_rounded, color: Colors.grey[600]),
                                filled: true,
                                fillColor: const Color(0xFFF8F9FA),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey[200]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.black, width: 2),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.red),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                              // Enforce Firebase's minimum password length requirement
                              validator: (value) =>
                              (value?.length ?? 0) >= 6 ? null : 'Min 6 characters',
                            ),
                            const SizedBox(height: 32),

                            // Submit button - disabled during loading to prevent duplicate submissions
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _authenticate,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  elevation: 0, // Flat design for modern aesthetic
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  disabledBackgroundColor: Colors.grey[300],
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                    : Text(
                                  _isLogin ? 'Login as Admin' : 'Sign Up as Admin',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Toggle between login and signup modes
                            Center(
                              child: TextButton(
                                onPressed: () => setState(() => _isLogin = !_isLogin),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.grey[700],
                                ),
                                child: Text(
                                  _isLogin
                                      ? 'Don\'t have an admin account? Sign Up'
                                      : 'Already have an account? Login',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Clean up text controllers to prevent memory leaks
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;
  bool _isLoading = false;

  Future<void> _authenticate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        // LOGIN - Check if user is trying to access with admin account
        print('=== STUDENT LOGIN ===');
        print('Email: ${_emailController.text.trim()}');

        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        final user = FirebaseAuth.instance.currentUser;
        print('Login successful!');
        print('User ID: ${user?.uid}');

        // 🔥 CRITICAL CHECK: Verify this is NOT an admin account
        final adminDoc = await FirebaseFirestore.instance
            .collection('admins')
            .doc(user!.uid)
            .get();

        if (adminDoc.exists) {
          // This is an admin account - reject login
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This is an admin account. Please use the Admin login.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }

        // Verify student document exists
        final studentDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!studentDoc.exists) {
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Student account not found. Please sign up first.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }

        print('✅ Valid student login');
        print('Email verified: ${user.emailVerified}');

      } else {
        // SIGNUP - Validate UNIMAS email domain
        print('=== STUDENT SIGNUP ===');
        print('Email: ${_emailController.text.trim()}');
        print('Name: ${_nameController.text.trim()}');

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

        final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        print('Account created!');
        print('User ID: ${userCredential.user?.uid}');

        // Update display name in Firebase Auth
        await userCredential.user?.updateDisplayName(_nameController.text.trim());
        print('Display name set in Auth: ${_nameController.text.trim()}');

        // Create user document with current timestamp
        final now = DateTime.now();
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'createdAt': Timestamp.fromDate(now),
          'streak': 0,
          'lastAccessDate': now.toIso8601String(),
          'currentLevel': 1,
          'completedLevels': [],
          'achievements': [],
          'role': 'student', // Add role identifier
        });

        print('✅ User document created successfully');
        print('   - Name: ${_nameController.text.trim()}');
        print('   - Email: ${_emailController.text.trim()}');
        print('   - CreatedAt: $now');

        // Send verification email
        await userCredential.user?.sendEmailVerification();
        print('Verification email sent');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created! Please verify your email to continue.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code}');
      print('Error message: ${e.message}');

      String message = 'Authentication failed';

      switch (e.code) {
        case 'weak-password':
          message = 'The password is too weak. Please use at least 6 characters.';
          break;
        case 'email-already-in-use':
          message = 'An account already exists with this email.';
          break;
        case 'user-not-found':
          message = 'No user found with this email.';
          break;
        case 'wrong-password':
          message = 'Incorrect password.';
          break;
        case 'invalid-email':
          message = 'Invalid email address.';
          break;
        case 'invalid-credential':
          message = 'Invalid email or password. Please check your credentials.';
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
      print('General Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0), // Cream background
      body: SafeArea(
        child: Stack(
          children: [
            // Background decorations
            Positioned(
              top: -20,
              left: -20,
              child: Image.asset(
                'assets/images/apple.png',
                width: 80,
                height: 80,
              ),
            ),
            Positioned(
              top: 30,
              left: 90,
              child: Image.asset(
                'assets/images/apple1.png',
                width: 60,
                height: 60,
              ),
            ),
            Positioned(
              top: 10,
              right: 30,
              child: Image.asset(
                'assets/images/apple.png',
                width: 100,
                height: 100,
              ),
            ),
            Positioned(
              top: 100,
              left: 30,
              child: Image.asset(
                'assets/images/apple2.png',
                width: 40,
                height: 40,
              ),
            ),
            Positioned(
              top: 35,
              left: MediaQuery.of(context).size.width / 2 - 15,
              child: Image.asset(
                'assets/images/star.png',
                width: 30,
                height: 30,
              ),
            ),
            Positioned(
              top: 280,
              left: 20,
              child: Image.asset(
                'assets/images/star.png',
                width: 35,
                height: 35,
              ),
            ),
            Positioned(
              bottom: 250,
              left: -10,
              child: Image.asset(
                'assets/images/apple.png',
                width: 70,
                height: 70,
              ),
            ),
            Positioned(
              bottom: 200,
              right: -15,
              child: Image.asset(
                'assets/images/apple.png',
                width: 85,
                height: 85,
              ),
            ),
            Positioned(
              bottom: 350,
              right: 30,
              child: Image.asset(
                'assets/images/apple2.png',
                width: 35,
                height: 35,
              ),
            ),
            Positioned(
              bottom: 130,
              left: 15,
              child: Image.asset(
                'assets/images/cat.png',
                width: 90,
                height: 90,
              ),
            ),
            Positioned(
              bottom: 100,
              right: 50,
              child: Image.asset(
                'assets/images/apple.png',
                width: 75,
                height: 75,
              ),
            ),
            Positioned(
              bottom: 50,
              left: MediaQuery.of(context).size.width / 2 - 20,
              child: Image.asset(
                'assets/images/star.png',
                width: 40,
                height: 40,
              ),
            ),

            // Main content
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Login/Sign Up Title
                      Text(
                        _isLogin ? 'Login' : 'Sign Up',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE17B7B),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // UNIMAS Email Notice (only for sign up)
                      if (!_isLogin)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Please use your UNIMAS email (@siswa.unimas.my)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.blue[900],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Name field (only for sign up)
                      if (!_isLogin)
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4D6),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.black, width: 2.5),
                          ),
                          child: TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                              labelStyle: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              hintText: 'Enter your full name',
                            ),
                            validator: (value) {
                              if (value?.isEmpty ?? true) {
                                return 'Enter your name';
                              }
                              if (value!.trim().length < 2) {
                                return 'Name must be at least 2 characters';
                              }
                              return null;
                            },
                          ),
                        ),
                      if (!_isLogin) const SizedBox(height: 16),

                      // Email field
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4D6),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.black, width: 2.5),
                        ),
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: _isLogin ? 'Email' : 'UNIMAS Email',
                            labelStyle: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            hintText: _isLogin ? null : 'name@siswa.unimas.my',
                          ),
                          validator: (value) {
                            if (value?.isEmpty ?? true) {
                              return 'Enter your email';
                            }
                            if (!value!.contains('@')) {
                              return 'Enter a valid email';
                            }
                            if (!_isLogin && !value.endsWith('@siswa.unimas.my')) {
                              return 'Use UNIMAS email (@siswa.unimas.my)';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password field
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4D6),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.black, width: 2.5),
                        ),
                        child: TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            labelStyle: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                          ),
                          validator: (value) =>
                          (value?.length ?? 0) >= 6 ? null : 'Min 6 characters',
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Login/Sign Up button
                      Container(
                        width: double.infinity,
                        height: 55,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.black, width: 2.5),
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _authenticate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFF4D6),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                            color: Colors.black,
                          )
                              : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _isLogin ? 'Login' : 'Sign Up',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('🎓', style: TextStyle(fontSize: 20)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Toggle between login and sign up
                      TextButton(
                        onPressed: () => setState(() => _isLogin = !_isLogin),
                        child: Text(
                          _isLogin
                              ? 'Don\'t have an account? Sign Up'
                              : 'Already have an account? Login',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
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
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }
}
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

// Integration instructions for login_screen.dart:
// 1. Add import: import 'verify_email_page.dart';
// 2. Replace signup block in _authenticate() with the commented code below
// 
// This ensures new accounts are created with email verification requirement
// and enforces UNIMAS institutional email domain validation (@siswa.unimas.my)

/*
else {
  // Validate UNIMAS email domain before account creation
  // This enforces institutional affiliation and prevents unauthorized registrations
  if (!_emailController.text.trim().endsWith('@siswa.unimas.my')) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please use a UNIMAS email address (@siswa.unimas.my)'),
          backgroundColor: Colors.red,
        ),
      );
    }
    return;
  }

  final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
    email: _emailController.text.trim(),
    password: _passwordController.text,
  );

  // Set display name immediately after account creation
  // This ensures user identity is captured before email verification
  await userCredential.user?.updateDisplayName(_nameController.text.trim());

  // Send verification email automatically
  // User cannot access app features until email is verified
  await userCredential.user?.sendEmailVerification();

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account created! Please verify your email.'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
*/

/// Email verification screen for new user accounts.
/// 
/// Enforces email verification before granting app access, which:
/// - Confirms user owns the email address (prevents typos/fake emails)
/// - Validates UNIMAS institutional affiliation
/// - Enables password recovery via verified email
/// 
/// Key features:
/// - Auto-checks verification status every 3 seconds
/// - Resend cooldown (60s) prevents email service abuse
/// - Decorative UI maintains brand consistency with welcome/login screens
/// - Multiple UX hints guide users through verification process
class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({Key? key}) : super(key: key);

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool _isEmailVerified = false;
  bool _canResendEmail = true;
  Timer? _timer;
  Timer? _resendTimer;
  int _resendCountdown = 0;

  @override
  void initState() {
    super.initState();

    // Check initial verification state
    // User might have verified in another session before returning
    _isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;

    if (!_isEmailVerified) {
      // Send initial verification email automatically
      // This ensures user receives email immediately after account creation
      _sendVerificationEmail();

      // Poll Firebase every 3 seconds to check verification status
      // This provides near-real-time feedback when user verifies via email
      // 3-second interval balances responsiveness with Firebase API rate limits
      _timer = Timer.periodic(
        const Duration(seconds: 3),
            (_) => _checkEmailVerified(),
      );
    }
  }

  @override
  void dispose() {
    // Cancel timers to prevent memory leaks and setState calls after disposal
    _timer?.cancel();
    _resendTimer?.cancel();
    super.dispose();
  }

  /// Checks current email verification status from Firebase.
  /// 
  /// Calls reload() to fetch fresh user data from server,
  /// as emailVerified status is cached locally and won't update
  /// automatically when user clicks verification link.
  Future<void> _checkEmailVerified() async {
    // Force refresh user data from Firebase server
    // Without reload(), cached emailVerified value would never update
    await FirebaseAuth.instance.currentUser?.reload();

    setState(() {
      _isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    });

    // Stop polling once verified to reduce unnecessary API calls
    if (_isEmailVerified) {
      _timer?.cancel();
      _resendTimer?.cancel();
    }
  }

  /// Sends verification email with cooldown mechanism.
  /// 
  /// Implements 60-second cooldown between sends to:
  /// - Prevent email service abuse/spam
  /// - Comply with Firebase email sending limits
  /// - Reduce server load from accidental multiple clicks
  Future<void> _sendVerificationEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      
      // Double-check user exists and needs verification
      // User might have verified in another tab/device
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();

        // Start 60-second cooldown period
        setState(() {
          _canResendEmail = false;
          _resendCountdown = 60;
        });

        // Visual countdown shows remaining wait time
        // This sets clear expectations and reduces user frustration
        _resendTimer = Timer.periodic(
          const Duration(seconds: 1),
              (timer) {
            if (_resendCountdown > 0) {
              setState(() {
                _resendCountdown--;
              });
            } else {
              // Re-enable resend button after cooldown expires
              setState(() {
                _canResendEmail = true;
              });
              timer.cancel();
            }
          },
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verification email sent! Please check your inbox.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending verification email: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Signs out current user and returns to login screen.
  /// 
  /// Allows users to switch accounts if they registered with wrong email
  /// or need to use a different UNIMAS email address.
  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';

    return Scaffold(
      // Cream background maintains visual consistency with app theme
      backgroundColor: const Color(0xFFFAF3E0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF3E0),
        elevation: 0,
        title: const Text(
          'Verify Email',
          style: TextStyle(color: Color(0xFFE07A5F)),
        ),
        // Disable back button - user must verify or sign out
        // This prevents bypassing email verification requirement
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFFE07A5F)),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Decorative elements positioned across screen
          // These create visual interest and maintain brand identity
          // Positioned outside viewport bounds create "peek-in" effect
          Positioned(top: -30, left: -30, child: _buildApple(60)),
          Positioned(top: 10, left: 60, child: _buildSmallApple(40)),
          Positioned(top: 20, right: -20, child: _buildApple(80)),
          Positioned(top: 100, left: 20, child: _buildStar(24)),
          Positioned(bottom: 200, left: -20, child: _buildApple(70)),
          Positioned(bottom: 300, right: 10, child: _buildSmallApple(50)),
          Positioned(bottom: 150, right: -30, child: _buildApple(90)),
          Positioned(bottom: 400, left: 30, child: _buildStar(20)),
          Positioned(bottom: 500, right: 40, child: _buildStar(16)),

          // Cat mascot adds friendly, approachable feel
          // Bottom-left placement balances decorative elements
          Positioned(
            bottom: 20,
            left: 20,
            child: _buildCat(),
          ),

          // Main content scrollable to accommodate various screen sizes
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),

                    // Star decoration serves as attention anchor
                    Image.asset(
                      'assets/images/star.png',
                      width: 32,
                      height: 32,
                      fit: BoxFit.contain,
                    ),

                    const SizedBox(height: 16),

                    // Dynamic title changes based on verification state
                    // This provides immediate visual feedback of success
                    Text(
                      _isEmailVerified ? 'Your Email\nhas been verified!' : 'Verify Your Email',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE07A5F),
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 32),

                    // Visual feedback changes dramatically on verification
                    // Green checkmark provides clear success indicator
                    if (_isEmailVerified)
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          color: const Color(0xFF81B29A), // Success green
                          borderRadius: BorderRadius.circular(70),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 80,
                          color: Colors.white,
                        ),
                      )
                    else
                      // Email icon indicates pending verification state
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE07A5F).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.email_outlined,
                          size: 80,
                          color: Color(0xFFE07A5F),
                        ),
                      ),

                    const SizedBox(height: 32),

                    // Display email address for confirmation
                    // Users can verify they're checking the correct inbox
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE07A5F).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.email, size: 20, color: Color(0xFFE07A5F)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              email,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF3D405B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Context-aware description guides next steps
                    Text(
                      _isEmailVerified
                          ? 'Your email has been successfully verified. You can now continue to the app.'
                          : 'A verification email has been sent to your email address. Please check your inbox and click the verification link.',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF3D405B),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 32),

                    // Warning for non-UNIMAS emails
                    // This catches edge cases where email validation was bypassed
                    // or user account was created through different flow
                    if (!email.endsWith('@siswa.unimas.my'))
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4A261).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF4A261)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber, color: Color(0xFFE07A5F), size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Please use a UNIMAS email (@siswa.unimas.my) for verification.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: const Color(0xFFE07A5F).withOpacity(0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Show action buttons based on verification state
                    if (!_isEmailVerified) ...[
                      // Resend button with visual countdown feedback
                      // Disabled state with timer prevents spam and sets expectations
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _canResendEmail ? _sendVerificationEmail : null,
                          icon: Icon(
                            _canResendEmail ? Icons.refresh : Icons.timer,
                          ),
                          label: Text(
                            _canResendEmail
                                ? 'Resend Verification Email'
                                : 'Resend in $_resendCountdown seconds',
                            style: const TextStyle(fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _canResendEmail ? const Color(0xFFE07A5F) : Colors.grey,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Manual status check for impatient users
                      // Provides control when auto-polling feels too slow
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _checkEmailVerified,
                          icon: const Icon(Icons.refresh),
                          label: const Text(
                            'I\'ve Verified, Check Status',
                            style: TextStyle(fontSize: 16),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFE07A5F),
                            side: const BorderSide(color: Color(0xFFE07A5F), width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      // Success state button - triggers state rebuild
                      // Actual navigation handled by AuthWrapper based on verification status
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Trigger rebuild to update AuthWrapper's stream
                            // This causes app to re-evaluate auth state and navigate accordingly
                            setState(() {});
                          },
                          icon: const Icon(Icons.check_circle),
                          label: const Text(
                            'Continue to App',
                            style: TextStyle(fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF81B29A), // Success green
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Educational tips reduce support burden
                    // Addresses common issues users face during email verification
                    if (!_isEmailVerified)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE07A5F).withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.lightbulb_outline, color: const Color(0xFFE07A5F), size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'Tips:',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF3D405B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Each tip addresses common user pain points
                            _buildTip('Check your spam/junk folder if you don\'t see the email'),
                            _buildTip('Make sure you\'re checking the correct email address'),
                            _buildTip('The verification link expires after 24 hours'),
                            _buildTip('Click "Resend" if you need a new verification email'),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Alternative sign-out path for wrong email scenarios
                    TextButton(
                      onPressed: _signOut,
                      child: const Text(
                        'Sign out and use a different account',
                        style: TextStyle(fontSize: 14, color: Color(0xFFE07A5F)),
                      ),
                    ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a single tip item with bullet point styling.
  /// 
  /// Circular bullet maintains visual consistency with app's
  /// rounded, friendly design language.
  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Custom bullet point matches brand color
          Container(
            margin: const EdgeInsets.only(top: 6), // Vertical alignment with text
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFFE07A5F),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF3D405B),
                height: 1.4, // Line height for readability
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Decorative apple image - large variant.
  Widget _buildApple(double size) {
    return Image.asset(
      'assets/images/apple.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }

  /// Decorative apple image - small variant.
  Widget _buildSmallApple(double size) {
    return Image.asset(
      'assets/images/apple1.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }

  /// Decorative star/apple variant.
  /// Asset naming (apple2.png) suggests visual theme consistency.
  Widget _buildStar(double size) {
    return Image.asset(
      'assets/images/apple2.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }

  /// Cat mascot illustration for brand personality.
  Widget _buildCat() {
    return Image.asset(
      'assets/images/cat.png',
      width: 80,
      height: 100,
      fit: BoxFit.contain,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

/// Email verification screen for admin accounts.
/// 
/// This intermediate screen appears after admin signup and prevents access to the
/// admin dashboard until email verification is completed. Features include:
/// - Automatic polling to detect when email is verified (every 3 seconds)
/// - Rate-limited resend functionality with 60-second cooldown
/// - Manual verification check button for immediate feedback
/// - Helpful tips for finding verification emails
/// - Sign out option to switch accounts
/// 
/// Design Philosophy:
/// The automatic polling provides a seamless UX where users can verify their email
/// in another tab/app, then return to see automatic progression without manual refresh.
/// The resend cooldown prevents email server abuse and spam complaints.
class AdminVerifyEmailPage extends StatefulWidget {
  const AdminVerifyEmailPage({Key? key}) : super(key: key);

  @override
  State<AdminVerifyEmailPage> createState() => _AdminVerifyEmailPageState();
}

class _AdminVerifyEmailPageState extends State<AdminVerifyEmailPage> {
  // Tracks current email verification status from Firebase
  bool _isEmailVerified = false;
  
  // Controls whether resend button is enabled (enforces 60-second cooldown)
  bool _canResendEmail = true;
  
  // Timer for automatic verification status polling
  Timer? _timer;
  
  // Timer for resend button cooldown countdown
  Timer? _resendTimer;
  
  // Countdown seconds remaining before resend is allowed
  int _resendCountdown = 0;

  @override
  void initState() {
    super.initState();

    // Check initial verification status
    _isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;

    // Only start monitoring if email is not yet verified
    // This prevents unnecessary polling for already-verified users
    if (!_isEmailVerified) {
      _sendVerificationEmail();
      
      // Poll Firebase every 3 seconds to check if email has been verified
      // This frequency balances responsiveness with Firebase API rate limits
      _timer = Timer.periodic(
        const Duration(seconds: 3),
            (_) => _checkEmailVerified(),
      );
    }
  }

  @override
  void dispose() {
    // Cancel all timers to prevent memory leaks and unnecessary API calls
    _timer?.cancel();
    _resendTimer?.cancel();
    super.dispose();
  }

  /// Checks current email verification status by reloading user data from Firebase.
  /// 
  /// This method is called both automatically (via timer) and manually (via button press).
  /// If verification is detected, all timers are cancelled to stop unnecessary polling.
  /// 
  /// Note: Firebase Auth caches user data, so reload() must be called to get
  /// the latest verification status from the server.
  Future<void> _checkEmailVerified() async {
    // Reload user data from Firebase server to get latest verification status
    await FirebaseAuth.instance.currentUser?.reload();

    setState(() {
      _isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    });

    // Once verified, stop all polling and countdown timers
    if (_isEmailVerified) {
      _timer?.cancel();
      _resendTimer?.cancel();
    }
  }

  /// Sends a verification email to the admin user's email address.
  /// 
  /// Implements rate limiting with a 60-second cooldown to:
  /// - Prevent abuse and spam complaints
  /// - Avoid overwhelming the email server
  /// - Comply with email service provider rate limits
  /// 
  /// The countdown provides visual feedback about when resend will be available.
  Future<void> _sendVerificationEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      
      // Double-check that user exists and isn't already verified
      // This prevents sending unnecessary emails
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();

        // Start 60-second cooldown period
        setState(() {
          _canResendEmail = false;
          _resendCountdown = 60;
        });

        // Countdown timer updates UI every second
        _resendTimer = Timer.periodic(
          const Duration(seconds: 1),
              (timer) {
            if (_resendCountdown > 0) {
              setState(() {
                _resendCountdown--;
              });
            } else {
              // Cooldown complete - re-enable resend button
              setState(() {
                _canResendEmail = true;
              });
              timer.cancel();
            }
          },
        );

        // Provide user feedback that email was sent successfully
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
      // Handle errors gracefully (network issues, Firebase errors, etc.)
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

  /// Signs the user out and returns to the login screen.
  /// 
  /// Useful when users accidentally signed up with the wrong email
  /// or need to switch to a different admin account.
  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    // AuthWrapper will automatically detect the signed-out state
    // and navigate to the login screen
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Verify Admin Email'),
        backgroundColor: Colors.orange,
        // Prevent back navigation to force email verification
        // Users must verify or sign out - no way to bypass this step
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Visual status indicator - changes icon and color based on verification state
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isEmailVerified ? Icons.mark_email_read : Icons.email_outlined,
                    size: 80,
                    color: _isEmailVerified ? Colors.green : Colors.orange,
                  ),
                ),

                const SizedBox(height: 32),

                // Dynamic heading based on verification status
                Text(
                  _isEmailVerified ? 'Email Verified!' : 'Verify Your Admin Email',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                // Display the admin email being verified
                // Helps users confirm they're verifying the correct account
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.admin_panel_settings, size: 20, color: Colors.orange),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          email,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Context-sensitive instructions that change based on verification status
                Text(
                  _isEmailVerified
                      ? 'Your admin email has been successfully verified. You can now access the admin dashboard.'
                      : 'A verification email has been sent to your admin email address. Please check your inbox and click the verification link to activate your admin account.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // Action buttons - different options shown based on verification state
                if (!_isEmailVerified) ...[
                  // Resend button with cooldown timer
                  // Button disabled during cooldown to enforce rate limiting
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _canResendEmail ? _sendVerificationEmail : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _canResendEmail ? Colors.orange : Colors.grey,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(
                        _canResendEmail ? Icons.refresh : Icons.timer,
                      ),
                      label: Text(
                        _canResendEmail
                            ? 'Resend Verification Email'
                            : 'Resend in $_resendCountdown seconds',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Manual check button for users who verified in another tab
                  // Provides immediate feedback instead of waiting for auto-polling
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
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // Success state button - triggers rebuild to let AuthWrapper
                  // detect verification and navigate to admin dashboard
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Force rebuild to trigger AuthWrapper navigation
                        setState(() {});
                      },
                      icon: const Icon(Icons.check_circle),
                      label: const Text(
                        'Continue to Admin Dashboard',
                        style: TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Helpful tips section - only shown when verification is pending
                // Addresses common issues users face with email verification
                if (!_isEmailVerified)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lightbulb_outline, color: Colors.orange[700], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Tips:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[900],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Common troubleshooting steps for missing verification emails
                        _buildTip('Check your spam/junk folder'),
                        _buildTip('Ensure you\'re checking the correct email'),
                        _buildTip('Verification link expires after 24 hours'),
                        _buildTip('Contact IT support if issues persist'),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // Secondary sign out option for users who want to switch accounts
                TextButton(
                  onPressed: _signOut,
                  child: const Text(
                    'Sign out and use a different account',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds a single tip item with bullet point styling.
  /// 
  /// Used in the tips section to display troubleshooting advice
  /// in a consistent, easy-to-read format.
  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Custom bullet point using a small circular container
          // Provides better visual consistency than default list markers
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.orange[700],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.orange[900],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

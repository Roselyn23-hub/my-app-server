import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/database_helper.dart';
import '../services/push_service.dart';
import 'admin/admin_dashboard.dart';
import 'faculty/faculty_dashboard.dart';
import 'staff/staff_dashboard.dart';

// Brand palette pulled from the university seal.
class AppColors {
  static const maroon = Color(0xFFA6192E);
  static const maroonDark = Color(0xFF7A1222);
  static const gold = Color(0xFFFDB913);
  static const cream = Color(0xFFFFF8E7);
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();

      final AppUser? user =
          await DatabaseHelper.instance.login(username, password);

      if (user == null) {
        setState(() => _errorMessage = 'Invalid username or password.');
        return;
      }

      if (!mounted) return;

      // Save this device's FCM token against the account so push
      // notifications know where to deliver. Doesn't block navigation if
      // it fails (e.g. no notification permission yet).
      unawaited(PushService.instance.registerTokenForUser(user.username));

      // Route to the correct dashboard based on the user's role
      Widget destination;
      switch (user.role) {
        case 'admin':
          destination = AdminDashboard(user: user);
          break;
        case 'faculty':
          destination = FacultyDashboard(user: user);
          break;
        case 'staff':
          destination = StaffDashboard(user: user);
          break;
        default:
          setState(() => _errorMessage = 'Unknown role: ${user.role}');
          return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => destination),
      );
    } catch (e) {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Campus photo background
          Image.asset(
            'assets/images/campus_bg.png',
            fit: BoxFit.cover,
          ),
          // Subtle dark wash — since the photo itself is light, a dark wash
          // (instead of a white one) gives text and cards more contrast.
          Container(
            color: Colors.black.withOpacity(0.15),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Seal / logo
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(10),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/icon.png', // rename your file to logo.png if it's currently logo.jpg
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.school,
                              color: AppColors.maroon,
                              size: 44,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Title block — solid maroon pill behind the text so it
                      // stays readable regardless of how light the photo is.
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.maroonDark.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'weTrack',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.gold,
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Document Tracking System',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Login card
                      Container(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.92),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          border: Border.all(
                            color: AppColors.gold.withOpacity(0.6),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _usernameController,
                              textCapitalization: TextCapitalization.none,
                              autocorrect: false,
                              style: const TextStyle(color: AppColors.maroonDark),
                              decoration: _fieldDecoration(
                                label: 'Username',
                                icon: Icons.person_outline,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(color: AppColors.maroonDark),
                              decoration: _fieldDecoration(
                                label: 'Password',
                                icon: Icons.lock_outline,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: AppColors.maroon,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            if (_errorMessage != null)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 12,
                                ),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.error_outline,
                                        color: Colors.red.shade700, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _signIn,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.maroon,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 3,
                                ).copyWith(
                                  overlayColor: WidgetStateProperty.all(
                                    AppColors.gold.withOpacity(0.15),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Text(
                                        'LOG IN',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '© ${DateTime.now().year} weTrack — All rights reserved',
                          style: TextStyle(
                            color: AppColors.maroonDark.withOpacity(0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.maroon),
      prefixIcon: Icon(icon, color: AppColors.maroon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.gold.withOpacity(0.4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.maroon, width: 1.6),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/zego_call_service.dart';
import '../dashboard/patient_dashboard.dart';
import '../dashboard/doctor_dashboard.dart';
import '../dashboard/admin_dashboard.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _handleLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (res.user == null) throw Exception('Login failed');

      // Fetch user role & name
      final profile = await Supabase.instance.client
          .from('users')
          .select('role, name')
          .eq('uid', res.user!.id)
          .single();

      if (!mounted) return;

      final role = profile['role'] as String?;
      final userName = profile['name'] as String? ?? 'User';

      // Initialize Zego Call Service for background call support
      if (role != 'admin') {
        ZegoCallService.instance.init(
          context: context,
          userId: res.user!.id,
          userName: role == 'doctor' ? 'Dr. $userName' : userName,
        );
      }

      Widget destination;
      if (role == 'admin') {
        destination = const AdminDashboard();
      } else if (role == 'doctor') {
        destination = const DoctorDashboard();
      } else {
        destination = const PatientDashboard();
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => destination),
        (_) => false,
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(90),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.medical_services_rounded, size: 28, color: Colors.white),
                ),
                const SizedBox(height: 20),
                Text('Welcome Back', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text(
                  'Sign in to your AarogyaPlus account',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),

                if (_error != null) ErrorBanner(message: _error!),

                PremiumTextField(
                  label: 'Email Address',
                  hint: 'you@example.com',
                  prefixIcon: Icons.email_outlined,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                ),
                PremiumTextField(
                  label: 'Password',
                  hint: '••••••••',
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                  controller: _passwordController,
                ),

                const SizedBox(height: 8),
                PrimaryButton(
                  text: 'Sign In',
                  icon: Icons.arrow_forward,
                  isLoading: _loading,
                  onPressed: _handleLogin,
                ),

                const SizedBox(height: 28),
                // Divider
                Container(
                  height: 1,
                  color: Theme.of(context).dividerColor.withAlpha(40),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RegisterScreen()),
                        );
                      },
                      child: Text(
                        'Register now',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

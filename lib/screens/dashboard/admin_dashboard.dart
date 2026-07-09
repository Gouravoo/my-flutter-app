import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../widgets/common_widgets.dart';
import '../auth/login_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  final _searchController = TextEditingController();
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
        }
        return;
      }

      final profileData = await _supabase.from('users').select('*').eq('uid', user.id).single();
      if (profileData['role'] != 'admin') {
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
        return;
      }

      final usersData = await _supabase.from('users').select('*').order('createdAt', ascending: false);

      if (mounted) {
        setState(() {
          _profile = profileData;
          _users = List<Map<String, dynamic>>.from(usersData);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleLogout() async {
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  Future<void> _toggleStatus(String uid, bool currentActive) async {
    try {
      await _supabase.from('users').update({'isActive': !currentActive}).eq('uid', uid);
      await _fetchData();
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchTerm.isEmpty) return _users;
    return _users.where((u) {
      final name = (u['name'] ?? '').toString().toLowerCase();
      final email = (u['email'] ?? '').toString().toLowerCase();
      final role = (u['role'] ?? '').toString().toLowerCase();
      final term = _searchTerm.toLowerCase();
      return name.contains(term) || email.contains(term) || role.contains(term);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }

    final total = _users.length;
    final patients = _users.where((u) => u['role'] == 'patient').length;
    final doctors = _users.where((u) => u['role'] == 'doctor').length;
    final active = _users.where((u) => u['isActive'] != false).length;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.adminGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF7E22CE).withAlpha(60), blurRadius: 32, offset: const Offset(0, 8)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(50),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.shield, size: 24, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Admin Control Panel',
                              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                          Text('System overview and management',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _handleLogout,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(40),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withAlpha(60)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.logout, size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            Text('Logout', style: GoogleFonts.inter(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Stats
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.0,
                children: [
                  _statCard('Total Users', '$total', AppColors.primary),
                  _statCard('Active Patients', '$patients', AppColors.secondary),
                  _statCard('Registered Doctors', '$doctors', AppColors.accent),
                  _statCard('Active Accounts', '$active', const Color(0xFF8B5CF6)),
                ],
              ),

              const SizedBox(height: 24),

              // Search
              Row(
                children: [
                  const Icon(Icons.people, size: 20, color: Color(0xFF7E22CE)),
                  const SizedBox(width: 8),
                  Text('User Directory', style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchTerm = v),
                decoration: InputDecoration(
                  hintText: 'Search users...',
                  prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),

              // User list
              ..._filteredUsers.map((user) => GlassCard(
                    child: Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                          child: Center(
                            child: Text(
                              (user['name'] ?? 'U').toString().substring(0, 1).toUpperCase(),
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user['name'] ?? 'Unknown', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                              Text(user['email'] ?? '', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _roleBadge(user['role'] ?? 'unknown'),
                            const SizedBox(height: 4),
                            if (user['uid'] != _profile?['uid'])
                              GestureDetector(
                                onTap: () => _toggleStatus(user['uid'], user['isActive'] != false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (user['isActive'] != false) ? AppColors.dangerLight : AppColors.secondaryLight,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: (user['isActive'] != false) ? AppColors.danger.withAlpha(50) : AppColors.secondary.withAlpha(50)),
                                  ),
                                  child: Text(
                                    (user['isActive'] != false) ? 'Suspend' : 'Activate',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: (user['isActive'] != false) ? AppColors.danger : AppColors.secondary,
                                    ),
                                  ),
                                ),
                              )
                            else
                              Text('Current User', style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label.toUpperCase(),
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.5)),
        ],
      ),
    );
  }

  Widget _roleBadge(String role) {
    Color color;
    if (role == 'admin') {
      color = const Color(0xFF7E22CE);
    } else if (role == 'doctor') {
      color = AppColors.primary;
    } else {
      color = AppColors.secondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Text(role, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

import 'dart:async';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import '../../core/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/zego_call_service.dart';
import '../auth/login_screen.dart';

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _appointments = [];
  bool _loading = true;
  int _activeTab = 0;
  StreamSubscription? _appointmentSubscription;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _listenForNewAppointments();
  }

  @override
  void dispose() {
    _appointmentSubscription?.cancel();
    super.dispose();
  }

  /// Listen for realtime changes in appointments table so new bookings appear instantly
  void _listenForNewAppointments() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _appointmentSubscription = _supabase
        .from('appointments')
        .stream(primaryKey: ['id'])
        .eq('doctorId', user.id)
        .listen((data) {
          if (mounted) {
            setState(() {
              _appointments = List<Map<String, dynamic>>.from(data);
              // Sort by date descending
              _appointments.sort((a, b) => (b['date'] ?? '').compareTo(a['date'] ?? ''));
            });
          }
        });
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
      final appointmentsData = await _supabase
          .from('appointments')
          .select('*')
          .eq('doctorId', user.id)
          .order('date', ascending: false);

      if (mounted) {
        setState(() {
          _profile = profileData;
          _appointments = List<Map<String, dynamic>>.from(appointmentsData);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleLogout() async {
    await ZegoCallService.instance.uninit();
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  Future<void> _markCompleted(String id) async {
    try {
      await _supabase.from('appointments').update({'status': 'completed'}).eq('id', id);
      await _fetchData();
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void _openPrescriptionSheet(Map<String, dynamic> apt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DoctorPrescriptionSheet(
        appointment: apt,
        onSaved: () {
          Navigator.pop(ctx);
          _fetchData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.secondary)));
    }

    final scheduledCount = _appointments.where((a) => a['status'] == 'scheduled').length;
    final completedCount = _appointments.where((a) => a['status'] == 'completed').length;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            Column(
              children: [
                // Header with logo
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withAlpha(220),
                    border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withAlpha(30))),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset('assets/app_icon.png', width: 36, height: 36, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dr. ${_profile?['name']?.toString().split(' ')[0] ?? 'Doctor'}',
                              style: Theme.of(context).textTheme.titleLarge),
                          Text('Ready for consultation?', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _handleLogout,
                        child: Container(
                          width: 36, height: 36,
                          decoration: const BoxDecoration(color: AppColors.dangerLight, shape: BoxShape.circle),
                          child: const Icon(Icons.logout, size: 16, color: AppColors.danger),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: IndexedStack(
                    index: _activeTab,
                    children: [
                      _buildHome(scheduledCount, completedCount),
                      _buildSchedule(),
                      _buildProfile(),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withAlpha(30))),
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: _activeTab,
            onTap: (i) => setState(() => _activeTab = i),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Overview'),
              BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Schedule'),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHome(int scheduledCount, int completedCount) {
    final scheduled = _appointments.where((a) => a['status'] == 'scheduled').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Overview', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),

          // Stats
          Row(
            children: [
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8, height: 8,
                            decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text('SCHEDULED', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.5)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('$scheduledCount', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
                          const SizedBox(width: 8),
                          const Icon(Icons.access_time, size: 16, color: AppColors.accent),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8, height: 8,
                            decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text('COMPLETED', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.5)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('$completedCount', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
                          const SizedBox(width: 8),
                          const Icon(Icons.check_circle, size: 16, color: AppColors.secondary),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Next patient
          if (scheduled.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Next Patient', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.secondaryGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: AppColors.secondary.withAlpha(100), blurRadius: 32, offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${scheduled[0]['date']} â€¢ ${scheduled[0]['time']}',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(50),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('Upcoming', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    scheduled[0]['patientName'] ?? 'Patient #${scheduled[0]['patientId'].toString().substring(0, 6)}',
                    style: GoogleFonts.outfit(fontSize: 19, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Age: ${scheduled[0]['patientAge'] ?? 'N/A'} â€¢ ${scheduled[0]['patientPhone'] ?? 'No Phone'}',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final targetUserId = scheduled[0]['patientId'].toString().replaceAll('-', '');
                        ZegoUIKitPrebuiltCallInvitationService().send(
                          invitees: [ZegoCallUser(targetUserId, scheduled[0]['patientName'] ?? 'Patient')],
                          isVideoCall: true,
                          customData: scheduled[0]['id'].toString(),
                        );
                      },
                      icon: const Icon(Icons.videocam, size: 16),
                      label: const Text('Start Call'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.secondary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSchedule() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('All Schedule', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          if (_appointments.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.calendar_today, size: 40, color: AppColors.textLight.withAlpha(80)),
                    const SizedBox(height: 12),
                    Text('No appointments yet', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            )
          else
            ..._appointments.map((apt) => GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32, height: 32,
                            decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                            child: Center(
                              child: Text(
                                (apt['patientName'] ?? 'P').toString().substring(0, 1).toUpperCase(),
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(apt['patientName'] ?? 'Patient #${apt['patientId'].toString().substring(0, 8)}',
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
                                Text(apt['patientPhone'] ?? 'No Phone',
                                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                          StatusBadge(
                            text: apt['status'],
                            color: apt['status'] == 'scheduled' ? const Color(0xFFB45309) : AppColors.secondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, size: 14, color: AppColors.textMuted),
                            const SizedBox(width: 6),
                            Text('${apt['date']} at ${apt['time']}',
                                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (apt['status'] == 'scheduled')
                        Row(
                          children: [
                            Expanded(
                              child: PrimaryButton(
                                text: 'Call',
                                icon: Icons.videocam,
                                onPressed: () {
                                  final targetUserId = apt['patientId'].toString().replaceAll('-', '');
                                  ZegoUIKitPrebuiltCallInvitationService().send(
                                    invitees: [ZegoCallUser(targetUserId, apt['patientName'] ?? 'Patient')],
                                    isVideoCall: true,
                                    customData: apt['id'].toString(),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SecondaryButton(
                                text: 'Done',
                                icon: Icons.check_circle,
                                color: AppColors.secondary,
                                onPressed: () => _markCompleted(apt['id'].toString()),
                              ),
                            ),
                          ],
                        ),
                      if (apt['status'] == 'completed')
                        PrimaryButton(
                          text: apt['prescription'] != null ? 'Edit Prescription' : 'Write Prescription',
                          icon: Icons.description,
                          onPressed: () => _openPrescriptionSheet(apt),
                        ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildProfile() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Profile', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                  child: Center(
                    child: Text('D', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Dr. ${_profile?['name'] ?? 'Doctor'}', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(_profile?['email'] ?? '', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _handleLogout,
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text('Log Out'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.dangerLight,
                      foregroundColor: AppColors.danger,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===== Doctor Prescription Bottom Sheet =====
class _DoctorPrescriptionSheet extends StatefulWidget {
  final Map<String, dynamic> appointment;
  final VoidCallback onSaved;

  const _DoctorPrescriptionSheet({required this.appointment, required this.onSaved});

  @override
  State<_DoctorPrescriptionSheet> createState() => _DoctorPrescriptionSheetState();
}

class _DoctorPrescriptionSheetState extends State<_DoctorPrescriptionSheet> {
  final _supabase = Supabase.instance.client;
  final _notesController = TextEditingController();
  File? _imageFile;
  bool _loading = false;
  String? _existingImageUrl;

  @override
  void initState() {
    super.initState();
    _notesController.text = widget.appointment['prescription'] ?? '';
    _existingImageUrl = widget.appointment['prescriptionUrl'];
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 70);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
        _existingImageUrl = null;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      String? imageUrl = _existingImageUrl;

      if (_imageFile != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${widget.appointment['id']}.jpg';
        await _supabase.storage.from('prescriptions').upload(fileName, _imageFile!);
        imageUrl = _supabase.storage.from('prescriptions').getPublicUrl(fileName);
      }

      await _supabase.from('appointments').update({
        'prescription': _notesController.text,
        'prescriptionUrl': imageUrl,
      }).eq('id', widget.appointment['id']);

      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prescription saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _shareViaWhatsApp() async {
    final phone = widget.appointment['patientPhone']?.toString() ?? '';
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No patient phone number available.')));
      return;
    }

    String msg = 'Hello ${widget.appointment['patientName']},\n\nThis is Dr. Santosh.\nHere is your prescription notes:\n\n${_notesController.text}';
    
    // Include photo URL if exists
    if (_existingImageUrl != null) {
      msg += '\n\nPrescription Photo: $_existingImageUrl';
    } else if (_imageFile != null) {
      msg += '\n\n(Please save this prescription first to share the uploaded photo link)';
    }

    msg += '\n\nThank you,\nAarogyaPlus';

    // Format phone number to include country code if missing
    String whatsappPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (!whatsappPhone.startsWith('91') && whatsappPhone.length == 10) {
      whatsappPhone = '91$whatsappPhone';
    }

    final url = Uri.parse('whatsapp://send?phone=$whatsappPhone&text=${Uri.encodeComponent(msg)}');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        // Fallback to share dialog
        await SharePlus.instance.share(ShareParams(text: msg));
      }
    } catch (e) {
      // Fallback to share dialog
      await SharePlus.instance.share(ShareParams(text: msg));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(80), blurRadius: 40, offset: const Offset(0, -10))],
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(color: AppColors.textLight.withAlpha(128), borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Prescription', style: Theme.of(context).textTheme.headlineSmall),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.black.withAlpha(10), shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt, size: 18),
                    label: const Text('Camera'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library, size: 18),
                    label: const Text('Gallery'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_imageFile != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_imageFile!, height: 150, width: double.infinity, fit: BoxFit.cover),
              )
            else if (_existingImageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(_existingImageUrl!, height: 150, width: double.infinity, fit: BoxFit.cover),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Type prescription notes, medicines, dosage...',
                labelText: 'Clinical Notes',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    text: 'Save',
                    icon: Icons.save,
                    isLoading: _loading,
                    onPressed: _save,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _shareViaWhatsApp,
                    icon: const Icon(Icons.chat),
                    label: const Text('WhatsApp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}



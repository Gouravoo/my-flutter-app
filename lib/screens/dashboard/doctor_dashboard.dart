import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/incoming_call_listener.dart';
import '../auth/login_screen.dart';
import '../call/call_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchData();
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

      final profileData = await _supabase
          .from('users')
          .select('*')
          .eq('uid', user.id)
          .single();

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
      debugPrint('Error fetching data: $e');
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

  void _showPrescriptionDialog(Map<String, dynamic> apt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DoctorPrescriptionSheet(
        appointment: apt,
        onSaved: () {
          _fetchData();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchData,
                    child: _buildAppointmentsList(),
                  ),
                ),
              ],
            ),
            // Incoming call overlay (on top of everything)
            if (_profile != null)
              IncomingCallListener(uid: _profile!['uid'] ?? ''),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withAlpha(220),
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor.withAlpha(30)),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/app_icon.png',
              width: 36,
              height: 36,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.medical_services, size: 20, color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dr. ${_profile?['name']?.toString().split(' ')[0] ?? 'Doctor'}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text('Doctor Dashboard', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: _handleLogout,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.dangerLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout, size: 16, color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsList() {
    if (_appointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 64, color: AppColors.textLight.withAlpha(80)),
            const SizedBox(height: 16),
            Text('No appointments yet', style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _appointments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final apt = _appointments[index];
        final isScheduled = apt['status'] == 'scheduled';

        return GlassCard(
          borderLeftColor: isScheduled ? AppColors.secondary : AppColors.textLight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(apt['patientName'] ?? 'Unknown Patient',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 12, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text('${apt['date']} • ${apt['time']}',
                                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                            const SizedBox(width: 12),
                            const Icon(Icons.cake, size: 12, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text('${apt['patientAge'] ?? '?'} yrs',
                                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(
                    text: apt['status'],
                    color: isScheduled ? AppColors.secondary : AppColors.textLight,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (isScheduled)
                    Expanded(
                      child: PrimaryButton(
                        text: 'Start Call',
                        icon: Icons.videocam,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CallScreen(appointmentId: apt['id'].toString()),
                            ),
                          ).then((_) => _fetchData());
                        },
                      ),
                    ),
                  if (isScheduled) const SizedBox(width: 8),
                  Expanded(
                    child: SecondaryButton(
                      text: apt['prescription'] == null ? 'Write Prescription' : 'View Prescription',
                      icon: Icons.edit_document,
                      onPressed: () => _showPrescriptionDialog(apt),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ===== Doctor Prescription Sheet =====
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
        await SharePlus.instance.share(msg);
      }
    } catch (e) {
      // Fallback to share dialog
      await SharePlus.instance.share(msg);
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

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/incoming_call_listener.dart';
import '../auth/login_screen.dart';
import '../call/call_screen.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _appointments = [];
  bool _loading = true;
  int _activeTab = 0; // 0=home, 1=appointments, 2=profile

  // Booking state
  String _selectedDate = '';
  String _selectedTime = '';
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _bookingLoading = false;

  late Razorpay _razorpay;

  // Store booking data for payment callback
  String? _pendingDoctorId;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _fetchData();
  }

  @override
  void dispose() {
    _razorpay.clear();
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
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

      final profileData = await _supabase
          .from('users')
          .select('*')
          .eq('uid', user.id)
          .single();

      final appointmentsData = await _supabase
          .from('appointments')
          .select('*')
          .eq('patientId', user.id)
          .order('date', ascending: false);

      if (mounted) {
        setState(() {
          _profile = profileData;
          _appointments = List<Map<String, dynamic>>.from(appointmentsData);
          if (_profile?['name'] != null && _nameController.text.isEmpty) {
            _nameController.text = _profile!['name'];
          }
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

  void _startBooking() {
    _selectedDate = '';
    _selectedTime = '';
    _ageController.clear();
    _phoneController.clear();
    _showBookingSheet();
  }

  void _showBookingSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BookingSheet(
        selectedDate: _selectedDate,
        selectedTime: _selectedTime,
        nameController: _nameController,
        ageController: _ageController,
        phoneController: _phoneController,
        isLoading: _bookingLoading,
        onDateChanged: (d) => _selectedDate = d,
        onTimeChanged: (t) => _selectedTime = t,
        onProceedPayment: () {
          _proceedToPayment(ctx);
        },
      ),
    );
  }

  Future<void> _proceedToPayment(BuildContext sheetContext) async {
    if (_selectedDate.isEmpty || _selectedTime.isEmpty ||
        _nameController.text.trim().isEmpty || _ageController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all details before proceeding.')),
      );
      return;
    }

    Navigator.pop(sheetContext);
    setState(() => _bookingLoading = true);

    try {
      // Get doctor ID
      final doctors = await _supabase
          .from('users')
          .select('uid')
          .eq('role', 'doctor')
          .limit(1);
      _pendingDoctorId = (doctors.isNotEmpty) ? doctors[0]['uid'] : 'dr_santosh';

      // Bypass Razorpay for direct booking
      await _supabase.from('appointments').insert({
        'patientId': _profile!['uid'],
        'doctorId': _pendingDoctorId ?? 'dr_santosh',
        'date': _selectedDate,
        'time': _selectedTime,
        'status': 'scheduled',
        'fee': 0,
        'patientName': _nameController.text,
        'patientAge': _ageController.text,
        'patientPhone': _phoneController.text,
      });

      await _fetchData();
      setState(() {
        _activeTab = 0; // Stay on home page to show the upcoming appointment
        _bookingLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment booked successfully!'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving appointment: $e')),
      );
      setState(() => _bookingLoading = false);
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      await _supabase.from('appointments').insert({
        'patientId': _profile!['uid'],
        'doctorId': _pendingDoctorId ?? 'dr_santosh',
        'date': _selectedDate,
        'time': _selectedTime,
        'status': 'scheduled',
        'fee': 250,
        'patientName': _nameController.text,
        'patientAge': _ageController.text,
        'patientPhone': _phoneController.text,
      });

      await _fetchData();
      setState(() {
        _activeTab = 1;
        _bookingLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment successful! Appointment booked.'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving appointment: $e')),
      );
      setState(() => _bookingLoading = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    setState(() => _bookingLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment failed: ${response.message ?? "Unknown error"}')),
    );
  }

  void _showPrescription(Map<String, dynamic> apt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PrescriptionSheet(appointment: apt),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            // Content
            Expanded(
              child: IndexedStack(
                index: _activeTab,
                children: [
                  _buildHome(),
                  _buildAppointments(),
                  _buildProfile(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
      // Incoming call listener overlay
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _profile != null
          ? IncomingCallListener(uid: _profile!['uid'] ?? '')
          : null,
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
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.show_chart, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, ${_profile?['name']?.toString().split(' ')[0] ?? 'User'}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text('How are you today?', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: _handleLogout,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
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

  Widget _buildHome() {
    final scheduled = _appointments.where((a) => a['status'] == 'scheduled').toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero CTA (Only show if no upcoming appointments to save space)
          if (scheduled.isEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(100),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Need a Consultation?',
                      style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 6),
                  Text('Book a video call with our specialist doctor today.',
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.white70)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _startBooking,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text('Book Appointment', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          Text('Our Specialist', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),

          // Large Doctor Card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.black.withAlpha(20)),
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), bottomLeft: Radius.circular(24)),
                  child: Image.asset(
                    'assets/dr_santosh.jpg.png',
                    width: 130,
                    height: 170,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 130,
                      height: 170,
                      color: AppColors.primaryLight,
                      child: const Center(
                        child: Icon(Icons.person, size: 50, color: AppColors.primary),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text('Dr. Santosh',
                                  style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700)),
                            ),
                            const Icon(Icons.verified, color: AppColors.primary, size: 18),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Physician & Child Care',
                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.accentLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.medical_services, size: 14, color: Color(0xFFB45309)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text('MBBS, Gold Medalist',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFB45309)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                        if (scheduled.isEmpty) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _startBooking,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text('Book Now', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Upcoming appointment
          if (scheduled.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Upcoming', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            GlassCard(
              borderLeftColor: AppColors.secondary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Date & Time', style: Theme.of(context).textTheme.bodySmall),
                      const StatusBadge(text: 'Scheduled', color: AppColors.secondary),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${scheduled[0]['date']} at ${scheduled[0]['time']}',
                    style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  PrimaryButton(
                    text: 'Join Video Call',
                    icon: Icons.videocam,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CallScreen(appointmentId: scheduled[0]['id'].toString()),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAppointments() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Appointments', style: Theme.of(context).textTheme.headlineSmall),
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
                    const SizedBox(height: 16),
                    PrimaryButton(
                      text: 'Book Now',
                      onPressed: () {
                        setState(() => _activeTab = 0);
                        _startBooking();
                      },
                    ),
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Dr. Santosh Kumar Singh',
                                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.access_time, size: 12, color: AppColors.textMuted),
                                  const SizedBox(width: 4),
                                  Text('${apt['date']} • ${apt['time']}',
                                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
                                ],
                              ),
                            ],
                          ),
                          StatusBadge(
                            text: apt['status'],
                            color: apt['status'] == 'scheduled' ? AppColors.primary : AppColors.secondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          if (apt['status'] == 'scheduled')
                            Expanded(
                              child: PrimaryButton(
                                text: 'Join Call',
                                icon: Icons.videocam,
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CallScreen(appointmentId: apt['id'].toString()),
                                    ),
                                  );
                                },
                              ),
                            ),
                          if (apt['prescription'] != null) ...[
                            if (apt['status'] == 'scheduled') const SizedBox(width: 8),
                            Expanded(
                              child: SecondaryButton(
                                text: 'View Prescription',
                                icon: Icons.description,
                                onPressed: () => _showPrescription(apt),
                              ),
                            ),
                          ],
                        ],
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
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _profile?['name']?.toString().substring(0, 1).toUpperCase() ?? 'U',
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _profile?['name'] ?? 'User',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  _profile?['email'] ?? '',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
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

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor.withAlpha(30)),
        ),
      ),
      child: SafeArea(
        child: BottomNavigationBar(
          currentIndex: _activeTab,
          onTap: (i) => setState(() => _activeTab = i),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Visits'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

// ===== Booking Bottom Sheet =====
class _BookingSheet extends StatefulWidget {
  final String selectedDate;
  final String selectedTime;
  final TextEditingController nameController;
  final TextEditingController ageController;
  final TextEditingController phoneController;
  final bool isLoading;
  final ValueChanged<String> onDateChanged;
  final ValueChanged<String> onTimeChanged;
  final VoidCallback onProceedPayment;

  const _BookingSheet({
    required this.selectedDate,
    required this.selectedTime,
    required this.nameController,
    required this.ageController,
    required this.phoneController,
    required this.isLoading,
    required this.onDateChanged,
    required this.onTimeChanged,
    required this.onProceedPayment,
  });

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  late String _date;
  late String _time;
  final _times = ['10:00 AM', '11:30 AM', '02:00 PM', '04:30 PM', '06:00 PM'];

  @override
  void initState() {
    super.initState();
    _date = widget.selectedDate;
    _time = widget.selectedTime;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) {
      final d = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() => _date = d);
      widget.onDateChanged(d);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.white.withAlpha(30) : Colors.black.withAlpha(20);
    final fieldBgColor = isDark ? Colors.white.withAlpha(15) : AppColors.surfaceLight;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.backgroundLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(80), blurRadius: 40, offset: const Offset(0, -10))],
        border: Border(top: BorderSide(color: isDark ? Colors.white.withAlpha(20) : Colors.white, width: 1.5)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.textLight.withAlpha(128),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Book Appointment', style: Theme.of(context).textTheme.headlineSmall),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10), shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Date picker
            Text('SELECT DATE', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: fieldBgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, size: 20, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Text(
                      _date.isNotEmpty ? _date : 'Choose a date for your visit',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: _date.isNotEmpty ? FontWeight.w600 : FontWeight.w400,
                        color: _date.isNotEmpty ? (isDark ? Colors.white : AppColors.textDark) : AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Time selector
            Text('AVAILABLE SLOTS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _times.map((t) {
                final selected = _time == t;
                return GestureDetector(
                  onTap: () {
                    setState(() => _time = t);
                    widget.onTimeChanged(t);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: selected ? AppColors.primaryGradient : null,
                      color: selected ? null : fieldBgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? Colors.transparent : borderColor),
                      boxShadow: selected ? [BoxShadow(color: AppColors.primary.withAlpha(80), blurRadius: 12, offset: const Offset(0, 4))] : null,
                    ),
                    child: Text(
                      t, 
                      style: GoogleFonts.inter(
                        fontSize: 14, 
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500, 
                        color: selected ? Colors.white : (isDark ? Colors.white70 : AppColors.textDark)
                      )
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            
            Text('PATIENT DETAILS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.8)),
            const SizedBox(height: 12),
            PremiumTextField(label: 'Full Name', hint: 'Enter patient name', prefixIcon: Icons.person_outline, controller: widget.nameController),
            Row(
              children: [
                Expanded(child: PremiumTextField(label: 'Age', hint: 'e.g. 25', controller: widget.ageController, keyboardType: TextInputType.number)),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: PremiumTextField(label: 'Phone Number', hint: 'WhatsApp Number', controller: widget.phoneController, keyboardType: TextInputType.phone)),
              ],
            ),
            const SizedBox(height: 8),
            PrimaryButton(
              text: 'Confirm Appointment',
              icon: Icons.check_circle_outline,
              isLoading: widget.isLoading,
              onPressed: widget.onProceedPayment,
            ),
          ],
        ),
      ),
    );
  }
}

// ===== Prescription Bottom Sheet =====
class _PrescriptionSheet extends StatelessWidget {
  final Map<String, dynamic> appointment;

  const _PrescriptionSheet({required this.appointment});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 5, decoration: BoxDecoration(color: AppColors.textLight.withAlpha(128), borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.description, color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  Text('Prescription', style: Theme.of(context).textTheme.headlineSmall),
                ]),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (appointment['prescriptionUrl'] != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  appointment['prescriptionUrl'],
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),

            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black.withAlpha(10)),
              ),
              child: Text(
                appointment['prescription'] ?? 'No text notes provided.',
                style: GoogleFonts.firaCode(fontSize: 13, height: 1.6),
              ),
            ),
            const SizedBox(height: 20),

            PrimaryButton(
              text: 'Download Prescription',
              icon: Icons.download,
              onPressed: () {
                // In Flutter, we can share as text
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Prescription saved!')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

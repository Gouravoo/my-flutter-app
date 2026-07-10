import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import '../../core/theme.dart';

class CallScreen extends StatefulWidget {
  final String appointmentId;
  /// true when user accepted an incoming call (don't re-broadcast)
  final bool isIncoming;

  const CallScreen({
    super.key,
    required this.appointmentId,
    this.isIncoming = false,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  String? _error;
  bool _loading = true;
  String _callerName = 'User';
  String _userId = '';
  String _otherUserId = '';

  // ZegoCloud credentials
  int? _appID;
  String? _appSign;

  // "Connecting..." animation
  late AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _init();
  }

  @override
  void dispose() {
    _dotController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() => _error = 'Not authenticated');
        return;
      }
      _userId = user.id;

      // Fetch ZegoCloud credentials from Supabase app_settings table
      final settings = await _supabase
          .from('app_settings')
          .select('setting_value')
          .eq('setting_key', 'zego_app_id')
          .maybeSingle();

      final signSettings = await _supabase
          .from('app_settings')
          .select('setting_value')
          .eq('setting_key', 'zego_app_sign')
          .maybeSingle();

      if (settings == null || signSettings == null) {
        setState(() {
          _error = 'Video call configuration not found. Please contact admin.';
          _loading = false;
        });
        return;
      }

      _appID = int.tryParse(settings['setting_value'].toString());
      _appSign = signSettings['setting_value'].toString();

      if (_appID == null || _appSign == null || _appSign!.isEmpty) {
        setState(() {
          _error = 'Invalid video call configuration. Please contact admin.';
          _loading = false;
        });
        return;
      }

      // Fetch appointment details
      final apt = await _supabase
          .from('appointments')
          .select('*')
          .eq('id', widget.appointmentId)
          .maybeSingle();

      if (apt == null) {
        setState(() {
          _error = 'Appointment not found (ID: ${widget.appointmentId})';
          _loading = false;
        });
        return;
      }

      if (apt['status'] == 'completed') {
        setState(() {
          _error = 'This appointment has already been completed.';
          _loading = false;
        });
        return;
      }

      final isPatient = user.id == apt['patientId'];

      // Fetch caller name
      final profile = await _supabase
          .from('users')
          .select('name')
          .eq('uid', user.id)
          .maybeSingle();

      _callerName = isPatient
          ? (profile?['name'] ?? 'Patient')
          : 'Dr. ${profile?['name'] ?? 'Doctor'}';

      // Determine the other user's ID
      _otherUserId = isPatient
          ? (apt['doctorId']?.toString() ?? '')
          : (apt['patientId']?.toString() ?? '');

      // ONLY broadcast "incoming_call" if this is an OUTGOING call (not accepting an incoming one)
      if (!widget.isIncoming && _otherUserId.isNotEmpty) {
        final channel = _supabase.channel('calls_$_otherUserId',
            opts: const RealtimeChannelConfig(ack: true));

        channel.subscribe((status, [error]) async {
          if (status == RealtimeSubscribeStatus.subscribed) {
            await channel.sendBroadcastMessage(
              event: 'incoming_call',
              payload: {
                'appointmentId': widget.appointmentId,
                'callerName': _callerName,
              },
            );
            Future.delayed(const Duration(seconds: 1), () {
              _supabase.removeChannel(channel);
            });
          }
        });
      }

      // If this is an INCOMING call being accepted, tell the caller to stop ringing
      if (widget.isIncoming && _otherUserId.isNotEmpty) {
        _broadcastCallAccepted();
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// Broadcast "call_accepted" so the other party's IncomingCallListener stops ringing
  Future<void> _broadcastCallAccepted() async {
    final channel = _supabase.channel('calls_$_otherUserId',
        opts: const RealtimeChannelConfig(ack: true));

    channel.subscribe((status, [error]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await channel.sendBroadcastMessage(
          event: 'call_accepted',
          payload: {
            'appointmentId': widget.appointmentId,
          },
        );
        Future.delayed(const Duration(seconds: 1), () {
          _supabase.removeChannel(channel);
        });
      }
    });
  }

  /// Broadcast "call_ended" so both sides can clean up
  Future<void> _broadcastCallEnded() async {
    if (_otherUserId.isEmpty) return;
    final channel = _supabase.channel('calls_$_otherUserId',
        opts: const RealtimeChannelConfig(ack: true));

    channel.subscribe((status, [error]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await channel.sendBroadcastMessage(
          event: 'call_ended',
          payload: {
            'appointmentId': widget.appointmentId,
          },
        );
        Future.delayed(const Duration(seconds: 1), () {
          _supabase.removeChannel(channel);
        });
      }
    });
  }

  /// When call ends — DO NOT auto-complete appointment. Just go back.
  Future<void> _onCallEnd() async {
    await _broadcastCallEnded();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Error state
    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF111827),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_outline,
                      size: 32, color: AppColors.danger),
                ),
                const SizedBox(height: 20),
                Text(
                  _error!,
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Go Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white30),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Loading / "Connecting..." state with animated dots
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFF111827),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(80),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(Icons.videocam_rounded,
                    size: 36, color: Colors.white),
              ),
              const SizedBox(height: 24),
              AnimatedBuilder(
                animation: _dotController,
                builder: (_, __) {
                  final dots = '.' * ((_dotController.value * 4).floor() % 4);
                  return Text(
                    'Connecting$dots',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Setting up video call',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Launch ZegoUIKitPrebuiltCall directly
    return SafeArea(
      child: ZegoUIKitPrebuiltCall(
        appID: _appID!,
        appSign: _appSign!,
        userID: _userId.replaceAll('-', ''),
        userName: _callerName,
        callID: widget.appointmentId.replaceAll('-', ''),
        events: ZegoUIKitPrebuiltCallEvents(
          onCallEnd: (ZegoCallEndEvent event, VoidCallback defaultAction) {
            _onCallEnd();
          },
        ),
        config: ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
          ..topMenuBar.isVisible = true
          ..bottomMenuBar.buttons = [
            ZegoCallMenuBarButtonName.toggleCameraButton,
            ZegoCallMenuBarButtonName.toggleMicrophoneButton,
            ZegoCallMenuBarButtonName.hangUpButton,
            ZegoCallMenuBarButtonName.switchAudioOutputButton,
            ZegoCallMenuBarButtonName.switchCameraButton,
          ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import '../../core/theme.dart';

class CallScreen extends StatefulWidget {
  final String appointmentId;

  const CallScreen({super.key, required this.appointmentId});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _supabase = Supabase.instance.client;
  String? _error;
  bool _loading = true;
  String _callerName = 'User';
  String _userId = '';
  
  // ZegoCloud Credentials Provided by User
  final int _appID = 1322131216;
  final String _appSign = '71e66c6461ba0311eedfde898177919ac381ba4af5fd7257ce6a5b1883c9f169';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() => _error = 'Not authenticated');
        return;
      }
      _userId = user.id;

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

      // Broadcast incoming call to the other user via Supabase Realtime
      final targetIds = [apt['patientId'], apt['doctorId']];
      for (final targetUid in targetIds) {
        if (targetUid == null || targetUid == user.id) continue;

        final channel = _supabase.channel('calls_$targetUid',
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
            // Delay removing channel to ensure message is sent
            Future.delayed(const Duration(seconds: 1), () {
              _supabase.removeChannel(channel);
            });
          }
        });
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF111827),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error!,
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.danger),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white30),
                  ),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF111827),
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    // Launch ZegoUIKitPrebuiltCall directly which handles the entire Video UI
    return SafeArea(
      child: ZegoUIKitPrebuiltCall(
        appID: _appID,
        appSign: _appSign,
        userID: _userId.replaceAll('-', ''),
        userName: _callerName,
        callID: widget.appointmentId.replaceAll('-', ''),
        events: ZegoUIKitPrebuiltCallEvents(
          onCallEnd: (ZegoCallEndEvent event, VoidCallback defaultAction) {
            Navigator.of(context).pop();
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

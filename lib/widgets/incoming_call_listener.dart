import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:vibration/vibration.dart';
import '../core/theme.dart';
import '../screens/call/call_screen.dart';

/// WhatsApp-style incoming call listener.
///
/// Wrap your dashboard content in a Stack and place this on top:
/// ```dart
/// Stack(children: [
///   yourMainContent,
///   IncomingCallListener(uid: currentUserUid),
/// ])
/// ```
class IncomingCallListener extends StatefulWidget {
  final String uid;

  const IncomingCallListener({super.key, required this.uid});

  @override
  State<IncomingCallListener> createState() => _IncomingCallListenerState();
}

class _IncomingCallListenerState extends State<IncomingCallListener>
    with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _channel;
  String? _appointmentId;
  String? _callerName;
  Timer? _autoDeclineTimer;

  // Animations
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late AnimationController _glowController;
  late Animation<double> _slideAnim;

  // Ringtone & Vibration
  final _ringtonePlayer = FlutterRingtonePlayer();
  bool _isRinging = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnim = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _subscribe();
  }

  void _subscribe() {
    if (widget.uid.isEmpty) return;

    _channel = _supabase.channel('calls_${widget.uid}',
        opts: const RealtimeChannelConfig(ack: true));

    _channel!
        .onBroadcast(
          event: 'incoming_call',
          callback: (payload) {
            debugPrint('📞 Incoming call received: $payload');
            if (mounted && _appointmentId == null) {
              setState(() {
                _appointmentId = payload['appointmentId']?.toString();
                _callerName =
                    payload['callerName']?.toString() ?? 'Unknown User';
              });
              _startRinging();
              _slideController.forward();

              // Auto-decline after 60 seconds
              _autoDeclineTimer?.cancel();
              _autoDeclineTimer = Timer(const Duration(seconds: 60), () {
                if (mounted && _appointmentId != null) {
                  _decline();
                }
              });
            }
          },
        )
        .subscribe();
  }

  Future<void> _startRinging() async {
    if (_isRinging) return;
    _isRinging = true;

    // Play device ringtone
    _ringtonePlayer.play(
      android: AndroidSounds.ringtone,
      ios: IosSounds.electronic,
      looping: true,
      volume: 1.0,
      asAlarm: false,
    );

    // Start vibration pattern (WhatsApp-like: vibrate-pause-vibrate)
    _startVibrationLoop();

    // Start animations
    _pulseController.repeat();
    _glowController.repeat(reverse: true);
  }

  Timer? _vibrationTimer;

  void _startVibrationLoop() {
    _vibrationTimer?.cancel();
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 2000), (_) {
      if (_isRinging) {
        Vibration.vibrate(duration: 800);
      }
    });
    // Vibrate immediately
    Vibration.vibrate(duration: 800);
  }

  void _stopRinging() {
    _isRinging = false;
    _ringtonePlayer.stop();
    Vibration.cancel();
    _vibrationTimer?.cancel();
    _pulseController.stop();
    _glowController.stop();
    _autoDeclineTimer?.cancel();
  }

  void _decline() {
    _stopRinging();
    _slideController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _appointmentId = null;
          _callerName = null;
        });
      }
    });
  }

  void _accept() {
    _stopRinging();
    final aptId = _appointmentId;
    setState(() {
      _appointmentId = null;
      _callerName = null;
    });
    if (aptId != null) {
      HapticFeedback.mediumImpact();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CallScreen(appointmentId: aptId)),
      );
    }
  }

  @override
  void dispose() {
    _stopRinging();
    if (_channel != null) {
      _supabase.removeChannel(_channel!);
    }
    _pulseController.dispose();
    _slideController.dispose();
    _glowController.dispose();
    _autoDeclineTimer?.cancel();
    _vibrationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_appointmentId == null) return const SizedBox.shrink();

    // Full-screen WhatsApp-style incoming call overlay
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _slideAnim,
        builder: (context, child) {
          return Opacity(
            opacity: _slideAnim.value.clamp(0.0, 1.0),
            child: child,
          );
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0A1628),
                  Color(0xFF0F2035),
                  Color(0xFF091520),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // "Incoming Video Call" label
                  AnimatedBuilder(
                    animation: _glowController,
                    builder: (_, __) {
                      return Text(
                        'Incoming Video Call',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withAlpha(
                            (150 + (105 * _glowController.value)).toInt(),
                          ),
                          letterSpacing: 1.2,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),

                  // Caller avatar with animated ring
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer pulse ring 1
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (_, __) {
                            final val = _pulseController.value;
                            return Container(
                              width: 100 + (50 * val),
                              height: 100 + (50 * val),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.secondary
                                      .withAlpha((120 * (1 - val)).toInt()),
                                  width: 2,
                                ),
                              ),
                            );
                          },
                        ),
                        // Outer pulse ring 2
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (_, __) {
                            final val =
                                (_pulseController.value + 0.5) % 1.0;
                            return Container(
                              width: 100 + (50 * val),
                              height: 100 + (50 * val),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.secondary
                                      .withAlpha((80 * (1 - val)).toInt()),
                                  width: 1.5,
                                ),
                              ),
                            );
                          },
                        ),
                        // Avatar circle
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF6366F1),
                                Color(0xFF818CF8),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withAlpha(80),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              (_callerName ?? 'U')
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: GoogleFonts.outfit(
                                fontSize: 40,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Caller name
                  Text(
                    _callerName ?? 'Unknown',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // AarogyaPlus branding
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.videocam_rounded,
                        size: 16,
                        color: Colors.white.withAlpha(120),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'AarogyaPlus Video Call',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withAlpha(120),
                        ),
                      ),
                    ],
                  ),

                  const Spacer(flex: 3),

                  // Action buttons (WhatsApp-style)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Decline button
                        _CallActionButton(
                          icon: Icons.call_end_rounded,
                          label: 'Decline',
                          color: const Color(0xFFEF4444),
                          onTap: _decline,
                          pulseController: null,
                        ),
                        // Accept button (with pulse animation)
                        _CallActionButton(
                          icon: Icons.videocam_rounded,
                          label: 'Accept',
                          color: const Color(0xFF10B981),
                          onTap: _accept,
                          pulseController: _glowController,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated call action button (accept/decline)
class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final AnimationController? pulseController;

  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    Widget button = GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withAlpha(120),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, size: 32, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withAlpha(200),
            ),
          ),
        ],
      ),
    );

    // Add pulse glow animation to accept button
    if (pulseController != null) {
      return AnimatedBuilder(
        animation: pulseController!,
        builder: (_, __) {
          final scale = 1.0 + (0.08 * pulseController!.value);
          return Transform.scale(
            scale: scale,
            child: button,
          );
        },
      );
    }

    return button;
  }
}

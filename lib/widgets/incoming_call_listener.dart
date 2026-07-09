import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../screens/call/call_screen.dart';

/// Global incoming call listener widget.
///
/// Use it as a Stack overlay wrapping your main content:
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
  late AnimationController _pulseController;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _bounceAnim = Tween<double>(begin: 0.0, end: -6.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
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
            debugPrint('Incoming call received: $payload');
            if (mounted) {
              setState(() {
                _appointmentId = payload['appointmentId']?.toString();
                _callerName =
                    payload['callerName']?.toString() ?? 'Unknown User';
              });
            }
          },
        )
        .subscribe();
  }

  void _decline() {
    setState(() {
      _appointmentId = null;
      _callerName = null;
    });
  }

  void _accept() {
    final aptId = _appointmentId;
    setState(() {
      _appointmentId = null;
      _callerName = null;
    });
    if (aptId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CallScreen(appointmentId: aptId)),
      );
    }
  }

  @override
  void dispose() {
    if (_channel != null) {
      _supabase.removeChannel(_channel!);
    }
    _pulseController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Return nothing when no incoming call
    if (_appointmentId == null) return const SizedBox.shrink();

    // Full-screen overlay
    return Positioned.fill(
      child: Material(
        color: Colors.black54,
        child: SafeArea(
          child: Center(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(80),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated phone icon with ripple
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Ripple ring
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (_, __) {
                            final value = _pulseController.value;
                            return Container(
                              width: 80 + (50 * value),
                              height: 80 + (50 * value),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primary
                                      .withAlpha((200 * (1 - value)).toInt()),
                                  width: 2.5,
                                ),
                              ),
                            );
                          },
                        ),
                        // Second ripple ring (delayed)
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (_, __) {
                            final value =
                                (_pulseController.value + 0.5) % 1.0;
                            return Container(
                              width: 80 + (50 * value),
                              height: 80 + (50 * value),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primary
                                      .withAlpha((150 * (1 - value)).toInt()),
                                  width: 2,
                                ),
                              ),
                            );
                          },
                        ),
                        // Phone icon with bounce
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withAlpha(50),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: AnimatedBuilder(
                            animation: _bounceAnim,
                            builder: (_, child) {
                              return Transform.translate(
                                offset: Offset(0, _bounceAnim.value),
                                child: child,
                              );
                            },
                            child: const Icon(Icons.phone_rounded,
                                size: 36, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Incoming Video Call',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_callerName ?? 'Someone'} is calling you...',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Action buttons
                  Row(
                    children: [
                      // Decline
                      Expanded(
                        child: Material(
                          color: AppColors.danger,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            onTap: _decline,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.danger.withAlpha(100),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.phone_disabled,
                                      size: 20, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Decline',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Accept
                      Expanded(
                        child: Material(
                          color: AppColors.secondary,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            onTap: _accept,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.secondary.withAlpha(100),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.videocam,
                                      size: 20, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Accept',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';
import '../core/offline_call_setup_helper.dart';

/// Manages Zego Call Invitation Service for background/offline call ringing.
///
/// Call [init] after login, and [uninit] on logout.
class ZegoCallService {
  ZegoCallService._();
  static final instance = ZegoCallService._();

  bool _initialized = false;

  /// Initialize Zego Call Invitation after user logs in.
  /// This enables the app to receive calls even when in background.
  Future<void> init({
    required BuildContext context,
    required String userId,
    required String userName,
  }) async {
    if (_initialized) return;

    final supabase = Supabase.instance.client;

    // Fetch Zego credentials from Supabase
    final settings = await supabase
        .from('app_settings')
        .select('setting_value')
        .eq('setting_key', 'zego_app_id')
        .maybeSingle();

    final signSettings = await supabase
        .from('app_settings')
        .select('setting_value')
        .eq('setting_key', 'zego_app_sign')
        .maybeSingle();

    if (settings == null || signSettings == null) {
      debugPrint('⚠️ Zego credentials not found, skipping call service init');
      return;
    }

    final appID = int.tryParse(settings['setting_value'].toString());
    final appSign = signSettings['setting_value'].toString();

    if (appID == null || appSign.isEmpty) {
      debugPrint('⚠️ Invalid Zego credentials');
      return;
    }

    // Remove dashes from userId for Zego compatibility
    final zegoUserId = userId.replaceAll('-', '');

    ZegoUIKitPrebuiltCallInvitationService().init(
      appID: appID,
      appSign: appSign,
      userID: zegoUserId,
      userName: userName,
      plugins: [ZegoUIKitSignalingPlugin()],
      // Show call invitation on notification when app is in background
      notificationConfig: ZegoCallInvitationNotificationConfig(
        androidNotificationConfig: ZegoCallAndroidNotificationConfig(
          channelID: 'medicine_tele_call',
          channelName: 'Call Notifications',
          showBackgroundUIConfirmDialog: false, // Disables Zego's default English popup
        ),
      ),
      config: ZegoCallInvitationConfig(
        endCallWhenInitiatorLeave: true,
        canInvitingInCalling: false,
        permissions: [
          ZegoCallInvitationPermission.camera,
          ZegoCallInvitationPermission.microphone,
          ZegoCallInvitationPermission.systemAlertWindow,
          ZegoCallInvitationPermission.manuallyByUser,
        ],
      ),
      requireConfig: (ZegoCallInvitationData data) {
        if (data.type == ZegoCallInvitationType.videoCall) {
          return ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
            ..useSpeakerWhenJoining = true
            ..enableAccidentalTouchPrevention = false
            ..topMenuBar.isVisible = true
            ..bottomMenuBar.buttons = [
              ZegoCallMenuBarButtonName.toggleCameraButton,
              ZegoCallMenuBarButtonName.toggleMicrophoneButton,
              ZegoCallMenuBarButtonName.hangUpButton,
              ZegoCallMenuBarButtonName.switchAudioOutputButton,
              ZegoCallMenuBarButtonName.switchCameraButton,
            ];
        } else {
          return ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall()
            ..enableAccidentalTouchPrevention = false;
        }
      },
    );

    // Prompt user for background permissions gracefully
    OfflineCallSetupHelper.checkAndRequestPermissions(context);

    _initialized = true;
    debugPrint('✅ Zego Call Invitation Service initialized for $userName ($zegoUserId)');
  }

  /// Uninitialize on logout
  Future<void> uninit() async {
    if (!_initialized) return;
    ZegoUIKitPrebuiltCallInvitationService().uninit();
    _initialized = false;
    debugPrint('📴 Zego Call Invitation Service uninitialized');
  }

  bool get isInitialized => _initialized;
}

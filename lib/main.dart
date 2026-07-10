import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';
import 'screens/splash_screen.dart';
import 'core/theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();

// Zego handles its own FCM offline pushes, avoiding conflict.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (still needed for Zego FCM to work internally on some setups)
  await Firebase.initializeApp();

  await Supabase.initialize(
    url: 'https://bzckanmfgkcljvsroamr.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ6Y2thbm1mZ2tjbGp2c3JvYW1yIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODMwMjgxMzIsImV4cCI6MjA5ODYwNDEzMn0.ynKAmkCD2sTr4N62uhuB-r_OND0nnQJokSCbVWUqXpE',
  );

  ZegoUIKitPrebuiltCallInvitationService().setNavigatorKey(navigatorKey);
  ZegoUIKitPrebuiltCallInvitationService().useSystemCallingUI(
    [ZegoUIKitSignalingPlugin()],
  );

  runApp(const AarogyaPlusApp());
}

class AarogyaPlusApp extends StatelessWidget {
  const AarogyaPlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AarogyaPlus',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }
}

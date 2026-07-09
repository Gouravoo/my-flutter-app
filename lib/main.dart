import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/splash_screen.dart';
import 'core/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://bzckanmfgkcljvsroamr.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ6Y2thbm1mZ2tjbGp2c3JvYW1yIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODMwMjgxMzIsImV4cCI6MjA5ODYwNDEzMn0.ynKAmkCD2sTr4N62uhuB-r_OND0nnQJokSCbVWUqXpE',
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
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }
}

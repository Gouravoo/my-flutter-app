import 'package:flutter/material.dart';
import 'dart:io';
import 'package:auto_start_flutter/auto_start_flutter.dart';

/// Guides users (even non-tech-savvy ones) through enabling
/// background permissions so calls ring when the app is closed.
class OfflineCallSetupHelper {
  static Future<void> checkAndRequestPermissions(BuildContext context) async {
    if (!Platform.isAndroid) return;

    try {
      final isBatteryOptDisabled = await isBatteryOptimizationDisabled ?? true;
      final autoStartAvailable = await isAutoStartAvailable ?? false;

      // Only show if something needs to be set up
      if (!isBatteryOptDisabled || autoStartAvailable) {
        await Future.delayed(const Duration(seconds: 2));
        if (!context.mounted) return;
        _showSetupDialog(context, !isBatteryOptDisabled, autoStartAvailable);
      }
    } catch (e) {
      debugPrint('OfflineCallSetupHelper error: $e');
    }
  }

  static void _showSetupDialog(BuildContext context, bool needsBattery, bool needsAutoStart) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.phone_in_talk_rounded, size: 48, color: Colors.green.shade700),
              ),
              const SizedBox(height: 16),

              // Title - simple Hindi
              const Text(
                '📞 Call Setup Zaruri Hai',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Simple explanation
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Agar aap ye setup nahi karenge toh phone band hone par doctor/patient ki call nahi aayegi.\n\n'
                  '👇 Neeche button dabao, phone apne aap settings kholega — bas "Allow" ya "ON" karo.',
                  style: TextStyle(fontSize: 15, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),

              // Big, clear "Setup Now" button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  icon: const Icon(Icons.settings, size: 22),
                  label: const Text('✅  Setup Karo (1 minute)'),
                  onPressed: () async {
                    Navigator.pop(ctx);

                    // Step 1: Battery optimization — shows system dialog, user just taps "Allow"
                    if (needsBattery) {
                      await disableBatteryOptimization();
                      await Future.delayed(const Duration(seconds: 1));
                    }

                    // Step 2: AutoStart — opens settings page, user toggles ON
                    if (needsAutoStart) {
                      await getAutoStartPermission();
                    }
                  },
                ),
              ),
              const SizedBox(height: 10),

              // "Later" option - small and subtle
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Baad mein karunga',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

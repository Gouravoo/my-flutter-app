import 'package:flutter/material.dart';
import 'dart:io';
import 'package:auto_start_flutter/auto_start_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

class OfflineCallSetupHelper {
  static Future<void> checkAndRequestPermissions(BuildContext context) async {
    if (!Platform.isAndroid) return;

    try {
      // 1. Check if Battery Optimization is disabled
      final isBatteryOptDisabled = await isBatteryOptimizationDisabled ?? true;
      // 2. Check if AutoStart is available
      final autoStartAvailable = await isAutoStartAvailable ?? false;

      // We only prompt if they haven't set these up, and the device supports AutoStart (like Xiaomi/Oppo/Vivo).
      if (!isBatteryOptDisabled || autoStartAvailable) {
        // Wait for a brief moment after screen load
        await Future.delayed(const Duration(seconds: 2));

        if (!context.mounted) return;

        // Verify if we actually need to ask (double check)
        bool needsBattery = !isBatteryOptDisabled;
        
        // Show elegant dialog
        if (needsBattery || autoStartAvailable) {
          _showSetupDialog(context, needsBattery, autoStartAvailable);
        }
      }
    } catch (e) {
      debugPrint('Error checking offline call permissions: $e');
    }
  }

  static void _showSetupDialog(BuildContext context, bool needsBattery, bool needsAutoStart) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('☎️ Background Call Setup', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'To ensure you receive calls even when the app is closed or your screen is locked, you must enable background execution permissions.',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              if (needsAutoStart) {
                await getAutoStartPermission();
                await Future.delayed(const Duration(seconds: 1)); // small delay between intents
              }
              if (needsBattery) {
                await disableBatteryOptimization();
              }
            },
            child: const Text('Setup Now'),
          ),
        ],
      ),
    );
  }
}

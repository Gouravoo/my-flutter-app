import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('About', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // App Icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withAlpha(60), blurRadius: 30, offset: const Offset(0, 10)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset('assets/app_icon.png', fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                          color: AppColors.primaryLight,
                          child: const Icon(Icons.medical_services, size: 48, color: AppColors.primary),
                        )),
              ),
            ),
            const SizedBox(height: 20),
            ShaderMask(
              shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
              child: Text('AarogyaPlus',
                  style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
            const SizedBox(height: 6),
            Text('Version 1.0.0', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted)),
            const SizedBox(height: 32),

            // Description
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black.withAlpha(10)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('About AarogyaPlus', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Text(
                    'AarogyaPlus is a telemedicine platform that connects patients with qualified doctors through video consultations. '
                    'Our mission is to make quality healthcare accessible to everyone, regardless of their location.\n\n'
                    'Features:\n'
                    '• Video consultations with specialists\n'
                    '• Easy appointment booking\n'
                    '• Digital prescriptions\n'
                    '• Secure payment via Razorpay\n'
                    '• Background call support',
                    style: GoogleFonts.inter(fontSize: 14, height: 1.6, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black.withAlpha(10)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Developer', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Text(
                    'Developed by AGL Prim Group\naglprimgroup@gmail.com',
                    style: GoogleFonts.inter(fontSize: 14, height: 1.6, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            Text('Made with ❤️ in India',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textLight)),
          ],
        ),
      ),
    );
  }
}

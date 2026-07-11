import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Privacy Policy', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield, color: AppColors.primary, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Last updated: July 2026',
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSection('1. Information We Collect',
                'We collect personal information that you voluntarily provide when registering for an account, '
                    'booking appointments, or contacting us. This includes:\n\n'
                    '• Name, email address, phone number\n'
                    '• Age and health-related information shared during consultations\n'
                    '• Payment information (processed securely via Razorpay)\n'
                    '• Device information for app functionality'),
            _buildSection('2. How We Use Your Information',
                'Your information is used to:\n\n'
                    '• Provide telemedicine consultation services\n'
                    '• Process appointment bookings and payments\n'
                    '• Send appointment reminders and notifications\n'
                    '• Improve our services and user experience\n'
                    '• Comply with legal obligations'),
            _buildSection('3. Data Security',
                'We implement industry-standard security measures to protect your personal information. '
                    'All data is encrypted in transit and at rest. Payment processing is handled by Razorpay, '
                    'a PCI DSS compliant payment gateway.'),
            _buildSection('4. Data Sharing',
                'We do not sell your personal data. Information may be shared with:\n\n'
                    '• Your assigned doctor for consultation purposes\n'
                    '• Payment processors (Razorpay) for transaction processing\n'
                    '• As required by law or legal proceedings'),
            _buildSection('5. Your Rights',
                'You have the right to:\n\n'
                    '• Access your personal data\n'
                    '• Request correction of inaccurate data\n'
                    '• Request deletion of your account\n'
                    '• Opt out of marketing communications'),
            _buildSection('6. Contact Us',
                'For privacy-related inquiries, contact us at:\n'
                    'Email: aglprimgroup@gmail.com'),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(content, style: GoogleFonts.inter(fontSize: 14, height: 1.7, color: const Color(0xFF64748B))),
        ],
      ),
    );
  }
}

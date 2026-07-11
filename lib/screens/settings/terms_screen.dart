import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Terms of Service', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
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
                color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description, color: Color(0xFFB45309), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Effective: July 2026',
                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFB45309), fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSection('1. Acceptance of Terms',
                'By using AarogyaPlus, you agree to these Terms of Service. '
                    'If you do not agree, please do not use the app.'),
            _buildSection('2. Description of Service',
                'AarogyaPlus is a telemedicine platform that facilitates video consultations between patients and doctors. '
                    'We are a technology platform and do not provide medical advice directly.'),
            _buildSection('3. User Accounts',
                '• You must provide accurate information during registration\n'
                    '• You are responsible for maintaining the confidentiality of your account\n'
                    '• You must be at least 18 years old to create an account\n'
                    '• A parent or guardian may create an account on behalf of a minor'),
            _buildSection('4. Appointments & Payments',
                '• Consultation fees are displayed before payment\n'
                    '• Payments are processed securely via Razorpay\n'
                    '• Refund policy: Contact support within 24 hours if a consultation was not conducted\n'
                    '• Appointment times are subject to doctor availability'),
            _buildSection('5. Medical Disclaimer',
                'AarogyaPlus facilitates consultations but does not guarantee any specific health outcomes. '
                    'The advice given by doctors is based on the information provided by patients. '
                    'In case of medical emergencies, please call emergency services immediately.'),
            _buildSection('6. User Conduct',
                'Users must:\n'
                    '• Provide truthful health information\n'
                    '• Treat doctors and staff with respect\n'
                    '• Not misuse the platform for non-medical purposes\n'
                    '• Not share their account credentials'),
            _buildSection('7. Limitation of Liability',
                'AarogyaPlus is not liable for any direct, indirect, incidental, or consequential damages '
                    'arising from the use of our services beyond the amount paid for the specific consultation.'),
            _buildSection('8. Changes to Terms',
                'We reserve the right to modify these terms at any time. '
                    'Continued use of the app constitutes acceptance of the updated terms.'),
            _buildSection('9. Contact',
                'For questions about these terms, contact us at:\n'
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

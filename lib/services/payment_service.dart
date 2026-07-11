import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles Razorpay payment flow for appointment bookings.
///
/// Usage:
/// ```dart
/// final success = await PaymentService.instance.processPayment(
///   context: context,
///   amountInRupees: 300,
///   patientName: 'John',
///   patientPhone: '9876543210',
///   patientEmail: 'john@example.com',
/// );
/// if (success) { /* book appointment */ }
/// ```
class PaymentService {
  PaymentService._();
  static final instance = PaymentService._();

  late Razorpay _razorpay;
  bool _initialized = false;

  // Callbacks set per payment attempt
  void Function(PaymentSuccessResponse)? _onSuccess;
  void Function(PaymentFailureResponse)? _onFailure;

  /// Fee in rupees (fetched from Supabase, default 300)
  int _consultationFee = 300;
  int get consultationFee => _consultationFee;

  /// Razorpay key (fetched from Supabase, fallback to test key)
  String _razorpayKey = 'rzp_test_1DP5mmOlF5G5ag'; // Test key — replace with live key later

  void _init() {
    if (_initialized) return;
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleFailure);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _initialized = true;
  }

  /// Fetch Razorpay key and consultation fee from Supabase app_settings.
  Future<void> loadSettings() async {
    try {
      final supabase = Supabase.instance.client;

      final keyResult = await supabase
          .from('app_settings')
          .select('setting_value')
          .eq('setting_key', 'razorpay_key')
          .maybeSingle();

      if (keyResult != null && keyResult['setting_value'] != null) {
        _razorpayKey = keyResult['setting_value'].toString();
      }

      final feeResult = await supabase
          .from('app_settings')
          .select('setting_value')
          .eq('setting_key', 'consultation_fee')
          .maybeSingle();

      if (feeResult != null && feeResult['setting_value'] != null) {
        _consultationFee = int.tryParse(feeResult['setting_value'].toString()) ?? 300;
      }
    } catch (e) {
      debugPrint('PaymentService.loadSettings error: $e');
    }
  }

  /// Start the Razorpay payment flow.
  /// Returns a [Future<bool>] — true if payment succeeded, false otherwise.
  Future<bool> processPayment({
    required BuildContext context,
    required String patientName,
    required String patientPhone,
    String? patientEmail,
  }) async {
    _init();
    await loadSettings();

    final completer = _PaymentCompleter();

    _onSuccess = (response) {
      completer.complete(true, paymentId: response.paymentId);
    };
    _onFailure = (response) {
      completer.complete(false, errorMessage: response.message);
    };

    final options = {
      'key': _razorpayKey,
      'amount': _consultationFee * 100, // Razorpay takes amount in paise
      'name': 'AarogyaPlus',
      'description': 'Doctor Consultation Fee',
      'prefill': {
        'contact': patientPhone,
        'email': patientEmail ?? '',
        'name': patientName,
      },
      'theme': {
        'color': '#6366F1',
      },
      'currency': 'INR',
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Razorpay open error: $e');
      return false;
    }

    // Wait for the payment result
    return await completer.future;
  }

  /// Get the last successful payment ID (for storing in appointment record)
  String? get lastPaymentId => _lastPaymentId;
  String? _lastPaymentId;

  void _handleSuccess(PaymentSuccessResponse response) {
    debugPrint('✅ Payment success: ${response.paymentId}');
    _lastPaymentId = response.paymentId;
    _onSuccess?.call(response);
  }

  void _handleFailure(PaymentFailureResponse response) {
    debugPrint('❌ Payment failed: ${response.code} - ${response.message}');
    _lastPaymentId = null;
    _onFailure?.call(response);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('💳 External wallet: ${response.walletName}');
  }

  void dispose() {
    if (_initialized) {
      _razorpay.clear();
      _initialized = false;
    }
  }
}

/// Simple completer that resolves a Future<bool> on payment result.
class _PaymentCompleter {
  final _completer = Future<bool>.delayed(Duration.zero, () => false);
  bool _isCompleted = false;
  bool _result = false;
  String? paymentId;
  String? errorMessage;

  late final Future<bool> future;

  _PaymentCompleter() {
    future = _createFuture();
  }

  Future<bool> _createFuture() async {
    // Poll until completed (Razorpay callbacks are async)
    while (!_isCompleted) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return _result;
  }

  void complete(bool result, {String? paymentId, String? errorMessage}) {
    _result = result;
    this.paymentId = paymentId;
    this.errorMessage = errorMessage;
    _isCompleted = true;
  }
}

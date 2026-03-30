import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';

class LoginPhonePage extends ConsumerStatefulWidget {
  const LoginPhonePage({
    super.key,
    required this.isSignup,
  });

  final bool isSignup;

  @override
  ConsumerState<LoginPhonePage> createState() => _LoginPhonePageState();
}

class _LoginPhonePageState extends ConsumerState<LoginPhonePage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController(text: '+225 ');
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  String _normalizePhone(String input) {
    final raw = input.trim();
    var cleaned = raw.replaceAll(RegExp(r'[^0-9+]'), '');

    if (!cleaned.startsWith('+')) {
      cleaned = '+$cleaned';
    }

    if (cleaned.startsWith('+') && cleaned.length == 11) {
      cleaned = '+225${cleaned.substring(1)}';
    } else if (cleaned.startsWith('+0') && cleaned.length == 11) {
      cleaned = '+225${cleaned.substring(2)}';
    }

    return cleaned;
  }

  String? _validatePhone(String? v) {
    final phone = _normalizePhone(v ?? '');
    final ok = RegExp(r'^\+225\d{10}$').hasMatch(phone);
    if (!ok) {
      return 'Numéro invalide. Exemple : +2250102030405';
    }
    return null;
  }

  Future<void> _requestOtp() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final phone = _normalizePhone(_phoneCtrl.text);

    setState(() => _isLoading = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;
    setState(() => _isLoading = false);

    final navigator = Navigator.of(context);

    final ok = await navigator.push<bool>(
      MaterialPageRoute(
        builder: (_) => OtpVerifyPage(
          isSignup: widget.isSignup,
          phone: phone,
          verificationId: 'mock_verification_id',
        ),
      ),
    );

    if (!mounted) return;

    if (ok == true) {
      navigator.pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isSignup ? 'Inscription' : 'Connexion';
    final headline = widget.isSignup
        ? 'Créez votre compte avec votre numéro'
        : 'Connectez-vous avec votre numéro';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              headline,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Nous vous enverrons un code par SMS.'),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _isLoading ? null : _requestOtp(),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Téléphone (CI)',
                  hintText: '+2250102030405',
                  prefixIcon: Icon(Icons.phone),
                ),
                validator: _validatePhone,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _isLoading ? null : _requestOtp,
                child: _isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Recevoir le code'),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Astuce dev : à l’étape suivante, on branchera un vrai OTP.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class OtpVerifyPage extends ConsumerStatefulWidget {
  const OtpVerifyPage({
    super.key,
    required this.isSignup,
    required this.phone,
    required this.verificationId,
  });

  final bool isSignup;
  final String phone;
  final String verificationId;

  @override
  ConsumerState<OtpVerifyPage> createState() => _OtpVerifyPageState();
}

class _OtpVerifyPageState extends ConsumerState<OtpVerifyPage> {
  final _formKey = GlobalKey<FormState>();
  final _otpCtrl = TextEditingController();
  bool _isLoading = false;

  static const int _cooldownSeconds = 30;
  int _secondsLeft = _cooldownSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsLeft = _cooldownSeconds;

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 0) {
        t.cancel();
        return;
      }
      setState(() => _secondsLeft -= 1);
    });

    setState(() {});
  }

  String? _validateOtp(String? v) {
    final otp = (v ?? '').trim();
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      return '6 chiffres requis';
    }
    return null;
  }

  String _buildDisplayName() {
    return widget.isSignup ? 'Nouveau patient' : 'Utilisateur';
  }

  Future<void> _verify() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final otp = _otpCtrl.text.trim();

    setState(() => _isLoading = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final success = otp == '123456';

    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (!success) {
      setState(() => _isLoading = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Code incorrect. Essaie 123456 (mock).'),
        ),
      );
      return;
    }

    await ref.read(authControllerProvider.notifier).loginMock(
          name: _buildDisplayName(),
          phone: widget.phone,
        );

    if (!mounted) return;

    setState(() => _isLoading = false);
    navigator.pop(true);
  }

  void _resend() {
    if (_secondsLeft > 0) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Code renvoyé à ${widget.phone} (mock)')),
    );
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _secondsLeft == 0;
    final title = widget.isSignup ? 'Inscription' : 'Connexion';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Code envoyé à ${widget.phone}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _isLoading ? null : _verify(),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  labelText: 'Code (6 chiffres)',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: _validateOtp,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _isLoading ? null : _verify,
                child: _isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Vérifier'),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: canResend ? _resend : null,
              child: Text(
                canResend
                    ? 'Renvoyer le code'
                    : 'Renvoyer dans ${_secondsLeft}s',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Astuce dev : utilise 123456 pour valider (mock).',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
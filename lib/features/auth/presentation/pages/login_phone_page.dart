import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/app_user.dart';
import '../../../../core/utils/string_normalizers.dart';
import '../../../profile/presentation/providers/patient_profile_providers.dart';
import '../../../professional_profile/domain/professional_profile.dart';
import '../../../professional_profile/presentation/providers/professional_profile_providers.dart';
import '../providers/auth_providers.dart';
import '../providers/auth_controller.dart';

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
  AppUserRole _selectedRole = AppUserRole.patient;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  String _normalizePhone(String input) {
    return StringNormalizers.normalizePhoneCi(input);
  }

  String? _validatePhone(String? value) {
    final phone = _normalizePhone(value ?? '');
    if (!StringNormalizers.isValidCiPhone(phone)) {
      return 'Numéro invalide. Exemple : +2250102030405';
    }
    return null;
  }

  Future<void> _requestOtp() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final phone = _normalizePhone(_phoneCtrl.text);
    final repo = ref.read(authRepositoryProvider);
    final existingUser = await repo.findByPhone(phone);

    if (widget.isSignup && existingUser != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existingUser.role == _selectedRole
                ? 'Ce numéro possède déjà un compte. Utilisez Connexion.'
                : 'Ce numéro est déjà utilisé pour un compte ${existingUser.role == AppUserRole.professional ? 'professionnel' : 'patient'}.',
          ),
        ),
      );
      return;
    }

    if (!widget.isSignup && existingUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aucun compte trouvé pour ce numéro. Veuillez vous inscrire.',
          ),
        ),
      );
      return;
    }

    if (!widget.isSignup &&
        existingUser != null &&
        existingUser.role != _selectedRole) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ce numéro existe, mais comme compte ${existingUser.role == AppUserRole.professional ? 'professionnel' : 'patient'}.',
          ),
        ),
      );
      return;
    }

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
          role: _selectedRole,
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
    final isProfessional = _selectedRole == AppUserRole.professional;

    final title = widget.isSignup ? 'Inscription' : 'Connexion';

    final headline = widget.isSignup
        ? 'Créez votre compte'
        : 'Accédez à votre compte';

    final description = widget.isSignup
        ? (isProfessional
            ? 'Créez votre espace professionnel avec votre numéro de téléphone.'
            : 'Créez votre espace patient avec votre numéro de téléphone.')
        : (isProfessional
            ? 'Connectez-vous à votre espace professionnel avec votre numéro.'
            : 'Connectez-vous à votre espace patient avec votre numéro.');

    final phoneHelperText = widget.isSignup
        ? (isProfessional
            ? 'Ce numéro servira à créer votre compte professionnel.'
            : 'Ce numéro servira à créer votre compte patient.')
        : (isProfessional
            ? 'Saisissez le numéro déjà utilisé pour votre compte professionnel.'
            : 'Saisissez le numéro déjà utilisé pour votre compte patient.');

    final primaryButtonLabel =
        widget.isSignup ? 'Continuer l’inscription' : 'Recevoir le code';

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
            Text(description),
            const SizedBox(height: 16),
            const Text(
              'Je suis :',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SegmentedButton<AppUserRole>(
              segments: const [
                ButtonSegment<AppUserRole>(
                  value: AppUserRole.patient,
                  label: Text('Patient'),
                  icon: Icon(Icons.person_outline),
                ),
                ButtonSegment<AppUserRole>(
                  value: AppUserRole.professional,
                  label: Text('Professionnel'),
                  icon: Icon(Icons.badge_outlined),
                ),
              ],
              selected: {_selectedRole},
              onSelectionChanged: (selection) {
                setState(() {
                  _selectedRole = selection.first;
                });
              },
            ),
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
                decoration: InputDecoration(
                  labelText: 'Téléphone (CI)',
                  hintText: '+2250102030405',
                  prefixIcon: const Icon(Icons.phone),
                  helperText: phoneHelperText,
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
                    : Text(primaryButtonLabel),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.isSignup
                  ? 'Astuce dev : cette étape prépare la création du compte avant validation OTP.'
                  : 'Astuce dev : cette étape vérifie l’accès à un compte existant avant validation OTP.',
              style: const TextStyle(fontSize: 12),
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
    required this.role,
  });

  final bool isSignup;
  final String phone;
  final String verificationId;
  final AppUserRole role;

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

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      if (_secondsLeft <= 0) {
        timer.cancel();
        return;
      }

      setState(() => _secondsLeft -= 1);
    });

    setState(() {});
  }

  String? _validateOtp(String? value) {
    final otp = (value ?? '').trim();
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      return '6 chiffres requis';
    }
    return null;
  }

  String _normalizePhoneKey(String value) {
    return StringNormalizers.normalizePhoneCi(value)
        .replaceAll(RegExp(r'\D'), '');
  }

  String _lastPhoneDigits(String phone, {int count = 4}) {
    final digits = _normalizePhoneKey(phone);
    if (digits.isEmpty) return '0000';
    if (digits.length <= count) return digits;
    return digits.substring(digits.length - count);
  }

  String _buildDisplayName() {
    if (widget.isSignup) {
      return widget.role == AppUserRole.professional
          ? 'Professionnel ${_lastPhoneDigits(widget.phone)}'
          : 'Patient ${_lastPhoneDigits(widget.phone)}';
    }

    if (widget.role == AppUserRole.professional) {
      final profile = ref.read(professionalProfileProvider);
      final samePhone =
          _normalizePhoneKey(profile.phone) == _normalizePhoneKey(widget.phone);
      if (samePhone && profile.displayName.trim().isNotEmpty) {
        return profile.displayName.trim();
      }

      return 'Professionnel ${_lastPhoneDigits(widget.phone)}';
    }

    final patientProfileAsync = ref.read(patientProfileProvider);
    final patientProfile = patientProfileAsync.valueOrNull;
    final patientPhone = patientProfile?.phone.trim() ?? '';
    final patientName = patientProfile?.name.trim() ?? '';

    final samePatientPhone =
        _normalizePhoneKey(patientPhone) == _normalizePhoneKey(widget.phone);
    if (samePatientPhone && patientName.isNotEmpty) {
      return patientName;
    }

    return 'Utilisateur';
  }

  Future<void> _syncProfessionalProfileAfterAuth() async {
    if (widget.role != AppUserRole.professional) {
      return;
    }

    final authUser = ref.read(authControllerProvider).user;
    if (authUser == null) {
      return;
    }

    final profileController = ref.read(professionalProfileProvider.notifier);
    final existingProfile = ref.read(professionalProfileProvider);
    final normalizedCurrentPhone =
        StringNormalizers.normalizePhoneCi(widget.phone);
    final samePhone = _normalizePhoneKey(existingProfile.phone) ==
        _normalizePhoneKey(widget.phone);

    if (!widget.isSignup && samePhone) {
      final syncedProfile = existingProfile.copyWith(
        id: authUser.id,
        phone: normalizedCurrentPhone,
      );

      await profileController.replaceProfile(syncedProfile);
      return;
    }

    final seededName = widget.isSignup
        ? 'Professionnel ${_lastPhoneDigits(widget.phone)}'
        : (samePhone && existingProfile.displayName.trim().isNotEmpty
            ? existingProfile.displayName.trim()
            : 'Professionnel ${_lastPhoneDigits(widget.phone)}');

    final seededProfile = ProfessionalProfile(
      id: authUser.id,
      displayName: seededName,
      specialty: samePhone && existingProfile.specialty.trim().isNotEmpty
          ? existingProfile.specialty
          : 'Professionnel de santé',
      structureName:
          samePhone && existingProfile.structureName.trim().isNotEmpty
              ? existingProfile.structureName
              : 'Structure à compléter',
      phone: normalizedCurrentPhone,
      city: samePhone ? existingProfile.city : '',
      area: samePhone ? existingProfile.area : '',
      address: samePhone ? existingProfile.address : '',
      bio: samePhone ? existingProfile.bio : '',
      languages: samePhone && existingProfile.languages.isNotEmpty
          ? existingProfile.languages
          : const ['Français'],
      consultationFeeLabel:
          samePhone ? existingProfile.consultationFeeLabel : '',
      isVerified: samePhone ? existingProfile.isVerified : false,
    );

    await profileController.replaceProfile(seededProfile);
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
    final controller = ref.read(authControllerProvider.notifier);

    if (!success) {
      setState(() => _isLoading = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Code incorrect. Essaie 123456 (mock).'),
        ),
      );
      return;
    }

    try {
      if (widget.isSignup) {
        await controller.registerMock(
          name: _buildDisplayName(),
          phone: widget.phone,
          role: widget.role,
        );
      } else {
        await controller.loginMock(
          name: _buildDisplayName(),
          phone: widget.phone,
          role: widget.role,
        );
      }

      await _syncProfessionalProfileAfterAuth();

      if (!mounted) return;

      setState(() => _isLoading = false);
      navigator.pop(true);
    } on AuthPhoneAlreadyUsedException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Ce numéro est déjà utilisé pour un compte ${e.existingRole == AppUserRole.professional ? 'professionnel' : 'patient'}.',
          ),
        ),
      );
    } on AuthLoginUserNotFoundException {
      if (!mounted) return;
      setState(() => _isLoading = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Aucun compte trouvé pour ce numéro. Veuillez vous inscrire.',
          ),
        ),
      );
    } on AuthPhoneRoleMismatchException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Ce numéro existe déjà comme compte ${e.existingRole == AppUserRole.professional ? 'professionnel' : 'patient'}.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Une erreur est survenue pendant la validation.',
          ),
        ),
      );
    }
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
    final isProfessional = widget.role == AppUserRole.professional;

    final otpHeadline = widget.isSignup
        ? (isProfessional
            ? 'Validation de votre inscription professionnelle'
            : 'Validation de votre inscription patient')
        : (isProfessional
            ? 'Validation de votre connexion professionnelle'
            : 'Validation de votre connexion patient');

    final otpDescription = widget.isSignup
        ? 'Entrez le code reçu pour finaliser la création de votre compte.'
        : 'Entrez le code reçu pour accéder à votre compte existant.';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              otpHeadline,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(otpDescription),
            const SizedBox(height: 8),
            Text('Code envoyé à ${widget.phone}'),
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
                    : Text(
                        widget.isSignup
                            ? 'Finaliser l’inscription'
                            : 'Vérifier et se connecter',
                      ),
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
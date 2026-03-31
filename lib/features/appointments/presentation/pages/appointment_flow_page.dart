import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/formatters/app_date_formatters.dart';
import '../../../../core/utils/string_normalizers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/domain/patient_profile.dart';
import '../../../profile/presentation/providers/patient_profile_providers.dart';
import '../../../search/domain/search_item.dart';
import '../../domain/appointment.dart';
import '../../domain/appointments_repository.dart';
import '../providers/appointments_providers.dart';

class AppointmentFlowPage extends ConsumerStatefulWidget {
  const AppointmentFlowPage({
    super.key,
    required this.item,
    required this.day,
    required this.slot,
    required this.isLoggedIn,
    required this.onRequireAuth,
  });

  final SearchItem item;
  final DateTime day;
  final String slot;
  final bool isLoggedIn;
  final Future<bool> Function() onRequireAuth;

  @override
  ConsumerState<AppointmentFlowPage> createState() =>
      _AppointmentFlowPageState();
}

class _AppointmentFlowPageState extends ConsumerState<AppointmentFlowPage> {
  static const String _consentVersion = 'dl-ci-consent-v1';

  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController(text: '+225 ');

  int _step = 0;
  String _reason = 'Consultation';
  bool _consentAccepted = false;
  bool _confirming = false;
  bool _didInitialPrefill = false;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  DateTime get _normalizedDay =>
      DateTime(widget.day.year, widget.day.month, widget.day.day);

  int get _selectedReasonDurationMinutes => _reasonDurationMinutes(_reason);

  bool get _isPhoneValid {
    final normalized = StringNormalizers.normalizePhoneCi(_phoneCtrl.text);
    return StringNormalizers.isValidCiPhone(normalized);
  }

  bool get _isPatientStepValid {
    return _firstNameCtrl.text.trim().isNotEmpty &&
        _lastNameCtrl.text.trim().isNotEmpty &&
        _isPhoneValid;
  }

  bool get _canConfirm {
    final authState = ref.read(authControllerProvider);
    return authState.isAuthenticated && _isPatientStepValid && _consentAccepted;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authState = ref.read(authControllerProvider);

      if (widget.isLoggedIn && !authState.isAuthenticated) {
        await ref.read(authControllerProvider.notifier).setLoggedIn(true);
      }

      if (!mounted) return;

      final patientProfile = ref.read(patientProfileProvider).valueOrNull;
      _prefillFromProfileAndAuth(
        profile: patientProfile,
        authUser: ref.read(authControllerProvider).user,
      );
      _didInitialPrefill = true;
    });
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _prefillFromProfileAndAuth({
    PatientProfile? profile,
    dynamic authUser,
  }) {
    final preferredName = profile?.name.trim().isNotEmpty == true
        ? profile!.name.trim()
        : (authUser?.name?.trim() ?? '');

    final preferredPhone = profile?.phone.trim().isNotEmpty == true
        ? profile!.phone.trim()
        : (authUser?.phone?.trim() ?? '');

    if (preferredName.isNotEmpty &&
        _firstNameCtrl.text.trim().isEmpty &&
        _lastNameCtrl.text.trim().isEmpty) {
      final (firstName, lastName) = _splitFullName(preferredName);
      _firstNameCtrl.text = firstName;
      _lastNameCtrl.text = lastName;
    }

    final currentPhone = _phoneCtrl.text.trim();
    if ((currentPhone.isEmpty || currentPhone == '+225') &&
        preferredPhone.isNotEmpty) {
      _phoneCtrl.text = preferredPhone;
    }

    if (_phoneCtrl.text.trim().isEmpty) {
      _phoneCtrl.text = '+225 ';
    }
  }

  (String, String) _splitFullName(String fullName) {
    final normalized = StringNormalizers.collapseSpaces(fullName);
    if (normalized.isEmpty) {
      return ('', '');
    }

    final parts = normalized.split(' ');
    final firstName = parts.first;
    final lastName = parts.length > 1 ? parts.skip(1).join(' ') : '';
    return (firstName, lastName);
  }

  Future<void> _ensureAuth() async {
    final authStateBefore = ref.read(authControllerProvider);
    if (authStateBefore.isAuthenticated) return;

    final ok = await widget.onRequireAuth();
    if (!mounted) return;

    final authStateAfter = ref.read(authControllerProvider);
    if (authStateAfter.isAuthenticated) {
      await ref.read(patientProfileProvider.future).catchError((_) => null);
      _prefillFromProfileAndAuth(
        profile: ref.read(patientProfileProvider).valueOrNull,
        authUser: authStateAfter.user,
      );
      return;
    }

    if (ok) {
      await ref.read(authControllerProvider.notifier).setLoggedIn(true);
      await ref.read(patientProfileProvider.future).catchError((_) => null);
      if (!mounted) return;

      _prefillFromProfileAndAuth(
        profile: ref.read(patientProfileProvider).valueOrNull,
        authUser: ref.read(authControllerProvider).user,
      );
      return;
    }

    _showMessage('Connexion requise pour envoyer la demande.');
  }

  void _next() {
    if (_step == 1) {
      final ok = _formKey.currentState?.validate() ?? false;
      if (!ok) {
        setState(() {
          _autovalidateMode = AutovalidateMode.onUserInteraction;
        });
        return;
      }
    }

    if (_step < 2) {
      setState(() => _step += 1);
    }
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step -= 1);
  }

  Future<void> _confirm() async {
    await _ensureAuth();
    if (!mounted) return;

    final authState = ref.read(authControllerProvider);
    if (!authState.isAuthenticated) return;

    if (!_consentAccepted) {
      _showMessage('Tu dois accepter le consentement pour continuer.');
      return;
    }

    final formValid = _formKey.currentState?.validate() ?? _isPatientStepValid;
    if (!formValid || !_isPatientStepValid) {
      setState(() {
        _autovalidateMode = AutovalidateMode.onUserInteraction;
      });
      _showMissingFeedback();
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _confirming = true);

    try {
      final controller = ref.read(appointmentsControllerProvider);

      final appointment = Appointment(
        id: _newId(),
        createdAt: DateTime.now(),
        practitionerId: widget.item.id,
        practitionerName: widget.item.displayName,
        specialty: widget.item.specialty,
        address: widget.item.address,
        city: widget.item.city,
        area: widget.item.area,
        day: _normalizedDay,
        slot: widget.slot,
        reason: _reason,
        patientFirstName: _firstNameCtrl.text.trim(),
        patientLastName: _lastNameCtrl.text.trim(),
        patientPhoneE164: StringNormalizers.normalizePhoneCi(_phoneCtrl.text),
        consentAccepted: true,
        consentVersion: _consentVersion,
        consentAcceptedAt: DateTime.now(),
        status: AppointmentStatus.pending,
      );

      await Future<void>.delayed(const Duration(milliseconds: 300));
      await controller.create(appointment);

      if (!mounted) return;
      setState(() => _confirming = false);

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => _AppointmentRequestSentPage(
            appointment: appointment,
            durationMinutes: _selectedReasonDurationMinutes,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _confirming = false);

      if (e is AppointmentSlotUnavailableException) {
        _showMessage(
          'Ce créneau vient d’être réservé. Merci d’en choisir un autre.',
        );
        Navigator.of(context).pop();
        return;
      }

      _showMessage('Erreur lors de l’envoi de la demande.');
    }
  }

  void _showMissingFeedback() {
    final authState = ref.read(authControllerProvider);
    final missing = <String>[];

    if (!authState.isAuthenticated) {
      missing.add('connexion');
    }
    if (_firstNameCtrl.text.trim().isEmpty) {
      missing.add('prénom');
    }
    if (_lastNameCtrl.text.trim().isEmpty) {
      missing.add('nom');
    }
    if (!_isPhoneValid) {
      missing.add('téléphone');
    }
    if (!_consentAccepted) {
      missing.add('consentement');
    }

    if (missing.isEmpty) return;
    _showMessage('À compléter : ${missing.join(', ')}');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final patientProfileAsync = ref.watch(patientProfileProvider);

    patientProfileAsync.whenData((patientProfile) {
      if (!_didInitialPrefill || !mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _prefillFromProfileAndAuth(
          profile: patientProfile,
          authUser: authState.user,
        );
      });
    });

    final pages = <Widget>[
      _ReasonStep(
        item: widget.item,
        selected: _reason,
        onSelect: (value) => setState(() => _reason = value),
      ),
      _PatientStep(
        formKey: _formKey,
        autovalidateMode: _autovalidateMode,
        firstNameCtrl: _firstNameCtrl,
        lastNameCtrl: _lastNameCtrl,
        phoneCtrl: _phoneCtrl,
      ),
      _SummaryStep(
        item: widget.item,
        day: _normalizedDay,
        slot: widget.slot,
        reason: _reason,
        durationMinutes: _selectedReasonDurationMinutes,
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        phone: StringNormalizers.normalizePhoneCi(_phoneCtrl.text),
        authed: authState.isAuthenticated,
        consentAccepted: _consentAccepted,
        onConsentChanged: (value) => setState(() => _consentAccepted = value),
        onLoginPressed: _ensureAuth,
      ),
    ];

    final title = switch (_step) {
      0 => 'Motif',
      1 => 'Patient',
      _ => 'Récapitulatif',
    };

    final canGoNext = _step < 2;
    final primaryLabel = canGoNext ? 'Continuer' : 'Envoyer la demande';

    return Scaffold(
      appBar: AppBar(
        title: Text('Prendre RDV • $title'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _step == 0 ? () => Navigator.of(context).pop() : _back,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              _FlowStepper(currentStep: _step),
              const SizedBox(height: 12),
              Expanded(child: pages[_step]),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _confirming
                  ? null
                  : () {
                      if (canGoNext) {
                        _next();
                        return;
                      }

                      if (!_canConfirm) {
                        _showMissingFeedback();
                        return;
                      }

                      _confirm();
                    },
              child: _confirming
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(primaryLabel),
            ),
          ),
        ),
      ),
    );
  }
}

class _FlowStepper extends StatelessWidget {
  const _FlowStepper({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget dot(bool active) => Container(
          height: 10,
          width: 10,
          decoration: BoxDecoration(
            color: active ? cs.primary : cs.outlineVariant,
            shape: BoxShape.circle,
          ),
        );

    Widget line(bool active) => Expanded(
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              color: active ? cs.primary : cs.outlineVariant,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );

    return Row(
      children: [
        dot(currentStep >= 0),
        line(currentStep >= 1),
        dot(currentStep >= 1),
        line(currentStep >= 2),
        dot(currentStep >= 2),
      ],
    );
  }
}

class _ReasonStep extends StatelessWidget {
  const _ReasonStep({
    required this.item,
    required this.selected,
    required this.onSelect,
  });

  final SearchItem item;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    const reasons = [
      'Consultation',
      'Suivi',
      'Renouvellement ordonnance',
      'Urgence légère',
    ];

    return ListView(
      children: [
        Text(
          item.displayName,
          style: Theme.of(context).textTheme.titleLarge,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          item.specialty,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choisis un motif',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                for (final reason in reasons)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onSelect(reason),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: selected == reason
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected == reason
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selected == reason
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              size: 20,
                              color: selected == reason
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '$reason • ${_formatDurationLabel(_reasonDurationMinutes(reason))}',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PatientStep extends StatelessWidget {
  const _PatientStep({
    required this.formKey,
    required this.autovalidateMode,
    required this.firstNameCtrl,
    required this.lastNameCtrl,
    required this.phoneCtrl,
  });

  final GlobalKey<FormState> formKey;
  final AutovalidateMode autovalidateMode;
  final TextEditingController firstNameCtrl;
  final TextEditingController lastNameCtrl;
  final TextEditingController phoneCtrl;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Form(
              key: formKey,
              autovalidateMode: autovalidateMode,
              child: Column(
                children: [
                  TextFormField(
                    controller: firstNameCtrl,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Prénom',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      final s = (value ?? '').trim();
                      if (s.isEmpty) return 'Prénom requis';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: lastNameCtrl,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nom',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    validator: (value) {
                      final s = (value ?? '').trim();
                      if (s.isEmpty) return 'Nom requis';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone (CI)',
                      prefixIcon: Icon(Icons.phone_outlined),
                      hintText: '+2250102030405',
                    ),
                    validator: (value) {
                      if (!StringNormalizers.isValidCiPhone(value ?? '')) {
                        return 'Numéro invalide. Exemple : +2250102030405';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryStep extends StatelessWidget {
  const _SummaryStep({
    required this.item,
    required this.day,
    required this.slot,
    required this.reason,
    required this.durationMinutes,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.authed,
    required this.consentAccepted,
    required this.onConsentChanged,
    required this.onLoginPressed,
  });

  final SearchItem item;
  final DateTime day;
  final String slot;
  final String reason;
  final int durationMinutes;
  final String firstName;
  final String lastName;
  final String phone;
  final bool authed;
  final bool consentAccepted;
  final ValueChanged<bool> onConsentChanged;
  final VoidCallback onLoginPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Récapitulatif',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                _Line(label: 'Professionnel', value: item.displayName),
                _Line(label: 'Spécialité', value: item.specialty),
                _Line(
                  label: 'Lieu',
                  value: '${item.address} • ${item.locationLabel}',
                ),
                _Line(label: 'Motif', value: reason),
                _Line(
                  label: 'Durée',
                  value: _formatDurationLabel(durationMinutes),
                ),
                _Line(
                  label: 'Date',
                  value: '${AppDateFormatters.formatShortDate(day)} à $slot',
                ),
                const SizedBox(height: 8),
                Divider(color: cs.outlineVariant),
                const SizedBox(height: 8),
                _Line(label: 'Patient', value: '$firstName $lastName'),
                _Line(label: 'Téléphone', value: phone),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Consentement',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Pour envoyer cette demande de rendez-vous, tu acceptes la collecte et le traitement des données strictement nécessaires (identité, contact, motif et créneau), uniquement pour la gestion du rendez-vous.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  value: consentAccepted,
                  onChanged: (value) => onConsentChanged(value ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'J’accepte le traitement de mes données pour cette demande.',
                  ),
                  subtitle: Text(
                    'Le professionnel pourra ensuite confirmer ou refuser la demande.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (!authed)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Connexion requise pour envoyer la demande.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: onLoginPressed,
                    child: const Text('Se connecter'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _AppointmentRequestSentPage extends StatelessWidget {
  const _AppointmentRequestSentPage({
    required this.appointment,
    required this.durationMinutes,
  });

  final Appointment appointment;
  final int durationMinutes;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Demande envoyée'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Icon(
                        Icons.schedule_send_outlined,
                        size: 58,
                        color: cs.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Demande de rendez-vous envoyée',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ta demande a bien été enregistrée localement. Elle est maintenant en attente de réponse du professionnel.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      _ConfirmLine(
                        label: 'Professionnel',
                        value: appointment.practitionerName,
                      ),
                      _ConfirmLine(
                        label: 'Date',
                        value:
                            '${AppDateFormatters.formatShortDate(appointment.day)} à ${appointment.slot}',
                      ),
                      _ConfirmLine(
                        label: 'Motif',
                        value: appointment.reason,
                      ),
                      _ConfirmLine(
                        label: 'Durée',
                        value: _formatDurationLabel(durationMinutes),
                      ),
                      _ConfirmLine(
                        label: 'Patient',
                        value: appointment.patientFullName,
                      ),
                      const _ConfirmLine(
                        label: 'Statut',
                        value: 'Demande envoyée',
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Identifiant : ${appointment.id}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      AppRoutes.appointments,
                      (route) => route.isFirst,
                    );
                  },
                  icon: const Icon(Icons.event_note_outlined),
                  label: const Text('Voir mes rendez-vous'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      AppRoutes.home,
                      (route) => route.isFirst,
                    );
                  },
                  child: const Text('Retour à l’accueil'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmLine extends StatelessWidget {
  const _ConfirmLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: textTheme.labelLarge?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

int _reasonDurationMinutes(String reason) {
  switch (reason) {
    case 'Suivi':
      return 20;
    case 'Renouvellement ordonnance':
      return 15;
    case 'Urgence légère':
      return 15;
    case 'Consultation':
    default:
      return 30;
  }
}

String _formatDurationLabel(int minutes) {
  return '$minutes min';
}

String _newId() {
  final now = DateTime.now();
  return 'apt_${now.microsecondsSinceEpoch}';
}
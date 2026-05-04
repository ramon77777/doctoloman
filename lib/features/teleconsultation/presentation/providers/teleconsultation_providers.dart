import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/app_user.dart';
import '../../../appointments/domain/appointment.dart';
import '../../../appointments/presentation/providers/appointments_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../professional_profile/domain/professional_profile.dart';
import '../../../professional_profile/presentation/providers/professional_profile_providers.dart';
import '../../data/in_memory_teleconsultation_repository.dart';
import '../../data/teleconsultation_local_storage.dart';
import '../../domain/teleconsultation_repository.dart';
import '../../domain/teleconsultation_session.dart';

final teleconsultationLocalStorageProvider =
    Provider<TeleconsultationLocalStorage>(
  (ref) => TeleconsultationLocalStorage(
    ref.watch(sharedPreferencesProvider),
  ),
  name: 'teleconsultationLocalStorageProvider',
);

final teleconsultationRepositoryProvider = Provider<TeleconsultationRepository>(
  (ref) => InMemoryTeleconsultationRepository(
    ref.watch(teleconsultationLocalStorageProvider),
  ),
  name: 'teleconsultationRepositoryProvider',
);

final teleconsultationsListProvider =
    FutureProvider<List<TeleconsultationSession>>(
  (ref) async {
    final repo = ref.watch(teleconsultationRepositoryProvider);
    final items = await repo.listAll();

    final sorted = [...items]
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    return List<TeleconsultationSession>.unmodifiable(sorted);
  },
  name: 'teleconsultationsListProvider',
);

final patientTeleconsultationsProvider =
    FutureProvider<List<TeleconsultationSession>>(
  (ref) async {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;

    if (!authState.isAuthenticated ||
        user == null ||
        user.role != AppUserRole.patient) {
      return const <TeleconsultationSession>[];
    }

    await syncTeleconsultationsFromConfirmedAppointments(ref);

    final items = await ref.watch(teleconsultationsListProvider.future);
    final patientKeys = _buildPatientKeys(user);

    if (patientKeys.isEmpty) {
      return const <TeleconsultationSession>[];
    }

    final filtered = items.where((item) {
      final sessionPatientId = _normalizePatientKey(item.patientId);
      final sessionPatientName = _normalizeTextKey(item.patientName);

      return patientKeys.contains(sessionPatientId) ||
          patientKeys.contains(sessionPatientName);
    }).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    return List<TeleconsultationSession>.unmodifiable(filtered);
  },
  name: 'patientTeleconsultationsProvider',
);

final professionalTeleconsultationsProvider =
    FutureProvider<List<TeleconsultationSession>>(
  (ref) async {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;
    final profile = ref.watch(professionalProfileProvider);

    if (!authState.isAuthenticated ||
        user == null ||
        user.role != AppUserRole.professional) {
      return const <TeleconsultationSession>[];
    }

    await syncTeleconsultationsFromConfirmedAppointments(ref);

    final items = await ref.watch(teleconsultationsListProvider.future);

    final professionalKeys = _buildProfessionalKeys(
      authUser: user,
      profile: profile,
    );

    if (professionalKeys.isEmpty) {
      return const <TeleconsultationSession>[];
    }

    final filtered = items.where((item) {
      final sessionProfessionalId = _normalizeTextKey(item.professionalId);
      final sessionProfessionalName = _normalizeTextKey(item.professionalName);

      return professionalKeys.contains(sessionProfessionalId) ||
          professionalKeys.contains(sessionProfessionalName);
    }).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    return List<TeleconsultationSession>.unmodifiable(filtered);
  },
  name: 'professionalTeleconsultationsProvider',
);

final teleconsultationByIdProvider =
    FutureProvider.family<TeleconsultationSession?, String>(
  (ref, sessionId) async {
    final normalizedId = sessionId.trim();
    if (normalizedId.isEmpty) return null;

    final repo = ref.watch(teleconsultationRepositoryProvider);
    return repo.getById(normalizedId);
  },
  name: 'teleconsultationByIdProvider',
);

final teleconsultationByAppointmentIdProvider =
    FutureProvider.family<TeleconsultationSession?, String>(
  (ref, appointmentId) async {
    final normalizedId = appointmentId.trim();
    if (normalizedId.isEmpty) return null;

    await syncTeleconsultationsFromConfirmedAppointments(ref);

    final repo = ref.watch(teleconsultationRepositoryProvider);
    return repo.getByAppointmentId(normalizedId);
  },
  name: 'teleconsultationByAppointmentIdProvider',
);

final teleconsultationControllerProvider = Provider<TeleconsultationController>(
  (ref) {
    final repo = ref.watch(teleconsultationRepositoryProvider);

    return TeleconsultationController(
      ref: ref,
      repo: repo,
    );
  },
  name: 'teleconsultationControllerProvider',
);

class TeleconsultationController {
  TeleconsultationController({
    required Ref ref,
    required TeleconsultationRepository repo,
  })  : _ref = ref,
        _repo = repo;

  final Ref _ref;
  final TeleconsultationRepository _repo;

  Future<TeleconsultationSession> ensureForAppointment({
    required String appointmentId,
    bool acceptConsent = false,
  }) async {
    final normalizedAppointmentId = appointmentId.trim();

    if (normalizedAppointmentId.isEmpty) {
      throw ArgumentError('Identifiant rendez-vous invalide.');
    }

    final appointment = await _ref.read(
      appointmentByIdProvider(normalizedAppointmentId).future,
    );

    if (appointment == null) {
      throw StateError('Rendez-vous introuvable.');
    }

    if (!_isTeleconsultationEligibleAppointment(appointment)) {
      throw StateError(
        'La téléconsultation est réservée aux rendez-vous confirmés.',
      );
    }

    final existing = await _repo.getByAppointmentId(normalizedAppointmentId);

    if (existing != null) {
      final updated = acceptConsent && !existing.consentAccepted
          ? existing.copyWith(
              consentAccepted: true,
              consentAcceptedAt: DateTime.now(),
            )
          : existing;

      if (updated != existing) {
        await _repo.upsert(updated);
        _invalidateSession(updated);
      }

      return updated;
    }

    final now = DateTime.now();
    final patientId = _normalizePatientKey(appointment.patientPhoneE164);
    final professionalId = appointment.practitionerId.trim();

    final session = TeleconsultationSession(
      id: 'tc_${now.microsecondsSinceEpoch}',
      appointmentId: appointment.id,
      patientId: patientId.isEmpty ? appointment.patientPhoneE164 : patientId,
      patientName: appointment.patientFullName,
      professionalId: professionalId.isEmpty
          ? appointment.practitionerName
          : professionalId,
      professionalName: appointment.practitionerName,
      scheduledAt: appointment.scheduledAt,
      reason: appointment.reason,
      consentAccepted: acceptConsent,
      consentAcceptedAt: acceptConsent ? now : null,
      roomUrl: 'mock://teleconsultation/${appointment.id}',
      status: TeleconsultationStatus.scheduled,
    );

    await _repo.upsert(session);
    _invalidateSession(session);

    return session;
  }

  Future<void> acceptConsent(String sessionId) async {
    final session = await _requireAuthorizedSession(sessionId);
    if (session == null) return;

    if (session.consentAccepted) {
      return;
    }

    final updated = session.copyWith(
      consentAccepted: true,
      consentAcceptedAt: DateTime.now(),
    );

    await _repo.upsert(updated);
    _invalidateSession(updated);
  }

  Future<void> markWaiting(String sessionId) async {
    final session = await _requireAuthorizedSession(sessionId);
    if (session == null || session.isClosed) return;

    if (!session.consentAccepted) {
      throw StateError(
        'Le consentement est requis avant de rejoindre la salle.',
      );
    }

    if (session.status == TeleconsultationStatus.waiting ||
        session.status == TeleconsultationStatus.inProgress) {
      return;
    }

    final updated = session.copyWith(
      status: TeleconsultationStatus.waiting,
    );

    await _repo.upsert(updated);
    _invalidateSession(updated);
  }

  Future<void> startSession(String sessionId) async {
    final session = await _requireAuthorizedSession(sessionId);
    if (session == null) return;

    final authState = _ref.read(authControllerProvider);
    final authUser = authState.user;

    if (authUser?.role != AppUserRole.professional) {
      throw StateError(
        'Seul le professionnel peut démarrer la téléconsultation.',
      );
    }

    if (!session.canStart) {
      throw StateError(
        'Impossible de démarrer cette téléconsultation.',
      );
    }

    final now = DateTime.now();

    final updated = session.copyWith(
      status: TeleconsultationStatus.inProgress,
      startedAt: session.startedAt ?? now,
      clearEndedAt: true,
    );

    await _repo.upsert(updated);
    _invalidateSession(updated);
  }

  Future<void> endSession(String sessionId) async {
    final session = await _requireAuthorizedSession(sessionId);
    if (session == null) return;

    final authState = _ref.read(authControllerProvider);
    final authUser = authState.user;

    if (authUser?.role != AppUserRole.professional) {
      throw StateError(
        'Seul le professionnel peut terminer la téléconsultation.',
      );
    }

    if (!session.canEnd) {
      throw StateError(
        'Impossible de terminer cette téléconsultation.',
      );
    }

    final updated = session.copyWith(
      status: TeleconsultationStatus.completed,
      endedAt: DateTime.now(),
    );

    await _repo.upsert(updated);
    _invalidateSession(updated);
  }

  Future<void> cancelSession(String sessionId) async {
    final session = await _requireAuthorizedSession(sessionId);
    if (session == null || session.isClosed) return;

    final updated = session.copyWith(
      status: TeleconsultationStatus.cancelled,
      endedAt: DateTime.now(),
    );

    await _repo.upsert(updated);
    _invalidateSession(updated);
  }

  Future<void> clear() async {
    await _repo.clear();
    _invalidateCollections();
  }

  Future<TeleconsultationSession?> _requireAuthorizedSession(
    String sessionId,
  ) async {
    final normalizedId = sessionId.trim();
    if (normalizedId.isEmpty) return null;

    final session = await _repo.getById(normalizedId);
    if (session == null) return null;

    final authState = _ref.read(authControllerProvider);
    final authUser = authState.user;

    if (!authState.isAuthenticated || authUser == null) {
      return null;
    }

    if (authUser.role == AppUserRole.patient) {
      final patientKeys = _buildPatientKeys(authUser);
      final sessionPatientId = _normalizePatientKey(session.patientId);
      final sessionPatientName = _normalizeTextKey(session.patientName);

      if (patientKeys.contains(sessionPatientId) ||
          patientKeys.contains(sessionPatientName)) {
        return session;
      }

      return null;
    }

    if (authUser.role == AppUserRole.professional) {
      final profile = _ref.read(professionalProfileProvider);
      final professionalKeys = _buildProfessionalKeys(
        authUser: authUser,
        profile: profile,
      );

      final sessionProfessionalId = _normalizeTextKey(session.professionalId);
      final sessionProfessionalName =
          _normalizeTextKey(session.professionalName);

      if (professionalKeys.contains(sessionProfessionalId) ||
          professionalKeys.contains(sessionProfessionalName)) {
        return session;
      }

      return null;
    }

    return null;
  }

  void _invalidateSession(TeleconsultationSession session) {
    _ref.invalidate(teleconsultationsListProvider);
    _ref.invalidate(patientTeleconsultationsProvider);
    _ref.invalidate(professionalTeleconsultationsProvider);
    _ref.invalidate(teleconsultationByIdProvider(session.id));
    _ref.invalidate(
      teleconsultationByAppointmentIdProvider(session.appointmentId),
    );
  }

  void _invalidateCollections() {
    _ref.invalidate(teleconsultationsListProvider);
    _ref.invalidate(patientTeleconsultationsProvider);
    _ref.invalidate(professionalTeleconsultationsProvider);
  }
}

Future<void> syncTeleconsultationsFromConfirmedAppointments(Ref ref) async {
  final appointments = await ref.read(appointmentsListProvider.future);
  final controller = ref.read(teleconsultationControllerProvider);

  for (final appointment in appointments) {
    if (!_isTeleconsultationEligibleAppointment(appointment)) {
      continue;
    }

    final repo = ref.read(teleconsultationRepositoryProvider);
    final existing = await repo.getByAppointmentId(appointment.id);

    if (existing != null) {
      continue;
    }

    try {
      await controller.ensureForAppointment(
        appointmentId: appointment.id,
      );
    } catch (_) {
      // On ignore volontairement une session impossible à créer pour ne pas
      // bloquer l’affichage de la liste des téléconsultations.
    }
  }
}

bool _isTeleconsultationEligibleAppointment(Appointment appointment) {
  return appointment.status == AppointmentStatus.confirmed;
}

Set<String> _buildPatientKeys(AppUser user) {
  final keys = <String>{
    _normalizePatientKey(user.phone),
    _normalizeTextKey(user.name),
    _normalizeTextKey(user.id),
  };

  keys.removeWhere((value) => value.isEmpty);
  return keys;
}

Set<String> _buildProfessionalKeys({
  required AppUser authUser,
  required ProfessionalProfile profile,
}) {
  final keys = <String>{
    _normalizeTextKey(authUser.id),
    _normalizeTextKey(authUser.name),
    _normalizeTextKey(profile.id),
    _normalizeTextKey(profile.displayName),
  };

  keys.removeWhere((value) => value.isEmpty);
  return keys;
}

String _normalizePatientKey(String value) {
  return value.replaceAll(RegExp(r'\D'), '');
}

String _normalizeTextKey(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('’', "'")
      .replaceAll(RegExp(r'\s+'), ' ');
}
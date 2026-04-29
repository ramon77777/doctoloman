// lib/features/teleconsultations/presentation/providers/teleconsultation_providers.dart

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

final teleconsultationRepositoryProvider =
    Provider<TeleconsultationRepository>(
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

    final patientKey = _normalizePatientKey(user.phone);
    if (patientKey.isEmpty) {
      return const <TeleconsultationSession>[];
    }

    await _syncTeleconsultationsFromConfirmedAppointments(ref);

    final items = await ref.watch(teleconsultationsListProvider.future);

    final filtered = items.where((item) {
      return _normalizePatientKey(item.patientId) == patientKey;
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

    final professionalKeys = _buildProfessionalKeys(
      authUser: user,
      profile: profile,
    );

    if (professionalKeys.isEmpty) {
      return const <TeleconsultationSession>[];
    }

    await _syncTeleconsultationsFromConfirmedAppointments(ref);

    final items = await ref.watch(teleconsultationsListProvider.future);

    final filtered = items.where((item) {
      return professionalKeys.contains(_normalizeTextKey(item.professionalId)) ||
          professionalKeys.contains(_normalizeTextKey(item.professionalName));
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

    final repo = ref.watch(teleconsultationRepositoryProvider);
    return repo.getByAppointmentId(normalizedId);
  },
  name: 'teleconsultationByAppointmentIdProvider',
);

final teleconsultationControllerProvider =
    Provider<TeleconsultationController>(
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

    if (appointment.status != AppointmentStatus.confirmed) {
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

    final session = TeleconsultationSession(
      id: 'tc_${now.microsecondsSinceEpoch}',
      appointmentId: appointment.id,
      patientId: patientId.isEmpty ? appointment.patientPhoneE164 : patientId,
      patientName: appointment.patientFullName,
      professionalId: appointment.practitionerId,
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

    final updated = session.copyWith(
      status: TeleconsultationStatus.waiting,
    );

    await _repo.upsert(updated);
    _invalidateSession(updated);
  }

  Future<void> startSession(String sessionId) async {
    final session = await _requireAuthorizedSession(sessionId);
    if (session == null) return;

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
      final authPatientKey = _normalizePatientKey(authUser.phone);
      final sessionPatientKey = _normalizePatientKey(session.patientId);

      if (authPatientKey.isEmpty || authPatientKey != sessionPatientKey) {
        return null;
      }

      return session;
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

Future<void> _syncTeleconsultationsFromConfirmedAppointments(Ref ref) async {
  final appointments = await ref.read(appointmentsListProvider.future);
  final controller = ref.read(teleconsultationControllerProvider);

  for (final appointment in appointments) {
    if (!_isTeleconsultationEligibleAppointment(appointment)) {
      continue;
    }

    final existing = await ref.read(
      teleconsultationByAppointmentIdProvider(appointment.id).future,
    );

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
  return value.trim();
}
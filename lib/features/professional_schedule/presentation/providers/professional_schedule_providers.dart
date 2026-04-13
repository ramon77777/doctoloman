import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/professional_schedule_local_datasource.dart';
import '../../data/datasources/professional_schedule_remote_datasource.dart';
import '../../data/professional_schedule_local_storage.dart';
import '../../data/repositories/professional_schedule_repository_impl.dart';
import '../../domain/professional_schedule.dart';
import '../../domain/professional_schedule_repository.dart';

final professionalScheduleLocalStorageProvider =
    Provider<ProfessionalScheduleLocalStorage>(
  (ref) => ProfessionalScheduleLocalStorage(
    ref.watch(sharedPreferencesProvider),
  ),
  name: 'professionalScheduleLocalStorageProvider',
);

final professionalScheduleLocalDataSourceProvider =
    Provider<ProfessionalScheduleLocalDataSource>(
  (ref) => ProfessionalScheduleLocalDataSource(
    ref.watch(professionalScheduleLocalStorageProvider),
  ),
  name: 'professionalScheduleLocalDataSourceProvider',
);

final professionalScheduleRemoteDataSourceProvider =
    Provider<ProfessionalScheduleRemoteDataSource>(
  (ref) => const FakeProfessionalScheduleRemoteDataSource(),
  name: 'professionalScheduleRemoteDataSourceProvider',
);

final professionalScheduleRepositoryProvider =
    Provider<ProfessionalScheduleRepository>(
  (ref) => ProfessionalScheduleRepositoryImpl(
    local: ref.watch(professionalScheduleLocalDataSourceProvider),
    remote: ref.watch(professionalScheduleRemoteDataSourceProvider),
  ),
  name: 'professionalScheduleRepositoryProvider',
);

final practitionerScheduleProvider =
    Provider.family<List<DaySchedule>, String>((ref, practitionerId) {
  final schedulesByPractitioner = ref.watch(professionalSchedulesMapProvider);
  final normalizedPractitionerId = practitionerId.trim();

  final resolved = schedulesByPractitioner[normalizedPractitionerId];
  if (resolved != null && resolved.isNotEmpty) {
    return _cloneSchedule(resolved);
  }

  return _cloneSchedule(ProfessionalScheduleController.defaultSchedule);
}, name: 'practitionerScheduleProvider');

final professionalSchedulesMapProvider = StateNotifierProvider<
    ProfessionalScheduleController, Map<String, List<DaySchedule>>>(
  (ref) {
    final repository = ref.watch(professionalScheduleRepositoryProvider);
    final authUser = ref.watch(authControllerProvider).user;

    return ProfessionalScheduleController(
      repository,
      authUser: authUser,
    );
  },
  name: 'professionalSchedulesMapProvider',
);

class ProfessionalScheduleController
    extends StateNotifier<Map<String, List<DaySchedule>>> {
  ProfessionalScheduleController(
    this._repository, {
    required AppUser? authUser,
  })  : _authUser = authUser,
        super(_initialState(authUser)) {
    _bootstrap();
  }

  final ProfessionalScheduleRepository _repository;
  final AppUser? _authUser;

  static final List<DaySchedule> defaultSchedule =
      _cloneSchedule(defaultProfessionalSchedule);

  static Map<String, List<DaySchedule>> _initialState(AppUser? authUser) {
    final result = <String, List<DaySchedule>>{
      defaultPractitionerId: _cloneSchedule(defaultProfessionalSchedule),
    };

    final currentProfessionalId = _resolveCurrentProfessionalId(authUser);
    if (currentProfessionalId != null && currentProfessionalId.isNotEmpty) {
      result[currentProfessionalId] = _cloneSchedule(defaultProfessionalSchedule);
    }

    return Map<String, List<DaySchedule>>.unmodifiable(result);
  }

  Future<void> _bootstrap() async {
    final loaded = await _repository.readAll(
      currentProfessionalId: _resolveCurrentProfessionalId(_authUser),
    );
    state = loaded;
  }

  List<DaySchedule> scheduleFor(String practitionerId) {
    final normalizedPractitionerId = practitionerId.trim();
    if (normalizedPractitionerId.isEmpty) {
      return _cloneSchedule(defaultSchedule);
    }

    final existing = state[normalizedPractitionerId];
    if (existing != null && existing.isNotEmpty) {
      return _cloneSchedule(existing);
    }

    return _cloneSchedule(defaultSchedule);
  }

  Future<void> toggleDay(String practitionerId, int weekday, bool open) async {
    final normalizedPractitionerId = practitionerId.trim();
    final current = scheduleFor(normalizedPractitionerId);

    final next = [
      for (final day in current)
        if (day.weekday == weekday)
          day.copyWith(
            isOpen: open,
            clearSlots: !open,
          )
        else
          day,
    ];

    await _replacePractitionerSchedule(normalizedPractitionerId, next);
  }

  Future<void> addSlot({
    required String practitionerId,
    required int weekday,
    required TimeSlot slot,
  }) async {
    final normalizedPractitionerId = practitionerId.trim();
    final current = scheduleFor(normalizedPractitionerId);

    final next = [
      for (final day in current)
        if (day.weekday == weekday)
          day.copyWith(
            isOpen: true,
            slots: [...day.slots, slot],
          )
        else
          day,
    ];

    await _replacePractitionerSchedule(normalizedPractitionerId, next);
  }

  Future<void> updateSlot({
    required String practitionerId,
    required int weekday,
    required int? slotIndex,
    required TimeSlot slot,
  }) async {
    final normalizedPractitionerId = practitionerId.trim();
    final current = scheduleFor(normalizedPractitionerId);

    final next = [
      for (final day in current)
        if (day.weekday == weekday)
          day.copyWith(
            isOpen: true,
            slots: replaceScheduleSlot(day.slots, slotIndex, slot),
          )
        else
          day,
    ];

    await _replacePractitionerSchedule(normalizedPractitionerId, next);
  }

  Future<void> removeSlot({
    required String practitionerId,
    required int weekday,
    required int? slotIndex,
  }) async {
    final normalizedPractitionerId = practitionerId.trim();
    final current = scheduleFor(normalizedPractitionerId);

    final next = [
      for (final day in current)
        if (day.weekday == weekday)
          day.copyWith(
            slots: removeScheduleSlot(day.slots, slotIndex),
          )
        else
          day,
    ];

    await _replacePractitionerSchedule(normalizedPractitionerId, next);
  }

  Future<void> resetDefaults(String practitionerId) async {
    final updated = await _repository.resetDefaults(
      practitionerId: practitionerId,
      currentProfessionalId: _resolveCurrentProfessionalId(_authUser),
    );
    state = updated;
  }

  Future<void> _replacePractitionerSchedule(
    String practitionerId,
    List<DaySchedule> next,
  ) async {
    final updated = await _repository.replaceSchedule(
      practitionerId: practitionerId,
      schedule: next,
      currentProfessionalId: _resolveCurrentProfessionalId(_authUser),
    );

    state = updated;
  }

  static String? _resolveCurrentProfessionalId(AppUser? authUser) {
    if (authUser == null || !authUser.isProfessional) {
      return null;
    }

    final normalizedId = authUser.id.trim();
    if (normalizedId.isNotEmpty) {
      return normalizedId;
    }

    return null;
  }
}

List<DaySchedule> _cloneSchedule(List<DaySchedule> input) {
  return List<DaySchedule>.unmodifiable(
    input
        .map(
          (day) => day.copyWith(
            slots: List<TimeSlot>.unmodifiable(
              day.slots.map((slot) => slot.copyWith()).toList(),
            ),
          ),
        )
        .toList(),
  );
}
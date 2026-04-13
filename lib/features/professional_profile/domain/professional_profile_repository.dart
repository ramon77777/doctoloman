import 'professional_profile.dart';

abstract class ProfessionalProfileRepository {
  Future<ProfessionalProfile> getCurrent({
    required String? currentUserId,
    required String? currentUserName,
    required String? currentUserPhone,
    required bool isProfessional,
  });

  Future<List<ProfessionalProfile>> getAll();

  Future<void> saveCurrent(
    ProfessionalProfile profile, {
    required String? currentUserId,
    required String? currentUserName,
    required String? currentUserPhone,
    required bool isProfessional,
  });

  Future<void> resetCurrent({
    required String? currentUserId,
    required String? currentUserName,
    required String? currentUserPhone,
    required bool isProfessional,
  });
}
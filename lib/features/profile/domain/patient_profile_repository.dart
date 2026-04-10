import 'patient_profile.dart';

abstract class PatientProfileRepository {
  Future<PatientProfile?> get({String? phone});

  Future<void> save(PatientProfile profile);

  Future<void> clear({String? phone});
}
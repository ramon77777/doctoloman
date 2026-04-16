import 'package:flutter/foundation.dart';

import '../../features/search/domain/search_item.dart';

@immutable
class LoginPhoneArgs {
  const LoginPhoneArgs({
    this.isSignup = false,
  });

  final bool isSignup;
}

@immutable
class SearchResultsArgs {
  const SearchResultsArgs({
    required this.initialWhat,
    required this.initialWhere,
  });

  final String initialWhat;
  final String initialWhere;
}

@immutable
class MedicalRecordEditArgs {
  const MedicalRecordEditArgs({
    required this.recordId,
  });

  final String recordId;
}

@immutable
class PractitionerDetailArgs {
  const PractitionerDetailArgs({
    required this.item,
  });

  final SearchItem item;
}

@immutable
class PharmacyDetailArgs {
  const PharmacyDetailArgs({
    required this.pharmacyId,
  });

  final String pharmacyId;
}

@immutable
class AppointmentDetailArgs {
  const AppointmentDetailArgs({
    required this.appointmentId,
  });

  final String appointmentId;
}

@immutable
class MedicalRecordDetailArgs {
  const MedicalRecordDetailArgs({
    required this.recordId,
  });

  final String recordId;
}

@immutable
class ProfessionalAppointmentDetailArgs {
  const ProfessionalAppointmentDetailArgs({
    required this.appointmentId,
  });

  final String appointmentId;
}

@immutable
class ProfessionalPatientMedicalRecordsArgs {
  const ProfessionalPatientMedicalRecordsArgs({
    required this.patientId,
    required this.patientName,
  });

  final String patientId;
  final String patientName;
}

@immutable
class ProfessionalAppointmentReportArgs {
  const ProfessionalAppointmentReportArgs({
    required this.appointmentId,
  });

  final String appointmentId;
}
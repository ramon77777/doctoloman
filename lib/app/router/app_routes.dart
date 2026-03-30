import 'package:flutter/material.dart';

import '../../features/appointments/presentation/pages/appointments_page.dart';
import '../../features/home/presentation/pages/home_entry_page.dart';
import '../../features/medical_records/presentation/pages/medical_records_page.dart';
import '../../features/medical_records/presentation/pages/medical_record_create_page.dart';
import '../../features/pharmacies/presentation/pages/pharmacies_on_duty_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/profile_edit_page.dart';
import '../../features/professional_appointments/presentation/pages/professional_appointments_page.dart';
import '../../features/professional_home/presentation/pages/professional_home_page.dart';
import '../../features/professional_profile/presentation/pages/professional_profile_edit_page.dart';
import '../../features/professional_profile/presentation/pages/professional_profile_page.dart';
import '../../features/professional_schedule/presentation/pages/professional_schedule_page.dart';

class AppRoutes {
  static const home = '/';
  static const loginPhone = '/auth/phone';
  static const profile = '/profile';
  static const profileEdit = '/profile/edit';

  static const searchResults = '/search/results';
  static const practitionerDetail = '/practitioner/detail';

  static const pharmacies = '/pharmacies';
  static const pharmaciesOnDuty = '/pharmacies/on-duty';
  static const pharmacyDetail = '/pharmacies/detail';

  static const appointments = '/appointments';
  static const appointmentDetail = '/appointments/detail';

  static const medicalRecords = '/medical-records';
  static const medicalRecordDetail = '/medical-records/detail';
  static const medicalRecordCreate = '/medical-records/create';
  static const medicalRecordEdit = '/medical-records/edit';
  

  static const professionalHome = '/professional';
  static const professionalAppointments = '/professional/appointments';
  static const professionalAppointmentDetail = '/professional/appointments/detail';
  static const professionalProfile = '/professional/profile';
  static const professionalSchedule = '/professional/schedule';
  static const professionalProfileEdit = '/professional/profile/edit';

  static Map<String, WidgetBuilder> staticRoutes() {
    return {
      home: (_) => const HomeEntryPage(),
      pharmacies: (_) => const PharmaciesPage(),
      pharmaciesOnDuty: (_) => const PharmaciesPage(initialOnDutyOnly: true),
      appointments: (_) => const AppointmentsPage(),
      profile: (_) => const ProfilePage(),
      profileEdit: (_) => const ProfileEditPage(),
      medicalRecords: (_) => const MedicalRecordsPage(),
      medicalRecordEdit: (_) => const Scaffold(),
      professionalHome: (_) => const ProfessionalHomePage(),
      professionalAppointments: (_) => const ProfessionalAppointmentsPage(),
      professionalProfile: (_) => const ProfessionalProfilePage(),
      professionalSchedule: (_) => const ProfessionalSchedulePage(),
      professionalProfileEdit: (_) => const ProfessionalProfileEditPage(),
      medicalRecordCreate: (_) => const MedicalRecordCreatePage(),
    };
  }
}
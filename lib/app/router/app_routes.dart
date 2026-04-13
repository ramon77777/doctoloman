import 'package:flutter/material.dart';

import '../../features/appointments/presentation/pages/appointments_page.dart';
import '../../features/home/presentation/pages/home_entry_page.dart';
import '../../features/medical_records/presentation/pages/medical_record_create_page.dart';
import '../../features/medical_records/presentation/pages/medical_records_page.dart';
import '../../features/pharmacies/presentation/pages/pharmacies_on_duty_page.dart';
import '../../features/profile/presentation/pages/profile_edit_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/professional_appointments/presentation/pages/professional_appointments_page.dart';
import '../../features/professional_home/presentation/pages/professional_home_page.dart';
import '../../features/professional_profile/presentation/pages/professional_profile_edit_page.dart';
import '../../features/professional_profile/presentation/pages/professional_profile_page.dart';
import '../../features/professional_schedule/presentation/pages/professional_schedule_page.dart';
import 'route_guards.dart';

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
  static const professionalAppointmentDetail =
      '/professional/appointments/detail';
  static const professionalProfile = '/professional/profile';
  static const professionalSchedule = '/professional/schedule';
  static const professionalProfileEdit = '/professional/profile/edit';

  static Map<String, WidgetBuilder> staticRoutes() {
    return {
      home: (_) => const HomeEntryPage(),

      pharmacies: (_) => const RouteGuard(
            access: AppRouteAccess.public,
            child: PharmaciesPage(),
          ),
      pharmaciesOnDuty: (_) => const RouteGuard(
            access: AppRouteAccess.public,
            child: PharmaciesPage(initialOnDutyOnly: true),
          ),

      appointments: (_) => const RouteGuard(
            access: AppRouteAccess.patientOnly,
            child: AppointmentsPage(),
          ),
      profile: (_) => const RouteGuard(
            access: AppRouteAccess.patientOnly,
            child: ProfilePage(),
          ),
      profileEdit: (_) => const RouteGuard(
            access: AppRouteAccess.patientOnly,
            child: ProfileEditPage(),
          ),

      medicalRecords: (_) => const RouteGuard(
            access: AppRouteAccess.patientOnly,
            child: MedicalRecordsPage(),
          ),
      medicalRecordCreate: (_) => const RouteGuard(
            access: AppRouteAccess.patientOnly,
            child: MedicalRecordCreatePage(),
          ),

      professionalHome: (_) => const RouteGuard(
            access: AppRouteAccess.professionalOnly,
            child: ProfessionalHomePage(),
          ),
      professionalAppointments: (_) => const RouteGuard(
            access: AppRouteAccess.professionalOnly,
            child: ProfessionalAppointmentsPage(),
          ),
      professionalProfile: (_) => const RouteGuard(
            access: AppRouteAccess.professionalOnly,
            child: ProfessionalProfilePage(),
          ),
      professionalSchedule: (_) => const RouteGuard(
            access: AppRouteAccess.professionalOnly,
            child: ProfessionalSchedulePage(),
          ),
      professionalProfileEdit: (_) => const RouteGuard(
            access: AppRouteAccess.professionalOnly,
            child: ProfessionalProfileEditPage(),
          ),
    };
  }
}
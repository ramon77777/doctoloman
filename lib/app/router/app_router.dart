import 'package:flutter/material.dart';

import '../../features/appointment_reports/presentation/pages/professional_appointment_report_page.dart'
    as professional_report_page;
import '../../features/appointments/presentation/pages/appointment_detail_page.dart'
    as patient_appointment_page;
import '../../features/appointments/presentation/pages/appointments_page.dart';
import '../../features/auth/presentation/pages/login_phone_page.dart';
import '../../features/home/presentation/pages/home_entry_page.dart';
import '../../features/home/presentation/pages/home_public_page.dart';
import '../../features/medical_access/presentation/pages/medical_access_audit_history_page.dart';
import '../../features/medical_records/presentation/pages/medical_record_detail_page.dart';
import '../../features/medical_records/presentation/pages/medical_record_edit_page.dart';
import '../../features/medical_records/presentation/pages/medical_records_page.dart';
import '../../features/medical_records/presentation/pages/professional_patient_medical_records_page.dart';
import '../../features/pharmacies/presentation/pages/pharmacy_detail_page.dart';
import '../../features/professional_appointments/presentation/pages/professional_appointment_detail_page.dart'
    as professional_appointment_page;
import '../../features/professional_appointments/presentation/pages/professional_appointments_page.dart';
import '../../features/search/presentation/pages/practitioner_detail_page.dart';
import '../../features/search/presentation/pages/search_results_page.dart';
import 'app_routes.dart';
import 'route_args.dart';
import 'route_guards.dart';

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.loginPhone:
        return _buildLoginPhoneRoute(settings);
      case AppRoutes.searchResults:
        return _buildSearchResultsRoute(settings);
      case AppRoutes.practitionerDetail:
        return _buildPractitionerDetailRoute(settings);
      case AppRoutes.pharmacyDetail:
        return _buildPharmacyDetailRoute(settings);
      case AppRoutes.appointmentDetail:
        return _buildAppointmentDetailRoute(settings);
      case AppRoutes.medicalRecordDetail:
        return _buildMedicalRecordDetailRoute(settings);
      case AppRoutes.medicalRecordEdit:
        return _buildMedicalRecordEditRoute(settings);
      case AppRoutes.professionalAppointmentDetail:
        return _buildProfessionalAppointmentDetailRoute(settings);
      case AppRoutes.professionalPatientMedicalRecords:
        return _buildProfessionalPatientMedicalRecordsRoute(settings);
      case AppRoutes.professionalAppointmentReport:
        return _buildProfessionalAppointmentReportRoute(settings);
      case AppRoutes.medicalAccessAuditHistory:
        return _buildMedicalAccessAuditHistoryRoute(settings);
      default:
        return fadeRoute(
          const HomeEntryPage(),
          settings: settings,
        );
    }
  }

  static Route<dynamic> onUnknownRoute(RouteSettings settings) {
    return fadeRoute(
      const HomePublicPage(),
      settings: settings,
    );
  }

  static Route<dynamic> _buildLoginPhoneRoute(RouteSettings settings) {
    final args = settings.arguments;

    final isSignup = switch (args) {
      LoginPhoneArgs value => value.isSignup,
      Map value when value['isSignup'] is bool => value['isSignup'] as bool,
      _ => false,
    };

    return fadeRoute(
      RouteGuard(
        access: AppRouteAccess.unauthenticatedOnly,
        child: LoginPhonePage(isSignup: isSignup),
      ),
      settings: settings,
    );
  }

  static Route<dynamic> _buildSearchResultsRoute(RouteSettings settings) {
    final args = settings.arguments;
    if (args is! SearchResultsArgs) {
      return fadeRoute(
        const HomeEntryPage(),
        settings: settings,
      );
    }

    return fadeRoute(
      RouteGuard(
        access: AppRouteAccess.public,
        child: SearchResultsPage(
          initialWhat: args.initialWhat,
          initialWhere: args.initialWhere,
        ),
      ),
      settings: settings,
    );
  }

  static Route<dynamic> _buildPractitionerDetailRoute(RouteSettings settings) {
    final args = settings.arguments;
    if (args is! PractitionerDetailArgs) {
      return fadeRoute(
        const HomeEntryPage(),
        settings: settings,
      );
    }

    return fadeRoute(
      RouteGuard(
        access: AppRouteAccess.public,
        child: PractitionerDetailPage(item: args.item),
      ),
      settings: settings,
    );
  }

  static Route<dynamic> _buildPharmacyDetailRoute(RouteSettings settings) {
    final args = settings.arguments;
    if (args is! PharmacyDetailArgs) {
      return fadeRoute(
        const HomeEntryPage(),
        settings: settings,
      );
    }

    return fadeRoute(
      RouteGuard(
        access: AppRouteAccess.public,
        child: PharmacyDetailPage(pharmacyId: args.pharmacyId),
      ),
      settings: settings,
    );
  }

  static Route<dynamic> _buildAppointmentDetailRoute(RouteSettings settings) {
    final args = settings.arguments;
    if (args is! AppointmentDetailArgs) {
      return fadeRoute(
        const RouteGuard(
          access: AppRouteAccess.patientOnly,
          child: AppointmentsPage(),
        ),
        settings: settings,
      );
    }

    return fadeRoute(
      RouteGuard(
        access: AppRouteAccess.patientOnly,
        child: patient_appointment_page.AppointmentDetailPage(
          appointmentId: args.appointmentId,
        ),
      ),
      settings: settings,
    );
  }

  static Route<dynamic> _buildMedicalRecordDetailRoute(RouteSettings settings) {
    final args = settings.arguments;
    if (args is! MedicalRecordDetailArgs) {
      return fadeRoute(
        const RouteGuard(
          access: AppRouteAccess.patientOnly,
          child: MedicalRecordsPage(),
        ),
        settings: settings,
      );
    }

    return fadeRoute(
      RouteGuard(
        access: AppRouteAccess.patientOnly,
        child: MedicalRecordDetailPage(recordId: args.recordId),
      ),
      settings: settings,
    );
  }

  static Route<dynamic> _buildMedicalRecordEditRoute(RouteSettings settings) {
    final args = settings.arguments;
    if (args is! MedicalRecordEditArgs) {
      return fadeRoute(
        const RouteGuard(
          access: AppRouteAccess.patientOnly,
          child: MedicalRecordsPage(),
        ),
        settings: settings,
      );
    }

    return fadeRoute(
      RouteGuard(
        access: AppRouteAccess.patientOnly,
        child: MedicalRecordEditPage(recordId: args.recordId),
      ),
      settings: settings,
    );
  }

  static Route<dynamic> _buildProfessionalAppointmentDetailRoute(
    RouteSettings settings,
  ) {
    final args = settings.arguments;
    if (args is! ProfessionalAppointmentDetailArgs) {
      return fadeRoute(
        const RouteGuard(
          access: AppRouteAccess.professionalOnly,
          child: ProfessionalAppointmentsPage(),
        ),
        settings: settings,
      );
    }

    return fadeRoute(
      RouteGuard(
        access: AppRouteAccess.professionalOnly,
        child: professional_appointment_page.ProfessionalAppointmentDetailPage(
          appointmentId: args.appointmentId,
        ),
      ),
      settings: settings,
    );
  }

  static Route<dynamic> _buildProfessionalPatientMedicalRecordsRoute(
    RouteSettings settings,
  ) {
    final args = settings.arguments;
    if (args is! ProfessionalPatientMedicalRecordsArgs) {
      return fadeRoute(
        const HomeEntryPage(),
        settings: settings,
      );
    }

    return fadeRoute(
      RouteGuard(
        access: AppRouteAccess.professionalOnly,
        child: ProfessionalPatientMedicalRecordsPage(
          patientId: args.patientId,
          patientName: args.patientName,
        ),
      ),
      settings: settings,
    );
  }

  static Route<dynamic> _buildProfessionalAppointmentReportRoute(
    RouteSettings settings,
  ) {
    final args = settings.arguments;
    if (args is! ProfessionalAppointmentReportArgs) {
      return fadeRoute(
        const RouteGuard(
          access: AppRouteAccess.professionalOnly,
          child: ProfessionalAppointmentsPage(),
        ),
        settings: settings,
      );
    }

    return fadeRoute(
      RouteGuard(
        access: AppRouteAccess.professionalOnly,
        child: professional_report_page.ProfessionalAppointmentReportPage(
          appointmentId: args.appointmentId,
        ),
      ),
      settings: settings,
    );
  }

  static Route<dynamic> _buildMedicalAccessAuditHistoryRoute(
    RouteSettings settings,
  ) {
    return fadeRoute(
      const RouteGuard(
        access: AppRouteAccess.patientOnly,
        child: MedicalAccessAuditHistoryPage(),
      ),
      settings: settings,
    );
  }

  static PageRouteBuilder<T> fadeRoute<T>(
    Widget child, {
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 150),
    );
  }
}
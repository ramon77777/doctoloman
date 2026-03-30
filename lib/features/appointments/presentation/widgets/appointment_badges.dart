import 'package:flutter/material.dart';

import '../../../../core/formatters/app_date_formatters.dart';
import '../../domain/appointment.dart';
import '../helpers/appointment_ui_helpers.dart';

class AppointmentStatusBadge extends StatelessWidget {
  const AppointmentStatusBadge({
    super.key,
    required this.status,
    this.isProfessional = false,
  });

  final AppointmentStatus status;
  final bool isProfessional;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = _statusBadgeStyle(status, scheme);

    final label = isProfessional
        ? AppointmentUiHelpers.professionalStatusBadgeLabel(status)
        : AppointmentUiHelpers.shortStatusBadgeLabel(status);

    return _BaseBadge(
      label: label,
      backgroundColor: style.backgroundColor,
      foregroundColor: style.foregroundColor,
      fontWeight: FontWeight.w700,
    );
  }
}

class AppointmentMiniBadge extends StatelessWidget {
  const AppointmentMiniBadge({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return _BaseBadge(
      label: label,
      backgroundColor: scheme.surfaceContainerHighest,
      foregroundColor: scheme.onSurface,
      fontWeight: FontWeight.w600,
    );
  }
}

class AppointmentTemporalBadge extends StatelessWidget {
  const AppointmentTemporalBadge({
    super.key,
    required this.appointment,
    this.isProfessional = false,
  });

  final Appointment appointment;
  final bool isProfessional;

  @override
  Widget build(BuildContext context) {
    final label = isProfessional
        ? AppointmentUiHelpers.professionalTemporalLabel(appointment)
        : AppointmentUiHelpers.temporalLabel(appointment);

    return AppointmentMiniBadge(label: label);
  }
}

class AppointmentDayHintBadge extends StatelessWidget {
  const AppointmentDayHintBadge({
    super.key,
    required this.appointment,
  });

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    if (appointment.status != AppointmentStatus.confirmed) {
      return const SizedBox.shrink();
    }

    if (AppDateFormatters.isToday(appointment.scheduledAt)) {
      return const AppointmentMiniBadge(label: 'Aujourd’hui');
    }

    if (AppDateFormatters.isTomorrow(appointment.scheduledAt)) {
      return const AppointmentMiniBadge(label: 'Demain');
    }

    return const SizedBox.shrink();
  }
}

@immutable
class _BadgeVisualStyle {
  const _BadgeVisualStyle({
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final Color backgroundColor;
  final Color foregroundColor;
}

_BadgeVisualStyle _statusBadgeStyle(
  AppointmentStatus status,
  ColorScheme scheme,
) {
  switch (status) {
    case AppointmentStatus.pending:
      return _BadgeVisualStyle(
        backgroundColor: scheme.secondaryContainer,
        foregroundColor: scheme.onSecondaryContainer,
      );
    case AppointmentStatus.confirmed:
      return _BadgeVisualStyle(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
      );
    case AppointmentStatus.cancelledByPatient:
    case AppointmentStatus.declinedByProfessional:
      return _BadgeVisualStyle(
        backgroundColor: scheme.errorContainer,
        foregroundColor: scheme.onErrorContainer,
      );
  }
}

class _BaseBadge extends StatelessWidget {
  const _BaseBadge({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.fontWeight,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontWeight: fontWeight,
        ),
      ),
    );
  }
}
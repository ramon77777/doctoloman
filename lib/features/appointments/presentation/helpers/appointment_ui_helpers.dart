import '../../../../core/formatters/app_date_formatters.dart';
import '../../domain/appointment.dart';

class AppointmentUiHelpers {
  static String statusLabel(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.pending:
        return 'Demande envoyée • en attente de réponse';
      case AppointmentStatus.confirmed:
        return 'Confirmé par le professionnel';
      case AppointmentStatus.cancelledByPatient:
        return 'Annulé par vous';
      case AppointmentStatus.cancelledByProfessional:
        return 'Annulé par le professionnel';
      case AppointmentStatus.declinedByProfessional:
        return 'Refusé par le professionnel';
      case AppointmentStatus.completed:
        return 'Rendez-vous réalisé';
      case AppointmentStatus.noShow:
        return 'Patient absent';
    }
  }

  static String shortStatusBadgeLabel(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.pending:
        return 'En attente';
      case AppointmentStatus.confirmed:
        return 'Confirmé';
      case AppointmentStatus.cancelledByPatient:
        return 'Annulé';
      case AppointmentStatus.cancelledByProfessional:
        return 'Annulé';
      case AppointmentStatus.declinedByProfessional:
        return 'Refusé';
      case AppointmentStatus.completed:
        return 'Réalisé';
      case AppointmentStatus.noShow:
        return 'Absent';
    }
  }

  static String professionalStatusBadgeLabel(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.pending:
        return 'En attente';
      case AppointmentStatus.confirmed:
        return 'Confirmé';
      case AppointmentStatus.cancelledByPatient:
        return 'Annulé patient';
      case AppointmentStatus.cancelledByProfessional:
        return 'Annulé pro';
      case AppointmentStatus.declinedByProfessional:
        return 'Refusé';
      case AppointmentStatus.completed:
        return 'Réalisé';
      case AppointmentStatus.noShow:
        return 'Patient absent';
    }
  }

  static String temporalLabel(Appointment appointment) {
    switch (appointment.status) {
      case AppointmentStatus.pending:
        return 'Réponse attendue';
      case AppointmentStatus.confirmed:
        return appointment.isUpcoming ? 'À venir' : 'Passé';
      case AppointmentStatus.cancelledByPatient:
        return 'Annulé';
      case AppointmentStatus.cancelledByProfessional:
        return 'Annulé';
      case AppointmentStatus.declinedByProfessional:
        return 'Refusé';
      case AppointmentStatus.completed:
        return 'Réalisé';
      case AppointmentStatus.noShow:
        return 'Absent';
    }
  }

  static String professionalTemporalLabel(Appointment appointment) {
    switch (appointment.status) {
      case AppointmentStatus.pending:
        return 'À traiter';
      case AppointmentStatus.confirmed:
        return appointment.isUpcoming ? 'À venir' : 'À clôturer';
      case AppointmentStatus.cancelledByPatient:
        return 'Annulé patient';
      case AppointmentStatus.cancelledByProfessional:
        return 'Annulé pro';
      case AppointmentStatus.declinedByProfessional:
        return 'Clos';
      case AppointmentStatus.completed:
        return 'Réalisé';
      case AppointmentStatus.noShow:
        return 'Absence';
    }
  }

  static String patientReminderTitle(Appointment appointment) {
    switch (appointment.status) {
      case AppointmentStatus.cancelledByPatient:
        return 'Rendez-vous annulé';
      case AppointmentStatus.cancelledByProfessional:
        return 'Rendez-vous annulé par le professionnel';
      case AppointmentStatus.declinedByProfessional:
        return 'Demande refusée';
      case AppointmentStatus.completed:
        return 'Rendez-vous réalisé';
      case AppointmentStatus.noShow:
        return 'Absence signalée';
      case AppointmentStatus.pending:
        return 'Réponse du professionnel attendue';
      case AppointmentStatus.confirmed:
        return appointment.isUpcoming
            ? 'Rendez-vous confirmé'
            : 'Rendez-vous passé';
    }
  }

  static String patientReminderSubtitle(Appointment appointment) {
    switch (appointment.status) {
      case AppointmentStatus.cancelledByPatient:
        return 'Vous avez annulé cette demande ou ce rendez-vous.';
      case AppointmentStatus.cancelledByProfessional:
        return 'Le professionnel a annulé ce rendez-vous. Vous pouvez reprendre un autre rendez-vous si nécessaire.';
      case AppointmentStatus.declinedByProfessional:
        return 'Le professionnel n’a pas retenu cette demande de rendez-vous.';
      case AppointmentStatus.completed:
        return 'Ce rendez-vous a été marqué comme réalisé.';
      case AppointmentStatus.noShow:
        return 'Le professionnel a signalé que vous ne vous êtes pas présenté à ce rendez-vous.';
      case AppointmentStatus.pending:
        return 'Votre demande a bien été envoyée. Le professionnel doit encore vous répondre.';
      case AppointmentStatus.confirmed:
        if (!appointment.isUpcoming) {
          return 'Ce rendez-vous est déjà passé. Le professionnel peut encore le clôturer.';
        }
        if (AppDateFormatters.isToday(appointment.scheduledAt)) {
          return 'Votre rendez-vous confirmé a lieu aujourd’hui.';
        }
        if (AppDateFormatters.isTomorrow(appointment.scheduledAt)) {
          return 'Votre rendez-vous confirmé a lieu demain.';
        }
        return 'Votre rendez-vous a été confirmé par le professionnel.';
    }
  }

  static String professionalActionTitle(Appointment appointment) {
    switch (appointment.status) {
      case AppointmentStatus.pending:
        return 'Action requise';
      case AppointmentStatus.confirmed:
        return appointment.isUpcoming
            ? 'Rendez-vous confirmé'
            : 'Rendez-vous à clôturer';
      case AppointmentStatus.cancelledByPatient:
        return 'Annulé par le patient';
      case AppointmentStatus.cancelledByProfessional:
        return 'Annulé par vous';
      case AppointmentStatus.declinedByProfessional:
        return 'Demande refusée';
      case AppointmentStatus.completed:
        return 'Consultation réalisée';
      case AppointmentStatus.noShow:
        return 'Patient absent';
    }
  }

  static String professionalActionMessage(Appointment appointment) {
    switch (appointment.status) {
      case AppointmentStatus.pending:
        return 'Cette demande attend votre validation. Vous pouvez la confirmer ou la refuser.';
      case AppointmentStatus.confirmed:
        return appointment.isUpcoming
            ? 'Ce rendez-vous est confirmé. Vous pouvez encore l’annuler si nécessaire.'
            : 'Ce rendez-vous est passé. Vous pouvez le marquer comme réalisé ou signaler une absence.';
      case AppointmentStatus.cancelledByPatient:
        return 'Le patient a annulé cette demande ou ce rendez-vous.';
      case AppointmentStatus.cancelledByProfessional:
        return 'Vous avez annulé ce rendez-vous. Aucune autre action n’est disponible.';
      case AppointmentStatus.declinedByProfessional:
        return 'Vous avez refusé cette demande. Aucune autre action n’est disponible.';
      case AppointmentStatus.completed:
        return 'Ce rendez-vous est clôturé comme réalisé. Le compte rendu peut être consulté ou complété selon le parcours prévu.';
      case AppointmentStatus.noShow:
        return 'Ce rendez-vous est clôturé avec une absence patient.';
    }
  }

  static bool canPatientCancel(Appointment appointment) {
    return appointment.canBeCancelledByPatient && appointment.isUpcoming;
  }

  static bool canPatientReschedule(Appointment appointment) {
    return appointment.status == AppointmentStatus.confirmed &&
        appointment.isUpcoming;
  }

  static bool canProfessionalConfirm(Appointment appointment) {
    return appointment.canBeConfirmed;
  }

  static bool canProfessionalDecline(Appointment appointment) {
    return appointment.canBeDeclined;
  }

  static bool canProfessionalCancelConfirmed(Appointment appointment) {
    return appointment.canBeCancelledByProfessional && appointment.isUpcoming;
  }

  static bool canProfessionalComplete(Appointment appointment) {
    return appointment.canBeCompleted && appointment.isPast;
  }

  static bool canProfessionalMarkNoShow(Appointment appointment) {
    return appointment.canBeMarkedNoShow && appointment.isPast;
  }

  static bool isPending(Appointment appointment) {
    return appointment.status == AppointmentStatus.pending;
  }

  static bool isUpcomingConfirmed(Appointment appointment) {
    return appointment.status == AppointmentStatus.confirmed &&
        appointment.isUpcoming;
  }

  static bool isHistory(Appointment appointment) {
    return appointment.status == AppointmentStatus.confirmed &&
        !appointment.isUpcoming;
  }

  static bool isCompleted(Appointment appointment) {
    return appointment.status == AppointmentStatus.completed;
  }

  static bool isNoShow(Appointment appointment) {
    return appointment.status == AppointmentStatus.noShow;
  }

  static bool isClosed(Appointment appointment) {
    return appointment.isClosed;
  }

  static String patientSectionLabel(Appointment appointment) {
    if (isPending(appointment)) {
      return 'En attente';
    }
    if (isUpcomingConfirmed(appointment)) {
      return 'À venir';
    }
    if (isHistory(appointment) || isCompleted(appointment)) {
      return 'Historique';
    }
    return 'Clos';
  }

  static String professionalSectionLabel(Appointment appointment) {
    if (isPending(appointment)) {
      return 'À traiter';
    }
    if (isUpcomingConfirmed(appointment)) {
      return 'À venir';
    }
    if (appointment.status == AppointmentStatus.confirmed &&
        appointment.isPast) {
      return 'À clôturer';
    }
    if (isCompleted(appointment)) {
      return 'Réalisés';
    }
    if (isNoShow(appointment)) {
      return 'Absences';
    }
    return 'Clos';
  }
}
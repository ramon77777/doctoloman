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
      case AppointmentStatus.declinedByProfessional:
        return 'Refusé par le professionnel';
    }
  }

  static String shortStatusBadgeLabel(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.pending:
        return 'Demande envoyée';
      case AppointmentStatus.confirmed:
        return 'Confirmé';
      case AppointmentStatus.cancelledByPatient:
        return 'Annulé';
      case AppointmentStatus.declinedByProfessional:
        return 'Refusé';
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
      case AppointmentStatus.declinedByProfessional:
        return 'Refusé';
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
      case AppointmentStatus.declinedByProfessional:
        return 'Refusé';
    }
  }

  static String professionalTemporalLabel(Appointment appointment) {
    switch (appointment.status) {
      case AppointmentStatus.pending:
        return 'À traiter';
      case AppointmentStatus.confirmed:
        return appointment.isUpcoming ? 'À venir' : 'Passé';
      case AppointmentStatus.cancelledByPatient:
        return 'Annulé patient';
      case AppointmentStatus.declinedByProfessional:
        return 'Clos';
    }
  }

  static String patientReminderTitle(Appointment appointment) {
    switch (appointment.status) {
      case AppointmentStatus.cancelledByPatient:
        return 'Rendez-vous annulé';
      case AppointmentStatus.declinedByProfessional:
        return 'Demande refusée';
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
      case AppointmentStatus.declinedByProfessional:
        return 'Le professionnel n’a pas retenu cette demande de rendez-vous.';
      case AppointmentStatus.pending:
        return 'Votre demande a bien été envoyée. Le professionnel doit encore vous répondre.';
      case AppointmentStatus.confirmed:
        if (!appointment.isUpcoming) {
          return 'Ce rendez-vous est déjà passé.';
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
            : 'Rendez-vous clôturé';
      case AppointmentStatus.cancelledByPatient:
        return 'Annulé par le patient';
      case AppointmentStatus.declinedByProfessional:
        return 'Clos côté professionnel';
    }
  }

  static String professionalActionMessage(Appointment appointment) {
    switch (appointment.status) {
      case AppointmentStatus.pending:
        return 'Cette demande attend votre validation. Vous pouvez la confirmer ou la refuser.';
      case AppointmentStatus.confirmed:
        return appointment.isUpcoming
            ? 'Ce rendez-vous est confirmé. Vous pouvez encore l’annuler si nécessaire.'
            : 'Ce rendez-vous est déjà passé.';
      case AppointmentStatus.cancelledByPatient:
        return 'Le patient a annulé cette demande ou ce rendez-vous.';
      case AppointmentStatus.declinedByProfessional:
        return 'Ce dossier a été clôturé côté professionnel. Aucune autre action n’est disponible.';
    }
  }

  static bool canPatientCancel(Appointment appointment) {
    return !appointment.isCancelledLike &&
        (appointment.status == AppointmentStatus.pending ||
            (appointment.status == AppointmentStatus.confirmed &&
                appointment.isUpcoming));
  }

  static bool canPatientReschedule(Appointment appointment) {
    return appointment.status == AppointmentStatus.confirmed &&
        appointment.isUpcoming;
  }

  static bool canProfessionalConfirm(Appointment appointment) {
    return appointment.status == AppointmentStatus.pending;
  }

  static bool canProfessionalDecline(Appointment appointment) {
    return appointment.status == AppointmentStatus.pending;
  }

  static bool canProfessionalCancelConfirmed(Appointment appointment) {
    return appointment.status == AppointmentStatus.confirmed &&
        appointment.isUpcoming;
  }
}
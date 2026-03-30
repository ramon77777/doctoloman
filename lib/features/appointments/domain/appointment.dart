import 'package:flutter/foundation.dart';

enum AppointmentStatus {
  pending,
  confirmed,
  cancelledByPatient,
  declinedByProfessional,
}

@immutable
class Appointment {
  const Appointment({
    required this.id,
    required this.createdAt,
    required this.practitionerId,
    required this.practitionerName,
    required this.specialty,
    required this.address,
    required this.city,
    required this.area,
    required this.day,
    required this.slot,
    required this.reason,
    required this.patientFirstName,
    required this.patientLastName,
    required this.patientPhoneE164,
    required this.consentAccepted,
    required this.consentVersion,
    required this.consentAcceptedAt,
    this.status = AppointmentStatus.confirmed,
  });

  final String id;
  final DateTime createdAt;

  final String practitionerId;
  final String practitionerName;
  final String specialty;

  final String address;
  final String city;
  final String area;

  final DateTime day;
  final String slot;

  final String reason;

  final String patientFirstName;
  final String patientLastName;
  final String patientPhoneE164;

  final bool consentAccepted;
  final String consentVersion;
  final DateTime consentAcceptedAt;

  final AppointmentStatus status;

  String get patientFullName =>
      '${patientFirstName.trim()} ${patientLastName.trim()}'.trim();

  String get practitionerLocationLabel => '$area, $city';

  String get fullAddress {
    final a = address.trim();
    if (a.isEmpty) return practitionerLocationLabel;
    return '$a • $practitionerLocationLabel';
  }

  DateTime get scheduledAt {
    final parts = slot.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    return DateTime(
      day.year,
      day.month,
      day.day,
      hour,
      minute,
    );
  }

  bool get isUpcoming => scheduledAt.isAfter(DateTime.now());
  bool get isPast => scheduledAt.isBefore(DateTime.now());

  bool get isCancelledLike =>
      status == AppointmentStatus.cancelledByPatient ||
      status == AppointmentStatus.declinedByProfessional;

  Appointment copyWith({
    String? id,
    DateTime? createdAt,
    String? practitionerId,
    String? practitionerName,
    String? specialty,
    String? address,
    String? city,
    String? area,
    DateTime? day,
    String? slot,
    String? reason,
    String? patientFirstName,
    String? patientLastName,
    String? patientPhoneE164,
    bool? consentAccepted,
    String? consentVersion,
    DateTime? consentAcceptedAt,
    AppointmentStatus? status,
  }) {
    return Appointment(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      practitionerId: practitionerId ?? this.practitionerId,
      practitionerName: practitionerName ?? this.practitionerName,
      specialty: specialty ?? this.specialty,
      address: address ?? this.address,
      city: city ?? this.city,
      area: area ?? this.area,
      day: day ?? this.day,
      slot: slot ?? this.slot,
      reason: reason ?? this.reason,
      patientFirstName: patientFirstName ?? this.patientFirstName,
      patientLastName: patientLastName ?? this.patientLastName,
      patientPhoneE164: patientPhoneE164 ?? this.patientPhoneE164,
      consentAccepted: consentAccepted ?? this.consentAccepted,
      consentVersion: consentVersion ?? this.consentVersion,
      consentAcceptedAt: consentAcceptedAt ?? this.consentAcceptedAt,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'practitionerId': practitionerId,
      'practitionerName': practitionerName,
      'specialty': specialty,
      'address': address,
      'city': city,
      'area': area,
      'day': day.toIso8601String(),
      'slot': slot,
      'reason': reason,
      'patientFirstName': patientFirstName,
      'patientLastName': patientLastName,
      'patientPhoneE164': patientPhoneE164,
      'consentAccepted': consentAccepted,
      'consentVersion': consentVersion,
      'consentAcceptedAt': consentAcceptedAt.toIso8601String(),
      'status': status.name,
    };
  }

  factory Appointment.fromMap(Map<String, dynamic> map) {
    return Appointment(
      id: (map['id'] as String?) ?? '',
      createdAt: DateTime.parse(
        (map['createdAt'] as String?) ?? DateTime.now().toIso8601String(),
      ),
      practitionerId: (map['practitionerId'] as String?) ?? '',
      practitionerName: (map['practitionerName'] as String?) ?? '',
      specialty: (map['specialty'] as String?) ?? '',
      address: (map['address'] as String?) ?? '',
      city: (map['city'] as String?) ?? '',
      area: (map['area'] as String?) ?? '',
      day: DateTime.parse(
        (map['day'] as String?) ?? DateTime.now().toIso8601String(),
      ),
      slot: (map['slot'] as String?) ?? '',
      reason: (map['reason'] as String?) ?? '',
      patientFirstName: (map['patientFirstName'] as String?) ?? '',
      patientLastName: (map['patientLastName'] as String?) ?? '',
      patientPhoneE164: (map['patientPhoneE164'] as String?) ?? '',
      consentAccepted: (map['consentAccepted'] as bool?) ?? false,
      consentVersion: (map['consentVersion'] as String?) ?? '',
      consentAcceptedAt: DateTime.parse(
        (map['consentAcceptedAt'] as String?) ??
            DateTime.now().toIso8601String(),
      ),
      status: _statusFromString((map['status'] as String?) ?? 'confirmed'),
    );
  }

  static AppointmentStatus _statusFromString(String raw) {
    switch (raw) {
      case 'pending':
        return AppointmentStatus.pending;
      case 'cancelledByPatient':
        return AppointmentStatus.cancelledByPatient;
      case 'declinedByProfessional':
        return AppointmentStatus.declinedByProfessional;
      case 'cancelled':
        return AppointmentStatus.cancelledByPatient; // compat ancien stockage
      case 'confirmed':
      default:
        return AppointmentStatus.confirmed;
    }
  }
}
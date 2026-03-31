import 'package:flutter/foundation.dart';

enum AppointmentStatus {
  pending,
  confirmed,
  cancelledByPatient,
  declinedByProfessional,
}

@immutable
class Appointment {
  Appointment({
    required String id,
    required DateTime createdAt,
    required String practitionerId,
    required String practitionerName,
    required String specialty,
    required String address,
    required String city,
    required String area,
    required DateTime day,
    required String slot,
    required String reason,
    required String patientFirstName,
    required String patientLastName,
    required String patientPhoneE164,
    required this.consentAccepted,
    required String consentVersion,
    required DateTime consentAcceptedAt,
    this.status = AppointmentStatus.confirmed,
  })  : id = _clean(id),
        createdAt = createdAt,
        practitionerId = _clean(practitionerId),
        practitionerName = _clean(practitionerName),
        specialty = _clean(specialty),
        address = _clean(address),
        city = _clean(city),
        area = _clean(area),
        day = _normalizeDay(day),
        slot = _normalizeSlot(slot),
        reason = _clean(reason),
        patientFirstName = _clean(patientFirstName),
        patientLastName = _clean(patientLastName),
        patientPhoneE164 = _normalizePhone(patientPhoneE164),
        consentVersion = _clean(consentVersion),
        consentAcceptedAt = consentAcceptedAt;

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

  // =========================
  // HELPERS MÉTIER
  // =========================

  String get patientFullName =>
      '$patientFirstName $patientLastName'.trim();

  String get practitionerLocationLabel {
    if (area.isEmpty && city.isEmpty) return 'Localisation non renseignée';
    if (area.isEmpty) return city;
    if (city.isEmpty) return area;
    return '$area, $city';
  }

  String get fullAddress {
    if (address.isEmpty) return practitionerLocationLabel;
    return '$address • $practitionerLocationLabel';
  }

  DateTime get scheduledAt {
    final parts = slot.split(':');
    if (parts.length != 2) return day;

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    return DateTime(
      day.year,
      day.month,
      day.day,
      hour.clamp(0, 23),
      minute.clamp(0, 59),
    );
  }

  bool get isUpcoming => scheduledAt.isAfter(DateTime.now());
  bool get isPast => scheduledAt.isBefore(DateTime.now());

  bool get isCancelledLike =>
      status == AppointmentStatus.cancelledByPatient ||
      status == AppointmentStatus.declinedByProfessional;

  bool get isActive =>
      status == AppointmentStatus.pending ||
      status == AppointmentStatus.confirmed;

  // =========================
  // COPY
  // =========================

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

  // =========================
  // SERIALIZATION
  // =========================

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
      id: map['id'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ??
          DateTime.now(),
      practitionerId: map['practitionerId'] ?? '',
      practitionerName: map['practitionerName'] ?? '',
      specialty: map['specialty'] ?? '',
      address: map['address'] ?? '',
      city: map['city'] ?? '',
      area: map['area'] ?? '',
      day: DateTime.tryParse(map['day'] ?? '') ??
          DateTime.now(),
      slot: map['slot'] ?? '',
      reason: map['reason'] ?? '',
      patientFirstName: map['patientFirstName'] ?? '',
      patientLastName: map['patientLastName'] ?? '',
      patientPhoneE164: map['patientPhoneE164'] ?? '',
      consentAccepted: map['consentAccepted'] ?? false,
      consentVersion: map['consentVersion'] ?? '',
      consentAcceptedAt:
          DateTime.tryParse(map['consentAcceptedAt'] ?? '') ??
              DateTime.now(),
      status: _statusFromString(map['status'] ?? 'confirmed'),
    );
  }

  static AppointmentStatus _statusFromString(String raw) {
    switch (raw) {
      case 'pending':
        return AppointmentStatus.pending;
      case 'cancelledByPatient':
      case 'cancelled':
        return AppointmentStatus.cancelledByPatient;
      case 'declinedByProfessional':
        return AppointmentStatus.declinedByProfessional;
      default:
        return AppointmentStatus.confirmed;
    }
  }

  // =========================
  // EQUALITY
  // =========================

  @override
  bool operator ==(Object other) {
    return other is Appointment &&
        other.id == id &&
        other.status == status &&
        other.scheduledAt == scheduledAt;
  }

  @override
  int get hashCode => Object.hash(id, status, scheduledAt);

  // =========================
  // NORMALISATION
  // =========================

  static String _clean(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _normalizePhone(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';

    if (trimmed.startsWith('+')) {
      final digits = trimmed.substring(1).replaceAll(RegExp(r'\D'), '');
      return '+$digits';
    }

    return trimmed.replaceAll(RegExp(r'\D'), '');
  }

  static DateTime _normalizeDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static String _normalizeSlot(String slot) {
    final parts = slot.split(':');
    if (parts.length != 2) return '00:00';

    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;

    return '${h.clamp(0, 23).toString().padLeft(2, '0')}:${m.clamp(0, 59).toString().padLeft(2, '0')}';
  }
}
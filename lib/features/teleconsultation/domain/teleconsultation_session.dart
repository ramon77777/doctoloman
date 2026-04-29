import 'package:flutter/foundation.dart';

enum TeleconsultationStatus {
  scheduled,
  waiting,
  inProgress,
  completed,
  cancelled,
}

@immutable
class TeleconsultationSession {
  TeleconsultationSession({
    required String id,
    required String appointmentId,
    required String patientId,
    required String patientName,
    required String professionalId,
    required String professionalName,
    required DateTime scheduledAt,
    required String reason,
    required bool consentAccepted,
    DateTime? consentAcceptedAt,
    String? roomUrl,
    DateTime? startedAt,
    DateTime? endedAt,
    this.status = TeleconsultationStatus.scheduled,
  })  : id = _clean(id),
        appointmentId = _clean(appointmentId),
        patientId = _clean(patientId),
        patientName = _clean(patientName),
        professionalId = _clean(professionalId),
        professionalName = _clean(professionalName),
        scheduledAt = scheduledAt,
        reason = _clean(reason),
        consentAccepted = consentAccepted,
        consentAcceptedAt = consentAcceptedAt,
        roomUrl = _cleanNullable(roomUrl),
        startedAt = startedAt,
        endedAt = endedAt;

  final String id;
  final String appointmentId;

  final String patientId;
  final String patientName;

  final String professionalId;
  final String professionalName;

  final DateTime scheduledAt;
  final String reason;

  final TeleconsultationStatus status;

  final bool consentAccepted;
  final DateTime? consentAcceptedAt;

  /// MVP mock : plus tard remplacé par une room Jitsi sécurisée côté backend.
  final String? roomUrl;

  final DateTime? startedAt;
  final DateTime? endedAt;

  bool get isScheduled => status == TeleconsultationStatus.scheduled;
  bool get isWaiting => status == TeleconsultationStatus.waiting;
  bool get isInProgress => status == TeleconsultationStatus.inProgress;
  bool get isCompleted => status == TeleconsultationStatus.completed;
  bool get isCancelled => status == TeleconsultationStatus.cancelled;

  bool get canJoin {
    return consentAccepted &&
        (status == TeleconsultationStatus.scheduled ||
            status == TeleconsultationStatus.waiting ||
            status == TeleconsultationStatus.inProgress);
  }

  bool get canStart {
    return consentAccepted &&
        (status == TeleconsultationStatus.scheduled ||
            status == TeleconsultationStatus.waiting);
  }

  bool get canEnd => status == TeleconsultationStatus.inProgress;

  bool get isClosed {
    return status == TeleconsultationStatus.completed ||
        status == TeleconsultationStatus.cancelled;
  }

  String get safeRoomUrl {
    final current = roomUrl?.trim() ?? '';
    if (current.isNotEmpty) return current;
    return 'mock://teleconsultation/$id';
  }

  TeleconsultationSession copyWith({
    String? id,
    String? appointmentId,
    String? patientId,
    String? patientName,
    String? professionalId,
    String? professionalName,
    DateTime? scheduledAt,
    String? reason,
    TeleconsultationStatus? status,
    bool? consentAccepted,
    DateTime? consentAcceptedAt,
    String? roomUrl,
    DateTime? startedAt,
    DateTime? endedAt,
    bool clearConsentAcceptedAt = false,
    bool clearRoomUrl = false,
    bool clearStartedAt = false,
    bool clearEndedAt = false,
  }) {
    return TeleconsultationSession(
      id: id ?? this.id,
      appointmentId: appointmentId ?? this.appointmentId,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      professionalId: professionalId ?? this.professionalId,
      professionalName: professionalName ?? this.professionalName,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      consentAccepted: consentAccepted ?? this.consentAccepted,
      consentAcceptedAt: clearConsentAcceptedAt
          ? null
          : (consentAcceptedAt ?? this.consentAcceptedAt),
      roomUrl: clearRoomUrl ? null : (roomUrl ?? this.roomUrl),
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      endedAt: clearEndedAt ? null : (endedAt ?? this.endedAt),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'appointmentId': appointmentId,
      'patientId': patientId,
      'patientName': patientName,
      'professionalId': professionalId,
      'professionalName': professionalName,
      'scheduledAt': scheduledAt.toIso8601String(),
      'reason': reason,
      'status': status.name,
      'consentAccepted': consentAccepted,
      'consentAcceptedAt': consentAcceptedAt?.toIso8601String(),
      'roomUrl': roomUrl,
      'startedAt': startedAt?.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
    };
  }

  factory TeleconsultationSession.fromMap(Map<String, dynamic> map) {
    return TeleconsultationSession(
      id: (map['id'] as String?) ?? '',
      appointmentId: (map['appointmentId'] as String?) ?? '',
      patientId: (map['patientId'] as String?) ?? '',
      patientName: (map['patientName'] as String?) ?? '',
      professionalId: (map['professionalId'] as String?) ?? '',
      professionalName: (map['professionalName'] as String?) ?? '',
      scheduledAt: _parseDate(map['scheduledAt']) ?? DateTime.now(),
      reason: (map['reason'] as String?) ?? '',
      status: _statusFromString(map['status'] as String?),
      consentAccepted: (map['consentAccepted'] as bool?) ?? false,
      consentAcceptedAt: _parseDate(map['consentAcceptedAt']),
      roomUrl: map['roomUrl'] as String?,
      startedAt: _parseDate(map['startedAt']),
      endedAt: _parseDate(map['endedAt']),
    );
  }

  static TeleconsultationStatus _statusFromString(String? raw) {
    switch (raw) {
      case 'waiting':
        return TeleconsultationStatus.waiting;
      case 'inProgress':
        return TeleconsultationStatus.inProgress;
      case 'completed':
        return TeleconsultationStatus.completed;
      case 'cancelled':
        return TeleconsultationStatus.cancelled;
      case 'scheduled':
      default:
        return TeleconsultationStatus.scheduled;
    }
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static String _clean(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String? _cleanNullable(String? value) {
    if (value == null) return null;
    final cleaned = _clean(value);
    return cleaned.isEmpty ? null : cleaned;
  }

  @override
  bool operator ==(Object other) {
    return other is TeleconsultationSession &&
        other.id == id &&
        other.appointmentId == appointmentId &&
        other.status == status &&
        other.scheduledAt == scheduledAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        appointmentId,
        status,
        scheduledAt,
      );

  @override
  String toString() {
    return 'TeleconsultationSession(id: $id, appointmentId: $appointmentId, status: ${status.name})';
  }
}
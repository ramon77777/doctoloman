import 'package:flutter/foundation.dart';

@immutable
class MedicalAccess {
  MedicalAccess({
    required String id,
    required String patientId,
    required String patientName,
    required String professionalId,
    required String professionalName,
    required DateTime grantedAt,
    DateTime? revokedAt,
  })  : id = _cleanText(id),
        patientId = _cleanText(patientId),
        patientName = _cleanText(patientName),
        professionalId = _cleanText(professionalId),
        professionalName = _cleanText(professionalName),
        grantedAt = grantedAt,
        revokedAt = revokedAt == null ? null : _normalizeDateTime(revokedAt);

  final String id;
  final String patientId;
  final String patientName;
  final String professionalId;
  final String professionalName;
  final DateTime grantedAt;
  final DateTime? revokedAt;

  bool get isActive => revokedAt == null;

  MedicalAccess copyWith({
    String? id,
    String? patientId,
    String? patientName,
    String? professionalId,
    String? professionalName,
    DateTime? grantedAt,
    DateTime? revokedAt,
    bool clearRevokedAt = false,
  }) {
    return MedicalAccess(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      professionalId: professionalId ?? this.professionalId,
      professionalName: professionalName ?? this.professionalName,
      grantedAt: grantedAt ?? this.grantedAt,
      revokedAt: clearRevokedAt ? null : (revokedAt ?? this.revokedAt),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'professionalId': professionalId,
      'professionalName': professionalName,
      'grantedAt': grantedAt.toIso8601String(),
      'revokedAt': revokedAt?.toIso8601String(),
    };
  }

  factory MedicalAccess.fromMap(Map<String, dynamic> map) {
    return MedicalAccess(
      id: (map['id'] as String?) ?? '',
      patientId: (map['patientId'] as String?) ?? '',
      patientName: (map['patientName'] as String?) ?? '',
      professionalId: (map['professionalId'] as String?) ?? '',
      professionalName: (map['professionalName'] as String?) ?? '',
      grantedAt: _parseDateOrNow(map['grantedAt']),
      revokedAt: _parseNullableDate(map['revokedAt']),
    );
  }

  static DateTime _parseDateOrNow(Object? raw) {
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        return parsed;
      }
    }
    return DateTime.now();
  }

  static DateTime? _parseNullableDate(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  static DateTime _normalizeDateTime(DateTime value) {
    return DateTime.fromMillisecondsSinceEpoch(
      value.millisecondsSinceEpoch,
      isUtc: value.isUtc,
    );
  }

  static String _cleanText(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MedicalAccess &&
        other.id == id &&
        other.patientId == patientId &&
        other.patientName == patientName &&
        other.professionalId == professionalId &&
        other.professionalName == professionalName &&
        other.grantedAt == grantedAt &&
        other.revokedAt == revokedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      patientId,
      patientName,
      professionalId,
      professionalName,
      grantedAt,
      revokedAt,
    );
  }

  @override
  String toString() {
    return 'MedicalAccess('
        'id: $id, '
        'patientId: $patientId, '
        'professionalId: $professionalId, '
        'isActive: $isActive'
        ')';
  }
}
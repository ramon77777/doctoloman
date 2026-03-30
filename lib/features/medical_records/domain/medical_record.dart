import 'package:flutter/foundation.dart';

enum MedicalRecordCategory {
  prescription,
  labResult,
  imaging,
  certificate,
  report,
  other,
}

@immutable
class MedicalRecord {
  const MedicalRecord({
    required this.id,
    required this.title,
    required this.category,
    required this.recordDate,
    required this.createdAt,
    required this.patientName,
    required this.sourceLabel,
    required this.summary,
    required this.isSensitive,
    this.description,
  });

  final String id;
  final String title;
  final MedicalRecordCategory category;
  final DateTime recordDate;
  final DateTime createdAt;

  final String patientName;
  final String sourceLabel;
  final String summary;
  final bool isSensitive;

  /// Champ enrichi pour la suite, sans casser l’existant.
  final String? description;

  String get effectiveDescription {
    final desc = description?.trim();
    if (desc != null && desc.isNotEmpty) {
      return desc;
    }
    return summary.trim();
  }

  MedicalRecord copyWith({
    String? id,
    String? title,
    MedicalRecordCategory? category,
    DateTime? recordDate,
    DateTime? createdAt,
    String? patientName,
    String? sourceLabel,
    String? summary,
    bool? isSensitive,
    String? description,
  }) {
    return MedicalRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      recordDate: recordDate ?? this.recordDate,
      createdAt: createdAt ?? this.createdAt,
      patientName: patientName ?? this.patientName,
      sourceLabel: sourceLabel ?? this.sourceLabel,
      summary: summary ?? this.summary,
      isSensitive: isSensitive ?? this.isSensitive,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category.name,
      'recordDate': recordDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'patientName': patientName,
      'sourceLabel': sourceLabel,
      'summary': summary,
      'isSensitive': isSensitive,
      'description': description,
    };
  }

  factory MedicalRecord.fromMap(Map<String, dynamic> map) {
    return MedicalRecord(
      id: (map['id'] as String?)?.trim() ?? '',
      title: (map['title'] as String?)?.trim() ?? '',
      category: _categoryFromString(map['category'] as String?),
      recordDate: DateTime.parse(
        (map['recordDate'] as String?) ?? DateTime.now().toIso8601String(),
      ),
      createdAt: DateTime.parse(
        (map['createdAt'] as String?) ?? DateTime.now().toIso8601String(),
      ),
      patientName: (map['patientName'] as String?)?.trim() ?? '',
      sourceLabel: (map['sourceLabel'] as String?)?.trim() ?? '',
      summary: (map['summary'] as String?)?.trim() ?? '',
      isSensitive: (map['isSensitive'] as bool?) ?? true,
      description: (map['description'] as String?)?.trim(),
    );
  }

  static MedicalRecordCategory _categoryFromString(String? raw) {
    switch (raw) {
      case 'prescription':
        return MedicalRecordCategory.prescription;
      case 'labResult':
        return MedicalRecordCategory.labResult;
      case 'imaging':
        return MedicalRecordCategory.imaging;
      case 'certificate':
        return MedicalRecordCategory.certificate;
      case 'report':
        return MedicalRecordCategory.report;
      default:
        return MedicalRecordCategory.other;
    }
  }
}
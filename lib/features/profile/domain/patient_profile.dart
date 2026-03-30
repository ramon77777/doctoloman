import 'package:flutter/foundation.dart';

enum PatientGender {
  female,
  male,
  other,
}

@immutable
class PatientProfile {
  const PatientProfile({
    required this.id,
    required this.name,
    required this.phone,
    this.city,
    this.district,
    this.address,
    this.birthDate,
    this.gender,
    this.bloodGroup,
    this.allergies,
    this.medicalNotes,
    this.emergencyContactName,
    this.emergencyContactPhone,
  });

  final String id;
  final String name;
  final String phone;

  final String? city;
  final String? district;
  final String? address;
  final DateTime? birthDate;
  final PatientGender? gender;

  final String? bloodGroup;
  final String? allergies;
  final String? medicalNotes;

  final String? emergencyContactName;
  final String? emergencyContactPhone;

  PatientProfile copyWith({
    String? id,
    String? name,
    String? phone,
    String? city,
    String? district,
    String? address,
    DateTime? birthDate,
    bool clearBirthDate = false,
    PatientGender? gender,
    bool clearGender = false,
    String? bloodGroup,
    String? allergies,
    String? medicalNotes,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) {
    return PatientProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      district: district ?? this.district,
      address: address ?? this.address,
      birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
      gender: clearGender ? null : (gender ?? this.gender),
      bloodGroup: bloodGroup ?? this.bloodGroup,
      allergies: allergies ?? this.allergies,
      medicalNotes: medicalNotes ?? this.medicalNotes,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone:
          emergencyContactPhone ?? this.emergencyContactPhone,
    );
  }

  bool get isComplete =>
      name.trim().isNotEmpty &&
      phone.trim().isNotEmpty &&
      (city?.trim().isNotEmpty ?? false) &&
      birthDate != null &&
      gender != null;

  int get completionScore {
    var score = 0;

    if (name.trim().isNotEmpty) score++;
    if (phone.trim().isNotEmpty) score++;
    if ((city?.trim().isNotEmpty ?? false)) score++;
    if ((district?.trim().isNotEmpty ?? false)) score++;
    if ((address?.trim().isNotEmpty ?? false)) score++;
    if (birthDate != null) score++;
    if (gender != null) score++;
    if ((bloodGroup?.trim().isNotEmpty ?? false)) score++;
    if ((emergencyContactName?.trim().isNotEmpty ?? false)) score++;
    if ((emergencyContactPhone?.trim().isNotEmpty ?? false)) score++;

    return score;
  }

  int get completionPercent {
    const totalFields = 10;
    return ((completionScore / totalFields) * 100).round();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'city': city,
      'district': district,
      'address': address,
      'birthDate': birthDate?.toIso8601String(),
      'gender': gender?.name,
      'bloodGroup': bloodGroup,
      'allergies': allergies,
      'medicalNotes': medicalNotes,
      'emergencyContactName': emergencyContactName,
      'emergencyContactPhone': emergencyContactPhone,
    };
  }

  factory PatientProfile.fromMap(Map<String, dynamic> map) {
    return PatientProfile(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      phone: (map['phone'] as String?) ?? '',
      city: map['city'] as String?,
      district: map['district'] as String?,
      address: map['address'] as String?,
      birthDate: map['birthDate'] != null
          ? DateTime.tryParse(map['birthDate'] as String)
          : null,
      gender: _genderFromString(map['gender'] as String?),
      bloodGroup: map['bloodGroup'] as String?,
      allergies: map['allergies'] as String?,
      medicalNotes: map['medicalNotes'] as String?,
      emergencyContactName: map['emergencyContactName'] as String?,
      emergencyContactPhone: map['emergencyContactPhone'] as String?,
    );
  }

  static PatientGender? _genderFromString(String? raw) {
    switch (raw) {
      case 'female':
        return PatientGender.female;
      case 'male':
        return PatientGender.male;
      case 'other':
        return PatientGender.other;
      default:
        return null;
    }
  }
}
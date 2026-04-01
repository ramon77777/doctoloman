import 'package:flutter/foundation.dart';

enum PatientGender {
  female,
  male,
  other,
}

@immutable
class PatientProfile {
  PatientProfile({
    required String id,
    required String name,
    required String phone,
    String? city,
    String? district,
    String? address,
    DateTime? birthDate,
    this.gender,
    String? bloodGroup,
    String? allergies,
    String? medicalNotes,
    String? emergencyContactName,
    String? emergencyContactPhone,
  })  : id = _cleanText(id),
        name = _cleanText(name),
        phone = _cleanText(phone),
        city = _cleanNullableText(city),
        district = _cleanNullableText(district),
        address = _cleanNullableText(address),
        birthDate = birthDate == null ? null : _normalizeDate(birthDate),
        bloodGroup = _cleanNullableText(bloodGroup),
        allergies = _cleanNullableMultilineText(allergies),
        medicalNotes = _cleanNullableMultilineText(medicalNotes),
        emergencyContactName = _cleanNullableText(emergencyContactName),
        emergencyContactPhone = _cleanNullableText(emergencyContactPhone);

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

  bool get hasCity => city != null && city!.isNotEmpty;
  bool get hasDistrict => district != null && district!.isNotEmpty;
  bool get hasAddress => address != null && address!.isNotEmpty;
  bool get hasBirthDate => birthDate != null;
  bool get hasGender => gender != null;
  bool get hasBloodGroup => bloodGroup != null && bloodGroup!.isNotEmpty;
  bool get hasAllergies => allergies != null && allergies!.isNotEmpty;
  bool get hasMedicalNotes => medicalNotes != null && medicalNotes!.isNotEmpty;
  bool get hasEmergencyContactName =>
      emergencyContactName != null && emergencyContactName!.isNotEmpty;
  bool get hasEmergencyContactPhone =>
      emergencyContactPhone != null && emergencyContactPhone!.isNotEmpty;

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
      name.isNotEmpty &&
      phone.isNotEmpty &&
      hasCity &&
      birthDate != null &&
      gender != null;

  int get completionScore {
    var score = 0;

    if (name.isNotEmpty) score++;
    if (phone.isNotEmpty) score++;
    if (hasCity) score++;
    if (hasDistrict) score++;
    if (hasAddress) score++;
    if (hasBirthDate) score++;
    if (hasGender) score++;
    if (hasBloodGroup) score++;
    if (hasEmergencyContactName) score++;
    if (hasEmergencyContactPhone) score++;

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
      birthDate: _parseNullableDate(map['birthDate']),
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

  static DateTime? _parseNullableDate(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return null;

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;

    return _normalizeDate(parsed);
  }

  static DateTime _normalizeDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static String _cleanText(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String? _cleanNullableText(String? value) {
    if (value == null) return null;

    final cleaned = _cleanText(value);
    return cleaned.isEmpty ? null : cleaned;
  }

  static String? _cleanNullableMultilineText(String? value) {
    if (value == null) return null;

    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return cleaned.isEmpty ? null : cleaned;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PatientProfile &&
        other.id == id &&
        other.name == name &&
        other.phone == phone &&
        other.city == city &&
        other.district == district &&
        other.address == address &&
        other.birthDate == birthDate &&
        other.gender == gender &&
        other.bloodGroup == bloodGroup &&
        other.allergies == allergies &&
        other.medicalNotes == medicalNotes &&
        other.emergencyContactName == emergencyContactName &&
        other.emergencyContactPhone == emergencyContactPhone;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      phone,
      city,
      district,
      address,
      birthDate,
      gender,
      bloodGroup,
      allergies,
      medicalNotes,
      emergencyContactName,
      emergencyContactPhone,
    );
  }

  @override
  String toString() {
    return 'PatientProfile(id: $id, name: $name, phone: $phone)';
  }
}
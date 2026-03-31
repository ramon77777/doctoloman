import 'package:flutter/foundation.dart';


@immutable
class ProfessionalProfile {
  ProfessionalProfile({
    required String id,
    required String displayName,
    required String specialty,
    required String structureName,
    required String phone,
    required String city,
    required String area,
    required String address,
    required String bio,
    required List<String> languages,
    required String consultationFeeLabel,
    required bool isVerified,
  })  : id = _normalizeRequired(id),
        displayName = _normalizeRequired(displayName),
        specialty = _normalizeRequired(specialty),
        structureName = _normalizeOptional(structureName),
        phone = _normalizeOptional(phone),
        city = _normalizeOptional(city),
        area = _normalizeOptional(area),
        address = _normalizeOptional(address),
        bio = _normalizeOptional(bio),
        languages = List.unmodifiable(_normalizeLanguages(languages)),
        consultationFeeLabel = _normalizeOptional(consultationFeeLabel),
        isVerified = isVerified;

  final String id;
  final String displayName;
  final String specialty;
  final String structureName;
  final String phone;
  final String city;
  final String area;
  final String address;
  final String bio;
  final List<String> languages;
  final String consultationFeeLabel;
  final bool isVerified;

  bool get hasStructureName => structureName.isNotEmpty;
  bool get hasPhone => phone.isNotEmpty;
  bool get hasCity => city.isNotEmpty;
  bool get hasArea => area.isNotEmpty;
  bool get hasAddress => address.isNotEmpty;
  bool get hasBio => bio.isNotEmpty;
  bool get hasLanguages => languages.isNotEmpty;
  bool get hasConsultationFee => consultationFeeLabel.isNotEmpty;

  String get fullLocation {
    final parts = <String>[
      if (address.isNotEmpty) address,
      if (area.isNotEmpty) area,
      if (city.isNotEmpty) city,
    ];
    return parts.join(' • ');
  }

  String get shortLocation {
    final parts = <String>[
      if (area.isNotEmpty) area,
      if (city.isNotEmpty) city,
    ];
    return parts.join(', ');
  }

  ProfessionalProfile copyWith({
    String? id,
    String? displayName,
    String? specialty,
    String? structureName,
    String? phone,
    String? city,
    String? area,
    String? address,
    String? bio,
    List<String>? languages,
    String? consultationFeeLabel,
    bool? isVerified,
  }) {
    return ProfessionalProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      specialty: specialty ?? this.specialty,
      structureName: structureName ?? this.structureName,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      area: area ?? this.area,
      address: address ?? this.address,
      bio: bio ?? this.bio,
      languages: languages ?? this.languages,
      consultationFeeLabel: consultationFeeLabel ?? this.consultationFeeLabel,
      isVerified: isVerified ?? this.isVerified,
    );
  }

  @override
  String toString() {
    return 'ProfessionalProfile('
        'id: $id, '
        'displayName: $displayName, '
        'specialty: $specialty, '
        'structureName: $structureName, '
        'phone: $phone, '
        'city: $city, '
        'area: $area, '
        'address: $address, '
        'bio: $bio, '
        'languages: $languages, '
        'consultationFeeLabel: $consultationFeeLabel, '
        'isVerified: $isVerified'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ProfessionalProfile &&
        other.id == id &&
        other.displayName == displayName &&
        other.specialty == specialty &&
        other.structureName == structureName &&
        other.phone == phone &&
        other.city == city &&
        other.area == area &&
        other.address == address &&
        other.bio == bio &&
        listEquals(other.languages, languages) &&
        other.consultationFeeLabel == consultationFeeLabel &&
        other.isVerified == isVerified;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      displayName,
      specialty,
      structureName,
      phone,
      city,
      area,
      address,
      bio,
      Object.hashAll(languages),
      consultationFeeLabel,
      isVerified,
    );
  }

  static String _normalizeRequired(String value) {
    final normalized = _collapseSpaces(value);
    return normalized;
  }

  static String _normalizeOptional(String value) {
    return _collapseSpaces(value);
  }

  static List<String> _normalizeLanguages(List<String> values) {
    final seen = <String>{};
    final result = <String>[];

    for (final raw in values) {
      final normalized = _collapseSpaces(raw);
      if (normalized.isEmpty) continue;

      final key = normalized.toLowerCase();
      if (!seen.add(key)) continue;

      result.add(normalized);
    }

    return result;
  }

  static String _collapseSpaces(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}
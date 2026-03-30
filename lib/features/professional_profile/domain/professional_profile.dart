import 'package:flutter/foundation.dart';

@immutable
class ProfessionalProfile {
  const ProfessionalProfile({
    required this.id,
    required this.displayName,
    required this.specialty,
    required this.structureName,
    required this.phone,
    required this.city,
    required this.area,
    required this.address,
    required this.bio,
    required this.languages,
    required this.consultationFeeLabel,
    required this.isVerified,
  });

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

  String get fullLocation {
    final parts = <String>[
      if (address.trim().isNotEmpty) address.trim(),
      if (area.trim().isNotEmpty) area.trim(),
      if (city.trim().isNotEmpty) city.trim(),
    ];
    return parts.join(' • ');
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
}
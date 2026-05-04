import 'package:flutter/foundation.dart';

@immutable
class AppointmentReasonOption {
  const AppointmentReasonOption({
    required this.label,
    required this.durationMinutes,
  });

  final String label;
  final int durationMinutes;

  String get durationLabel => '$durationMinutes min';

  AppointmentReasonOption copyWith({
    String? label,
    int? durationMinutes,
  }) {
    return AppointmentReasonOption(
      label: label ?? this.label,
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'durationMinutes': durationMinutes,
    };
  }

  factory AppointmentReasonOption.fromMap(
    Map<String, dynamic> map, {
    required AppointmentReasonOption fallback,
  }) {
    return AppointmentReasonOption(
      label: _readString(map, 'label', fallback.label),
      durationMinutes: _readDuration(
        map,
        'durationMinutes',
        fallback.durationMinutes,
      ),
    );
  }

  static String _readString(
    Map<String, dynamic> map,
    String key,
    String fallback,
  ) {
    final value = map[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim().replaceAll(RegExp(r'\s+'), ' ');
    }
    return fallback;
  }

  static int _readDuration(
    Map<String, dynamic> map,
    String key,
    int fallback,
  ) {
    final value = map[key];

    if (value is int) {
      return ProfessionalProfile.normalizeAppointmentDuration(value);
    }

    if (value is num) {
      return ProfessionalProfile.normalizeAppointmentDuration(value.round());
    }

    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) {
        return ProfessionalProfile.normalizeAppointmentDuration(parsed);
      }
    }

    return ProfessionalProfile.normalizeAppointmentDuration(fallback);
  }

  @override
  String toString() {
    return 'AppointmentReasonOption(label: $label, durationMinutes: $durationMinutes)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AppointmentReasonOption &&
        other.label == label &&
        other.durationMinutes == durationMinutes;
  }

  @override
  int get hashCode => Object.hash(label, durationMinutes);
}

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
    int appointmentDurationMinutes = defaultAppointmentDurationMinutes,
    List<AppointmentReasonOption> appointmentReasons =
        defaultAppointmentReasons,
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
        isVerified = isVerified,
        appointmentDurationMinutes =
            normalizeAppointmentDuration(appointmentDurationMinutes),
        appointmentReasons = List.unmodifiable(
          _normalizeAppointmentReasons(appointmentReasons),
        );

  static const int defaultAppointmentDurationMinutes = 30;

  static const List<int> allowedAppointmentDurations = [
    15,
    20,
    30,
    45,
    60,
  ];

  static const List<AppointmentReasonOption> defaultAppointmentReasons = [
    AppointmentReasonOption(
      label: 'Consultation',
      durationMinutes: 30,
    ),
    AppointmentReasonOption(
      label: 'Suivi',
      durationMinutes: 20,
    ),
    AppointmentReasonOption(
      label: 'Renouvellement ordonnance',
      durationMinutes: 15,
    ),
    AppointmentReasonOption(
      label: 'Urgence légère',
      durationMinutes: 15,
    ),
    AppointmentReasonOption(
      label: 'Autre',
      durationMinutes: 30,
    ),
  ];

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

  /// Durée par défaut d’un rendez-vous pour ce professionnel.
  ///
  /// Conservée comme valeur de secours.
  /// Les motifs configurables utilisent [appointmentReasons].
  final int appointmentDurationMinutes;

  /// Motifs de rendez-vous visibles côté patient, avec durée associée.
  final List<AppointmentReasonOption> appointmentReasons;

  bool get hasStructureName => structureName.isNotEmpty;
  bool get hasPhone => phone.isNotEmpty;
  bool get hasCity => city.isNotEmpty;
  bool get hasArea => area.isNotEmpty;
  bool get hasAddress => address.isNotEmpty;
  bool get hasBio => bio.isNotEmpty;
  bool get hasLanguages => languages.isNotEmpty;
  bool get hasConsultationFee => consultationFeeLabel.isNotEmpty;

  String get appointmentDurationLabel => '$appointmentDurationMinutes min';

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
    int? appointmentDurationMinutes,
    List<AppointmentReasonOption>? appointmentReasons,
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
      appointmentDurationMinutes:
          appointmentDurationMinutes ?? this.appointmentDurationMinutes,
      appointmentReasons: appointmentReasons ?? this.appointmentReasons,
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
        'isVerified: $isVerified, '
        'appointmentDurationMinutes: $appointmentDurationMinutes, '
        'appointmentReasons: $appointmentReasons'
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
        other.isVerified == isVerified &&
        other.appointmentDurationMinutes == appointmentDurationMinutes &&
        listEquals(other.appointmentReasons, appointmentReasons);
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
      appointmentDurationMinutes,
      Object.hashAll(appointmentReasons),
    );
  }

  static int normalizeAppointmentDuration(int value) {
    if (allowedAppointmentDurations.contains(value)) {
      return value;
    }

    return defaultAppointmentDurationMinutes;
  }

  static String _normalizeRequired(String value) {
    return _collapseSpaces(value);
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

  static List<AppointmentReasonOption> _normalizeAppointmentReasons(
    List<AppointmentReasonOption> values,
  ) {
    if (values.isEmpty) {
      return defaultAppointmentReasons;
    }

    final seen = <String>{};
    final result = <AppointmentReasonOption>[];

    for (final raw in values) {
      final label = _collapseSpaces(raw.label);
      if (label.isEmpty) continue;

      final key = label.toLowerCase();
      if (!seen.add(key)) continue;

      result.add(
        AppointmentReasonOption(
          label: label,
          durationMinutes: normalizeAppointmentDuration(raw.durationMinutes),
        ),
      );
    }

    if (result.isEmpty) {
      return defaultAppointmentReasons;
    }

    return result;
  }

  static String _collapseSpaces(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}
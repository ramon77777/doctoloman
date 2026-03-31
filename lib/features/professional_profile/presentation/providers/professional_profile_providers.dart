import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/professional_profile.dart';

const _professionalProfileStorageKey = 'professional_profile_v1';
const _defaultProfessionalProfileId = 'pro_001';

final defaultProfessionalProfile = ProfessionalProfile(
  id: _defaultProfessionalProfileId,
  displayName: 'Dr Kouamé Aya',
  specialty: 'Médecin généraliste',
  structureName: 'Cabinet Médical Sainte Grâce',
  phone: '+2250700000001',
  city: 'Abidjan',
  area: 'Cocody',
  address: 'Rue des Jardins',
  bio:
      'Médecin généraliste avec une pratique orientée suivi familial, prévention et consultations de proximité.',
  languages: const ['Français'],
  consultationFeeLabel: '10 000 - 15 000 FCFA',
  isVerified: true,
);

class ProfessionalProfileController extends StateNotifier<ProfessionalProfile> {
  ProfessionalProfileController(this._prefs)
      : super(_loadInitialState(_prefs));

  final SharedPreferences _prefs;

  static ProfessionalProfile _loadInitialState(SharedPreferences prefs) {
    final raw = prefs.getString(_professionalProfileStorageKey);
    if (raw == null || raw.trim().isEmpty) {
      return defaultProfessionalProfile;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return defaultProfessionalProfile;
      }

      final profile = ProfessionalProfile(
        id: _readString(decoded, 'id', defaultProfessionalProfile.id),
        displayName: _readString(
          decoded,
          'displayName',
          defaultProfessionalProfile.displayName,
        ),
        specialty: _readString(
          decoded,
          'specialty',
          defaultProfessionalProfile.specialty,
        ),
        structureName: _readString(
          decoded,
          'structureName',
          defaultProfessionalProfile.structureName,
        ),
        phone: _readString(
          decoded,
          'phone',
          defaultProfessionalProfile.phone,
        ),
        city: _readString(
          decoded,
          'city',
          defaultProfessionalProfile.city,
        ),
        area: _readString(
          decoded,
          'area',
          defaultProfessionalProfile.area,
        ),
        address: _readString(
          decoded,
          'address',
          defaultProfessionalProfile.address,
        ),
        bio: _readString(
          decoded,
          'bio',
          defaultProfessionalProfile.bio,
        ),
        languages: _readStringList(
          decoded,
          'languages',
          defaultProfessionalProfile.languages,
        ),
        consultationFeeLabel: _readString(
          decoded,
          'consultationFeeLabel',
          defaultProfessionalProfile.consultationFeeLabel,
        ),
        isVerified: _readBool(
          decoded,
          'isVerified',
          defaultProfessionalProfile.isVerified,
        ),
      );

      return _sanitizeProfile(profile);
    } catch (_) {
      return defaultProfessionalProfile;
    }
  }

  Future<void> updateProfile({
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
  }) async {
    final nextState = _sanitizeProfile(
      state.copyWith(
        displayName: displayName,
        specialty: specialty,
        structureName: structureName,
        phone: phone,
        city: city,
        area: area,
        address: address,
        bio: bio,
        languages: languages,
        consultationFeeLabel: consultationFeeLabel,
        isVerified: isVerified,
      ),
    );

    if (nextState == state) return;

    state = nextState;
    await _persist(nextState);
  }

  Future<void> resetProfile() async {
    final resetState = _sanitizeProfile(defaultProfessionalProfile);
    if (resetState == state) return;

    state = resetState;
    await _persist(resetState);
  }

  Future<void> replaceProfile(ProfessionalProfile profile) async {
    final nextState = _sanitizeProfile(profile);
    if (nextState == state) return;

    state = nextState;
    await _persist(nextState);
  }

  Future<void> _persist(ProfessionalProfile profile) async {
    final sanitized = _sanitizeProfile(profile);
    await _prefs.setString(
      _professionalProfileStorageKey,
      jsonEncode(_toJson(sanitized)),
    );
  }

  static Map<String, dynamic> _toJson(ProfessionalProfile profile) {
    return <String, dynamic>{
      'id': profile.id,
      'displayName': profile.displayName,
      'specialty': profile.specialty,
      'structureName': profile.structureName,
      'phone': profile.phone,
      'city': profile.city,
      'area': profile.area,
      'address': profile.address,
      'bio': profile.bio,
      'languages': profile.languages,
      'consultationFeeLabel': profile.consultationFeeLabel,
      'isVerified': profile.isVerified,
    };
  }

  static ProfessionalProfile _sanitizeProfile(ProfessionalProfile profile) {
    return profile.copyWith(
      id: _cleanText(profile.id),
      displayName: _cleanText(profile.displayName),
      specialty: _cleanText(profile.specialty),
      structureName: _cleanText(profile.structureName),
      phone: _normalizePhone(profile.phone),
      city: _cleanText(profile.city),
      area: _cleanText(profile.area),
      address: _cleanText(profile.address),
      bio: _normalizeMultilineText(profile.bio),
      languages: _normalizeLanguages(profile.languages),
      consultationFeeLabel: _cleanText(profile.consultationFeeLabel),
      isVerified: profile.isVerified,
    );
  }

  static String _readString(
    Map<String, dynamic> map,
    String key,
    String fallback,
  ) {
    final value = map[key];
    if (value is String) {
      final normalized = _cleanText(value);
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return fallback;
  }

  static List<String> _readStringList(
    Map<String, dynamic> map,
    String key,
    List<String> fallback,
  ) {
    final value = map[key];
    if (value is List) {
      final items = _normalizeLanguages(value.whereType<String>().toList());
      if (items.isNotEmpty) {
        return items;
      }
    }
    return fallback;
  }

  static bool _readBool(
    Map<String, dynamic> map,
    String key,
    bool fallback,
  ) {
    final value = map[key];
    if (value is bool) return value;
    return fallback;
  }

  static String _cleanText(String value) {
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

  static String _normalizeMultilineText(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }

  static List<String> _normalizeLanguages(List<String> rawLanguages) {
    final seen = <String>{};
    final result = <String>[];

    for (final language in rawLanguages) {
      final value = _cleanText(language);
      if (value.isEmpty) continue;

      final key = value.toLowerCase();
      if (!seen.add(key)) continue;

      result.add(value);
    }

    return List.unmodifiable(result);
  }
}

final professionalProfileProvider =
    StateNotifierProvider<ProfessionalProfileController, ProfessionalProfile>(
  (ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    return ProfessionalProfileController(prefs);
  },
);
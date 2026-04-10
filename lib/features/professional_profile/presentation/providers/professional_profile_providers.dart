import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/models/app_user.dart';
import '../../../../core/utils/string_normalizers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/professional_profile.dart';

const _professionalProfilesStorageKey = 'professional_profiles_v2';
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
  ProfessionalProfileController(
    this._prefs, {
    required AppUser? authUser,
  })  : _authUser = authUser,
        super(_loadInitialState(_prefs, authUser: authUser));

  final SharedPreferences _prefs;
  final AppUser? _authUser;

  static ProfessionalProfile _loadInitialState(
    SharedPreferences prefs, {
    required AppUser? authUser,
  }) {
    final currentUser = authUser;

    if (currentUser == null || !currentUser.isProfessional) {
      return _sanitizeProfile(defaultProfessionalProfile);
    }

    final profilesMap = _readProfilesMap(prefs);
    final storageKey = _storageKeyForUser(currentUser);

    final storedRaw = profilesMap[storageKey];
    if (storedRaw is Map<String, dynamic>) {
      try {
        final storedProfile = _profileFromJson(
          storedRaw,
          fallback: _buildDefaultProfileForUser(currentUser),
        );
        final synced = _syncProfileWithAuth(
          storedProfile: storedProfile,
          authUser: currentUser,
        );

        if (!_sameProfessionalProfile(storedProfile, synced)) {
          profilesMap[storageKey] = _toJson(synced);
          _writeProfilesMap(prefs, profilesMap);
        }

        return synced;
      } catch (_) {
        final fallback = _buildDefaultProfileForUser(currentUser);
        profilesMap[storageKey] = _toJson(fallback);
        _writeProfilesMap(prefs, profilesMap);
        return fallback;
      }
    }

    final created = _buildDefaultProfileForUser(currentUser);
    profilesMap[storageKey] = _toJson(created);
    _writeProfilesMap(prefs, profilesMap);
    return created;
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

    if (_sameProfessionalProfile(nextState, state)) return;

    state = nextState;
    await _persist(nextState);
  }

  Future<void> resetProfile() async {
    final authUser = _authUser;
    final resetState = authUser != null && authUser.isProfessional
        ? _buildDefaultProfileForUser(authUser)
        : _sanitizeProfile(defaultProfessionalProfile);

    if (_sameProfessionalProfile(resetState, state)) return;

    state = resetState;
    await _persist(resetState);
  }

  Future<void> replaceProfile(ProfessionalProfile profile) async {
    final nextState = _sanitizeProfile(
      _authUser != null && _authUser.isProfessional
          ? _syncProfileWithAuth(
              storedProfile: profile,
              authUser: _authUser,
            )
          : profile,
    );

    if (_sameProfessionalProfile(nextState, state)) return;

    state = nextState;
    await _persist(nextState);
  }

  Future<void> _persist(ProfessionalProfile profile) async {
    final authUser = _authUser;
    if (authUser == null || !authUser.isProfessional) {
      return;
    }

    final sanitized = _sanitizeProfile(
      _syncProfileWithAuth(
        storedProfile: profile,
        authUser: authUser,
      ),
    );

    final profilesMap = _readProfilesMap(_prefs);
    profilesMap[_storageKeyForUser(authUser)] = _toJson(sanitized);
    _writeProfilesMap(_prefs, profilesMap);
  }

  static Map<String, dynamic> _readProfilesMap(SharedPreferences prefs) {
    final raw = prefs.getString(_professionalProfilesStorageKey);
    if (raw == null || raw.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // ignore
    }

    return <String, dynamic>{};
  }

  static void _writeProfilesMap(
    SharedPreferences prefs,
    Map<String, dynamic> profilesMap,
  ) {
    prefs.setString(
      _professionalProfilesStorageKey,
      jsonEncode(profilesMap),
    );
  }

  static ProfessionalProfile _profileFromJson(
    Map<String, dynamic> json, {
    required ProfessionalProfile fallback,
  }) {
    final profile = ProfessionalProfile(
      id: _readString(json, 'id', fallback.id),
      displayName: _readString(
        json,
        'displayName',
        fallback.displayName,
      ),
      specialty: _readString(
        json,
        'specialty',
        fallback.specialty,
      ),
      structureName: _readString(
        json,
        'structureName',
        fallback.structureName,
      ),
      phone: _readString(
        json,
        'phone',
        fallback.phone,
      ),
      city: _readString(
        json,
        'city',
        fallback.city,
      ),
      area: _readString(
        json,
        'area',
        fallback.area,
      ),
      address: _readString(
        json,
        'address',
        fallback.address,
      ),
      bio: _readString(
        json,
        'bio',
        fallback.bio,
      ),
      languages: _readStringList(
        json,
        'languages',
        fallback.languages,
      ),
      consultationFeeLabel: _readString(
        json,
        'consultationFeeLabel',
        fallback.consultationFeeLabel,
      ),
      isVerified: _readBool(
        json,
        'isVerified',
        fallback.isVerified,
      ),
    );

    return _sanitizeProfile(profile);
  }

  static ProfessionalProfile _buildDefaultProfileForUser(AppUser user) {
    final normalizedPhone = StringNormalizers.normalizePhoneCi(user.phone);
    final suffix = _lastPhoneDigits(normalizedPhone);
    final effectiveName = _effectiveProfessionalDisplayName(user.name, suffix);

    return _sanitizeProfile(
      ProfessionalProfile(
        id: user.id.trim().isEmpty ? 'pro_$suffix' : user.id.trim(),
        displayName: effectiveName,
        specialty: 'Professionnel de santé',
        structureName: '',
        phone: normalizedPhone,
        city: '',
        area: '',
        address: '',
        bio: '',
        languages: const ['Français'],
        consultationFeeLabel: '',
        isVerified: false,
      ),
    );
  }

  static ProfessionalProfile _syncProfileWithAuth({
    required ProfessionalProfile storedProfile,
    required AppUser authUser,
  }) {
    final nextId = authUser.id.trim();
    final nextPhone = StringNormalizers.normalizePhoneCi(authUser.phone);
    final currentDisplayName = storedProfile.displayName.trim();

    final shouldReplaceName = _isPlaceholderProfessionalName(currentDisplayName);
    final nextDisplayName = shouldReplaceName
        ? _effectiveProfessionalDisplayName(
            authUser.name,
            _lastPhoneDigits(nextPhone),
          )
        : currentDisplayName;

    return _sanitizeProfile(
      storedProfile.copyWith(
        id: nextId.isEmpty ? storedProfile.id : nextId,
        phone: nextPhone,
        displayName: nextDisplayName,
      ),
    );
  }

  static String _storageKeyForUser(AppUser user) {
    final id = user.id.trim();
    if (id.isNotEmpty) {
      return 'id:$id';
    }

    final phoneDigits = StringNormalizers.normalizePhoneCi(user.phone)
        .replaceAll(RegExp(r'\D'), '');

    if (phoneDigits.isNotEmpty) {
      return 'phone:$phoneDigits';
    }

    return 'fallback:${user.role.name}';
  }

  static String _effectiveProfessionalDisplayName(
    String rawName,
    String suffix,
  ) {
    final normalized = _cleanText(rawName);

    if (normalized.isEmpty ||
        normalized.toLowerCase() == 'utilisateur' ||
        normalized.toLowerCase() == 'nouveau professionnel') {
      return 'Professionnel $suffix';
    }

    return normalized;
  }

  static bool _isPlaceholderProfessionalName(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.isEmpty ||
        normalized == 'utilisateur' ||
        normalized == 'nouveau professionnel';
  }

  static String _lastPhoneDigits(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 4) {
      return digits.substring(digits.length - 4);
    }
    if (digits.isNotEmpty) {
      return digits;
    }
    return '0000';
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
    return StringNormalizers.normalizePhoneCi(value);
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

  static bool _sameProfessionalProfile(
    ProfessionalProfile a,
    ProfessionalProfile b,
  ) {
    return a.id == b.id &&
        a.displayName == b.displayName &&
        a.specialty == b.specialty &&
        a.structureName == b.structureName &&
        a.phone == b.phone &&
        a.city == b.city &&
        a.area == b.area &&
        a.address == b.address &&
        a.bio == b.bio &&
        _sameStringList(a.languages, b.languages) &&
        a.consultationFeeLabel == b.consultationFeeLabel &&
        a.isVerified == b.isVerified;
  }

  static bool _sameStringList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;

    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }

    return true;
  }
}

final professionalProfileProvider =
    StateNotifierProvider<ProfessionalProfileController, ProfessionalProfile>(
  (ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    final authUser = ref.watch(authControllerProvider).user;

    return ProfessionalProfileController(
      prefs,
      authUser: authUser,
    );
  },
  name: 'professionalProfileProvider',
);

final allProfessionalProfilesProvider = Provider<List<ProfessionalProfile>>(
  (ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    final rawMap = ProfessionalProfileController._readProfilesMap(prefs);

    final profiles = <ProfessionalProfile>[
      ProfessionalProfileController._sanitizeProfile(defaultProfessionalProfile),
    ];

    final seenIds = <String>{
      defaultProfessionalProfile.id.trim(),
    };

    for (final entry in rawMap.entries) {
      final value = entry.value;
      if (value is! Map) continue;

      try {
        final profile = ProfessionalProfileController._profileFromJson(
          Map<String, dynamic>.from(value),
          fallback: defaultProfessionalProfile,
        );

        final normalizedId = profile.id.trim();
        if (normalizedId.isEmpty) continue;
        if (!seenIds.add(normalizedId)) continue;

        profiles.add(profile);
      } catch (_) {
        // ignore invalid entry
      }
    }

    return List<ProfessionalProfile>.unmodifiable(profiles);
  },
  name: 'allProfessionalProfilesProvider',
);
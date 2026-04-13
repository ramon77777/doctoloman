import '../../../../core/utils/string_normalizers.dart';
import '../../domain/professional_profile.dart';
import '../../domain/professional_profile_repository.dart';
import '../datasources/professional_profile_local_datasource.dart';
import '../datasources/professional_profile_remote_datasource.dart';

const defaultProfessionalProfileId = 'pro_001';

final defaultProfessionalProfile = ProfessionalProfile(
  id: defaultProfessionalProfileId,
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

class ProfessionalProfileRepositoryImpl
    implements ProfessionalProfileRepository {
  ProfessionalProfileRepositoryImpl({
    required ProfessionalProfileLocalDataSource local,
    required ProfessionalProfileRemoteDataSource remote,
  })  : _local = local,
        _remote = remote;

  final ProfessionalProfileLocalDataSource _local;
  final ProfessionalProfileRemoteDataSource _remote;

  @override
  Future<ProfessionalProfile> getCurrent({
    required String? currentUserId,
    required String? currentUserName,
    required String? currentUserPhone,
    required bool isProfessional,
  }) async {
    if (!isProfessional) {
      return _sanitizeProfile(defaultProfessionalProfile);
    }

    final profilesMap = _local.readProfilesMap();
    final storageKey = _storageKeyForUser(
      id: currentUserId,
      phone: currentUserPhone,
      roleName: 'professional',
    );

    final fallback = _buildDefaultProfileForUser(
      id: currentUserId,
      name: currentUserName,
      phone: currentUserPhone,
    );

    final storedRaw = profilesMap[storageKey];
    if (storedRaw is Map<String, dynamic>) {
      try {
        final storedProfile = _profileFromJson(
          storedRaw,
          fallback: fallback,
        );
        final synced = _syncProfileWithAuth(
          storedProfile: storedProfile,
          authUserId: currentUserId,
          authUserName: currentUserName,
          authUserPhone: currentUserPhone,
        );

        if (!_sameProfessionalProfile(storedProfile, synced)) {
          profilesMap[storageKey] = _toJson(synced);
          await _local.writeProfilesMap(profilesMap);
        }

        return synced;
      } catch (_) {
        profilesMap[storageKey] = _toJson(fallback);
        await _local.writeProfilesMap(profilesMap);
        return fallback;
      }
    }

    final remoteProfile = await _remote.fetchCurrent(storageKey);
    if (remoteProfile != null) {
      final synced = _syncProfileWithAuth(
        storedProfile: remoteProfile,
        authUserId: currentUserId,
        authUserName: currentUserName,
        authUserPhone: currentUserPhone,
      );
      profilesMap[storageKey] = _toJson(synced);
      await _local.writeProfilesMap(profilesMap);
      return synced;
    }

    profilesMap[storageKey] = _toJson(fallback);
    await _local.writeProfilesMap(profilesMap);
    return fallback;
  }

  @override
  Future<List<ProfessionalProfile>> getAll() async {
    final rawMap = _local.readProfilesMap();

    final profiles = <ProfessionalProfile>[
      _sanitizeProfile(defaultProfessionalProfile),
    ];

    final seenIds = <String>{
      defaultProfessionalProfile.id.trim(),
    };

    for (final entry in rawMap.entries) {
      final value = entry.value;
      if (value is! Map) continue;

      try {
        final profile = _profileFromJson(
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

    final remoteProfiles = await _remote.fetchAll();
    for (final profile in remoteProfiles) {
      final normalizedId = profile.id.trim();
      if (normalizedId.isEmpty) continue;
      if (!seenIds.add(normalizedId)) continue;

      profiles.add(_sanitizeProfile(profile));
    }

    return List<ProfessionalProfile>.unmodifiable(profiles);
  }

  @override
  Future<void> saveCurrent(
    ProfessionalProfile profile, {
    required String? currentUserId,
    required String? currentUserName,
    required String? currentUserPhone,
    required bool isProfessional,
  }) async {
    if (!isProfessional) return;

    final synced = _sanitizeProfile(
      _syncProfileWithAuth(
        storedProfile: profile,
        authUserId: currentUserId,
        authUserName: currentUserName,
        authUserPhone: currentUserPhone,
      ),
    );

    final storageKey = _storageKeyForUser(
      id: currentUserId,
      phone: currentUserPhone,
      roleName: 'professional',
    );

    final profilesMap = _local.readProfilesMap();
    profilesMap[storageKey] = _toJson(synced);

    await _remote.saveCurrent(storageKey, synced);
    await _local.writeProfilesMap(profilesMap);
  }

  @override
  Future<void> resetCurrent({
    required String? currentUserId,
    required String? currentUserName,
    required String? currentUserPhone,
    required bool isProfessional,
  }) async {
    if (!isProfessional) return;

    final resetState = _buildDefaultProfileForUser(
      id: currentUserId,
      name: currentUserName,
      phone: currentUserPhone,
    );

    final storageKey = _storageKeyForUser(
      id: currentUserId,
      phone: currentUserPhone,
      roleName: 'professional',
    );

    final profilesMap = _local.readProfilesMap();
    profilesMap[storageKey] = _toJson(resetState);

    await _remote.resetCurrent(storageKey);
    await _local.writeProfilesMap(profilesMap);
  }
}

String _storageKeyForUser({
  required String? id,
  required String? phone,
  required String roleName,
}) {
  final normalizedId = (id ?? '').trim();
  if (normalizedId.isNotEmpty) {
    return 'id:$normalizedId';
  }

  final phoneDigits = StringNormalizers.normalizePhoneCi(phone ?? '')
      .replaceAll(RegExp(r'\D'), '');

  if (phoneDigits.isNotEmpty) {
    return 'phone:$phoneDigits';
  }

  return 'fallback:$roleName';
}

ProfessionalProfile _profileFromJson(
  Map<String, dynamic> json, {
  required ProfessionalProfile fallback,
}) {
  final profile = ProfessionalProfile(
    id: _readString(json, 'id', fallback.id),
    displayName: _readString(json, 'displayName', fallback.displayName),
    specialty: _readString(json, 'specialty', fallback.specialty),
    structureName: _readString(json, 'structureName', fallback.structureName),
    phone: _readString(json, 'phone', fallback.phone),
    city: _readString(json, 'city', fallback.city),
    area: _readString(json, 'area', fallback.area),
    address: _readString(json, 'address', fallback.address),
    bio: _readString(json, 'bio', fallback.bio),
    languages: _readStringList(json, 'languages', fallback.languages),
    consultationFeeLabel: _readString(
      json,
      'consultationFeeLabel',
      fallback.consultationFeeLabel,
    ),
    isVerified: _readBool(json, 'isVerified', fallback.isVerified),
  );

  return _sanitizeProfile(profile);
}

ProfessionalProfile _buildDefaultProfileForUser({
  required String? id,
  required String? name,
  required String? phone,
}) {
  final normalizedPhone = StringNormalizers.normalizePhoneCi(phone ?? '');
  final suffix = _lastPhoneDigits(normalizedPhone);
  final effectiveName = _effectiveProfessionalDisplayName(name ?? '', suffix);

  return _sanitizeProfile(
    ProfessionalProfile(
      id: (id ?? '').trim().isEmpty ? 'pro_$suffix' : (id ?? '').trim(),
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

ProfessionalProfile _syncProfileWithAuth({
  required ProfessionalProfile storedProfile,
  required String? authUserId,
  required String? authUserName,
  required String? authUserPhone,
}) {
  final nextId = (authUserId ?? '').trim();
  final nextPhone = StringNormalizers.normalizePhoneCi(authUserPhone ?? '');
  final currentDisplayName = storedProfile.displayName.trim();

  final shouldReplaceName = _isPlaceholderProfessionalName(currentDisplayName);
  final nextDisplayName = shouldReplaceName
      ? _effectiveProfessionalDisplayName(
          authUserName ?? '',
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

String _effectiveProfessionalDisplayName(String rawName, String suffix) {
  final normalized = _cleanText(rawName);

  if (normalized.isEmpty ||
      normalized.toLowerCase() == 'utilisateur' ||
      normalized.toLowerCase() == 'nouveau professionnel') {
    return 'Professionnel $suffix';
  }

  return normalized;
}

bool _isPlaceholderProfessionalName(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized.isEmpty ||
      normalized == 'utilisateur' ||
      normalized == 'nouveau professionnel';
}

String _lastPhoneDigits(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length >= 4) {
    return digits.substring(digits.length - 4);
  }
  if (digits.isNotEmpty) {
    return digits;
  }
  return '0000';
}

Map<String, dynamic> _toJson(ProfessionalProfile profile) {
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

ProfessionalProfile _sanitizeProfile(ProfessionalProfile profile) {
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

String _readString(
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

List<String> _readStringList(
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

bool _readBool(
  Map<String, dynamic> map,
  String key,
  bool fallback,
) {
  final value = map[key];
  if (value is bool) return value;
  return fallback;
}

String _cleanText(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

String _normalizePhone(String value) {
  return StringNormalizers.normalizePhoneCi(value);
}

String _normalizeMultilineText(String value) {
  return value
      .trim()
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n');
}

List<String> _normalizeLanguages(List<String> rawLanguages) {
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

bool _sameProfessionalProfile(
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

bool _sameStringList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;

  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }

  return true;
}
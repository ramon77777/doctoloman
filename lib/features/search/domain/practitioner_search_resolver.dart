import '../../professional_profile/domain/professional_profile.dart';
import 'search_item.dart';

class ResolvedPractitionerData {
  const ResolvedPractitionerData({
    required this.item,
    required this.structureName,
    required this.phone,
    required this.bio,
    required this.languages,
    required this.addressLabel,
    required this.usedProfileOverride,
  });

  final SearchItem item;
  final String structureName;
  final String phone;
  final String bio;
  final List<String> languages;
  final String addressLabel;

  /// Indique si les données du profil professionnel ont réellement été utilisées
  /// pour enrichir / remplacer les données issues de la recherche.
  final bool usedProfileOverride;

  bool get hasPhone => phone.trim().isNotEmpty;
  bool get hasBio => bio.trim().isNotEmpty;
  bool get hasLanguages => languages.isNotEmpty;
}

ResolvedPractitionerData resolvePractitionerData({
  required SearchItem baseItem,
  required ProfessionalProfile profile,
}) {
  final hasMatchingProfile = _hasMatchingPractitionerId(
    searchPractitionerId: baseItem.id,
    profilePractitionerId: profile.id,
  );

  if (!hasMatchingProfile) {
    return _buildFallbackResolvedData(baseItem);
  }

  final mergedIdentity = _mergeIdentity(
    baseItem: baseItem,
    profile: profile,
  );

  final mergedPricing = _mergePricing(
    baseItem: baseItem,
    profile: profile,
  );

  final resolvedItem = SearchItem(
    id: baseItem.id,
    type: baseItem.type,
    displayName: mergedIdentity.displayName,
    specialty: mergedIdentity.specialty,
    city: mergedIdentity.city,
    area: mergedIdentity.area,
    address: mergedIdentity.address,
    rating: baseItem.rating,
    reviewCount: baseItem.reviewCount,
    isVerified: profile.isVerified,
    isAvailableSoon: baseItem.isAvailableSoon,
    priceXofMin: mergedPricing.minPrice,
    priceXofMax: mergedPricing.maxPrice,
    latitude: baseItem.latitude,
    longitude: baseItem.longitude,
  );

  return ResolvedPractitionerData(
    item: resolvedItem,
    structureName: _pickNonEmpty(
      profile.structureName,
      _defaultStructureName,
    ),
    phone: _normalizePhone(profile.phone),
    bio: profile.bio.trim(),
    languages: _normalizeLanguages(profile.languages),
    addressLabel: _buildAddressLabel(
      address: mergedIdentity.address,
      area: mergedIdentity.area,
      city: mergedIdentity.city,
      fallback: resolvedItem.locationLabel,
    ),
    usedProfileOverride: true,
  );
}

ResolvedPractitionerData _buildFallbackResolvedData(SearchItem baseItem) {
  return ResolvedPractitionerData(
    item: baseItem,
    structureName: _defaultStructureName,
    phone: '',
    bio: '',
    languages: const [],
    addressLabel: _buildAddressLabel(
      address: baseItem.address,
      area: baseItem.area,
      city: baseItem.city,
      fallback: baseItem.locationLabel,
    ),
    usedProfileOverride: false,
  );
}

bool _hasMatchingPractitionerId({
  required String searchPractitionerId,
  required String profilePractitionerId,
}) {
  return searchPractitionerId.trim() == profilePractitionerId.trim();
}

({String displayName, String specialty, String city, String area, String address})
    _mergeIdentity({
  required SearchItem baseItem,
  required ProfessionalProfile profile,
}) {
  return (
    displayName: _pickNonEmpty(profile.displayName, baseItem.displayName),
    specialty: _pickNonEmpty(profile.specialty, baseItem.specialty),
    city: _pickNonEmpty(profile.city, baseItem.city),
    area: _pickNonEmpty(profile.area, baseItem.area),
    address: _pickNonEmpty(profile.address, baseItem.address),
  );
}

({int minPrice, int maxPrice}) _mergePricing({
  required SearchItem baseItem,
  required ProfessionalProfile profile,
}) {
  final (parsedMinPrice, parsedMaxPrice) =
      extractPriceRange(profile.consultationFeeLabel);

  final resolvedMinPrice =
      parsedMinPrice > 0 ? parsedMinPrice : baseItem.priceXofMin;
  final resolvedMaxPrice =
      parsedMaxPrice > 0 ? parsedMaxPrice : baseItem.priceXofMax;

  final safeMinPrice = resolvedMinPrice < 0 ? 0 : resolvedMinPrice;
  final safeMaxPrice = resolvedMaxPrice < 0 ? 0 : resolvedMaxPrice;

  if (safeMinPrice == 0 && safeMaxPrice == 0) {
    return (
      minPrice: baseItem.priceXofMin,
      maxPrice: baseItem.priceXofMax,
    );
  }

  if (safeMinPrice == 0) {
    return (
      minPrice: safeMaxPrice,
      maxPrice: safeMaxPrice,
    );
  }

  if (safeMaxPrice == 0) {
    return (
      minPrice: safeMinPrice,
      maxPrice: safeMinPrice,
    );
  }

  return safeMinPrice <= safeMaxPrice
      ? (
          minPrice: safeMinPrice,
          maxPrice: safeMaxPrice,
        )
      : (
          minPrice: safeMaxPrice,
          maxPrice: safeMinPrice,
        );
}

const String _defaultStructureName = 'Structure non renseignée';
const String _defaultAddressLabel = 'Adresse non renseignée';

(int, int) extractPriceRange(String label) {
  final normalized = label.trim();
  if (normalized.isEmpty) return (0, 0);

  final matches = RegExp(r'\d[\d\s.,]*')
      .allMatches(normalized)
      .map((match) => _parseLooseInt(match.group(0)))
      .whereType<int>()
      .where((value) => value > 0)
      .toList();

  if (matches.isEmpty) return (0, 0);
  if (matches.length == 1) return (matches.first, matches.first);

  final first = matches.first;
  final last = matches.last;
  return first <= last ? (first, last) : (last, first);
}

int? _parseLooseInt(String? raw) {
  if (raw == null) return null;

  final digitsOnly = raw.replaceAll(RegExp(r'[^\d]'), '');
  if (digitsOnly.isEmpty) return null;

  return int.tryParse(digitsOnly);
}

String _pickNonEmpty(String primary, String fallback) {
  final primaryValue = primary.trim();
  if (primaryValue.isNotEmpty) return primaryValue;

  return fallback.trim();
}

String _normalizePhone(String raw) {
  return raw.trim();
}

List<String> _normalizeLanguages(List<String> rawLanguages) {
  final seen = <String>{};
  final result = <String>[];

  for (final language in rawLanguages) {
    final value = language.trim();
    if (value.isEmpty) continue;

    final key = value.toLowerCase();
    if (!seen.add(key)) continue;

    result.add(value);
  }

  return List.unmodifiable(result);
}

String _buildAddressLabel({
  required String address,
  required String area,
  required String city,
  required String fallback,
}) {
  final normalizedAddress = address.trim();
  final normalizedArea = area.trim();
  final normalizedCity = city.trim();
  final normalizedFallback = fallback.trim();

  final localityParts = <String>[
    if (normalizedArea.isNotEmpty) normalizedArea,
    if (normalizedCity.isNotEmpty) normalizedCity,
  ];

  final parts = <String>[
    if (normalizedAddress.isNotEmpty) normalizedAddress,
    if (localityParts.isNotEmpty) localityParts.join(', '),
  ];

  if (parts.isNotEmpty) {
    return parts.join('\n');
  }

  if (normalizedFallback.isNotEmpty) {
    return normalizedFallback;
  }

  return _defaultAddressLabel;
}
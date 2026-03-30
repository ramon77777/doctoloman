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
  });

  final SearchItem item;
  final String structureName;
  final String phone;
  final String bio;
  final List<String> languages;
  final String addressLabel;

  bool get hasPhone => phone.trim().isNotEmpty;
  bool get hasBio => bio.trim().isNotEmpty;
  bool get hasLanguages => languages.isNotEmpty;
}

ResolvedPractitionerData resolvePractitionerData({
  required SearchItem baseItem,
  required ProfessionalProfile profile,
}) {
  if (baseItem.id != profile.id) {
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
    );
  }

  final resolvedDisplayName =
      _pickNonEmpty(profile.displayName, baseItem.displayName);
  final resolvedSpecialty =
      _pickNonEmpty(profile.specialty, baseItem.specialty);
  final resolvedCity = _pickNonEmpty(profile.city, baseItem.city);
  final resolvedArea = _pickNonEmpty(profile.area, baseItem.area);
  final resolvedAddress = _pickNonEmpty(profile.address, baseItem.address);

  final (parsedMinPrice, parsedMaxPrice) =
      extractPriceRange(profile.consultationFeeLabel);

  final resolvedMinPrice =
      parsedMinPrice > 0 ? parsedMinPrice : baseItem.priceXofMin;
  final resolvedMaxPrice =
      parsedMaxPrice > 0 ? parsedMaxPrice : baseItem.priceXofMax;

  final resolvedItem = SearchItem(
    id: baseItem.id,
    type: baseItem.type,
    displayName: resolvedDisplayName,
    specialty: resolvedSpecialty,
    city: resolvedCity,
    area: resolvedArea,
    address: resolvedAddress,
    rating: baseItem.rating,
    reviewCount: baseItem.reviewCount,
    isVerified: profile.isVerified,
    isAvailableSoon: baseItem.isAvailableSoon,
    priceXofMin: resolvedMinPrice,
    priceXofMax: resolvedMaxPrice,
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
      address: resolvedAddress,
      area: resolvedArea,
      city: resolvedCity,
      fallback: resolvedItem.locationLabel,
    ),
  );
}

const String _defaultStructureName = 'Structure non renseignée';

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
  final value = primary.trim();
  return value.isNotEmpty ? value : fallback.trim();
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
    if (seen.contains(key)) continue;

    seen.add(key);
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

  final locality = [
    if (normalizedArea.isNotEmpty) normalizedArea,
    if (normalizedCity.isNotEmpty) normalizedCity,
  ].join(', ');

  final parts = <String>[
    if (normalizedAddress.isNotEmpty) normalizedAddress,
    if (locality.isNotEmpty) locality,
  ];

  if (parts.isEmpty) {
    final fallbackValue = fallback.trim();
    return fallbackValue.isNotEmpty ? fallbackValue : 'Adresse non renseignée';
  }

  return parts.join('\n');
}
import '../domain/pharmacy.dart';

class MockPharmaciesData {
  static final List<Pharmacy> _items = [
    Pharmacy(
      id: 'ph_001',
      name: 'Pharmacie Sainte Marie',
      address: 'Cocody, II Plateaux',
      city: 'Abidjan',
      area: 'Cocody',
      phone: '+225 07 01 02 03 04',
      openingHours: '20:00 - 08:00',
      isOnDuty: true,
      latitude: 5.3600,
      longitude: -3.9750,
    ),
    Pharmacy(
      id: 'ph_002',
      name: 'Pharmacie du Centre',
      address: 'Plateau, Avenue Chardy',
      city: 'Abidjan',
      area: 'Plateau',
      phone: '+225 07 08 09 10 11',
      openingHours: '24h/24',
      isOnDuty: true,
      latitude: 5.3240,
      longitude: -4.0200,
    ),
    Pharmacy(
      id: 'ph_003',
      name: 'Pharmacie Les Arcades',
      address: 'Yopougon, Siporex',
      city: 'Abidjan',
      area: 'Yopougon',
      phone: '+225 05 06 07 08 09',
      openingHours: '08:00 - 20:00',
      isOnDuty: false,
      latitude: 5.3360,
      longitude: -4.0790,
    ),
    Pharmacy(
      id: 'ph_010',
      name: 'Pharmacie Bingerville Centre',
      address: 'Centre-ville Bingerville',
      city: 'Bingerville',
      area: 'Centre',
      phone: '+225 01 23 45 67 89',
      openingHours: '20:00 - 08:00',
      isOnDuty: true,
      latitude: 5.3550,
      longitude: -3.8860,
    ),
    Pharmacy(
      id: 'ph_011',
      name: 'Pharmacie Akandjé',
      address: 'Akandjé Marché',
      city: 'Bingerville',
      area: 'Akandjé',
      phone: '+225 01 11 22 33 44',
      openingHours: '08:00 - 20:00',
      isOnDuty: false,
      latitude: 5.3650,
      longitude: -3.8700,
    ),
    Pharmacy(
      id: 'ph_012',
      name: 'Pharmacie Feh Kessé',
      address: 'Route Bingerville',
      city: 'Bingerville',
      area: 'Feh Kessé',
      phone: '+225 01 55 66 77 88',
      openingHours: '24h/24',
      isOnDuty: true,
      latitude: 5.3505,
      longitude: -3.8920,
    ),
    Pharmacy(
      id: 'ph_020',
      name: 'Pharmacie de la Paix',
      address: 'Bouaké, Quartier Commerce',
      city: 'Bouaké',
      area: 'Centre',
      phone: '+225 01 01 01 01 01',
      openingHours: '20:00 - 07:00',
      isOnDuty: true,
      latitude: 7.6900,
      longitude: -5.0300,
    ),
    Pharmacy(
      id: 'ph_030',
      name: 'Pharmacie du Marché',
      address: 'Yamoussoukro, Zone Habitat',
      city: 'Yamoussoukro',
      area: 'Habitat',
      phone: '+225 02 02 02 02 02',
      openingHours: '24h/24',
      isOnDuty: true,
      latitude: 6.8200,
      longitude: -5.2900,
    ),
  ];

  static List<Pharmacy> items() {
    return List<Pharmacy>.unmodifiable(_items);
  }

  static List<String> cities() {
    final cities = _items
        .map((item) => item.city.trim())
        .where((city) => city.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return List<String>.unmodifiable(cities);
  }
}
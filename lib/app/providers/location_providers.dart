import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Legacy location helpers.
/// Gardé temporairement pour compatibilité avec d’anciens écrans / imports.
/// Le flux actif du module pharmacies passe désormais par:
/// - locationConsentProvider
/// - userLocationProvider
/// - pharmacyFiltersProvider
///
/// Quand plus aucun fichier n’importe ce module, il pourra être supprimé.

class UserLocation {
  const UserLocation({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

sealed class LocationState {
  const LocationState();
}

class LocationIdle extends LocationState {
  const LocationIdle();
}

class LocationLoading extends LocationState {
  const LocationLoading();
}

class LocationDenied extends LocationState {
  const LocationDenied({required this.permanently});

  final bool permanently;
}

class LocationReady extends LocationState {
  const LocationReady(this.location);

  final UserLocation location;
}

class LocationError extends LocationState {
  const LocationError(this.message);

  final String message;
}

class LocationController extends StateNotifier<LocationState> {
  LocationController() : super(const LocationIdle());

  Future<UserLocation?> requestCurrentLocation() async {
    state = const LocationLoading();

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = const LocationError(
          'Localisation désactivée. Active-la dans les réglages.',
        );
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        state = const LocationDenied(permanently: false);
        return null;
      }

      if (permission == LocationPermission.deniedForever) {
        state = const LocationDenied(permanently: true);
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );

      final location = UserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      state = LocationReady(location);
      return location;
    } catch (e) {
      state = LocationError('Impossible d’obtenir la localisation: $e');
      return null;
    }
  }

  void reset() {
    state = const LocationIdle();
  }
}

final locationProvider =
    StateNotifierProvider<LocationController, LocationState>(
  (ref) => LocationController(),
  name: 'legacyLocationProvider',
);

double distanceMeters(UserLocation a, UserLocation b) {
  return Geolocator.distanceBetween(
    a.latitude,
    a.longitude,
    b.latitude,
    b.longitude,
  );
}
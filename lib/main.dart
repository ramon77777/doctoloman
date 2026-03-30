import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/services/local_notifications_service.dart';
import 'features/appointments/data/appointments_local_storage.dart';
import 'features/auth/presentation/providers/auth_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sharedPreferences = await SharedPreferences.getInstance();

  await LocalNotificationsService.instance.init();

  final appointmentsStorage = AppointmentsLocalStorage(sharedPreferences);
  final existingAppointments = await appointmentsStorage.readAll();

  await LocalNotificationsService.instance
      .syncAppointments(existingAppointments);

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const DoctoLomanApp(),
    ),
  );
}
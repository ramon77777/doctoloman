import 'package:flutter/material.dart';

import 'router/app_router.dart';
import 'router/app_routes.dart';
import 'theme/app_theme.dart';

class DoctoLomanApp extends StatelessWidget {
  const DoctoLomanApp({super.key});

  Map<String, WidgetBuilder> _sanitizedStaticRoutes() {
    final routes = Map<String, WidgetBuilder>.from(AppRoutes.staticRoutes());

    routes.remove(AppRoutes.loginPhone);
    routes.remove(AppRoutes.searchResults);
    routes.remove(AppRoutes.practitionerDetail);
    routes.remove(AppRoutes.pharmacyDetail);
    routes.remove(AppRoutes.appointmentDetail);
    routes.remove(AppRoutes.medicalRecordDetail);
    routes.remove(AppRoutes.medicalRecordEdit);
    routes.remove(AppRoutes.professionalAppointmentDetail);

    return routes;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Docto'Loman",
      theme: AppTheme.light,
      initialRoute: AppRoutes.home,
      routes: _sanitizedStaticRoutes(),
      onGenerateRoute: AppRouter.onGenerateRoute,
      onUnknownRoute: AppRouter.onUnknownRoute,
    );
  }
}
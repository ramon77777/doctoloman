import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/app_user.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/home/presentation/pages/home_entry_page.dart';

enum AppRouteAccess {
  public,
  unauthenticatedOnly,
  authenticatedOnly,
  patientOnly,
  professionalOnly,
}

class RouteGuard extends ConsumerWidget {
  const RouteGuard({
    super.key,
    required this.child,
    required this.access,
  });

  final Widget child;
  final AppRouteAccess access;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;
    final isAuthenticated = authState.isAuthenticated && user != null;

    switch (access) {
      case AppRouteAccess.public:
        return child;

      case AppRouteAccess.unauthenticatedOnly:
        if (!isAuthenticated) {
          return child;
        }
        return const HomeEntryPage();

      case AppRouteAccess.authenticatedOnly:
        if (isAuthenticated) {
          return child;
        }
        return const HomeEntryPage();

      case AppRouteAccess.patientOnly:
        if (isAuthenticated && user.role == AppUserRole.patient) {
          return child;
        }
        return const HomeEntryPage();

      case AppRouteAccess.professionalOnly:
        if (isAuthenticated && user.role == AppUserRole.professional) {
          return child;
        }
        return const HomeEntryPage();
    }
  }
}
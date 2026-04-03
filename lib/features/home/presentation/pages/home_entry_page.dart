import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../professional_home/presentation/pages/professional_home_page.dart';
import 'home_dashboard_page.dart';
import 'home_public_page.dart';

class HomeEntryPage extends ConsumerWidget {
  const HomeEntryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;

    if (!authState.isAuthenticated || user == null) {
      return const HomePublicPage();
    }

    if (user.role == AppUserRole.professional) {
      return const ProfessionalHomePage();
    }

    return const HomeDashboardPage();
  }
}
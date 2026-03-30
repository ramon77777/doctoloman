import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import 'home_dashboard_page.dart';
import 'home_public_page.dart';

class HomeEntryPage extends ConsumerWidget {
  const HomeEntryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    if (authState.isAuthenticated) {
      return const HomeDashboardPage();
    }

    return const HomePublicPage();
  }
}
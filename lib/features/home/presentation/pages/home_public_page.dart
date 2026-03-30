import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../../../app/router/app_routes.dart';
import '../../../../app/router/route_args.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class HomePublicPage extends ConsumerStatefulWidget {
  const HomePublicPage({super.key});

  @override
  ConsumerState<HomePublicPage> createState() => _HomePublicPageState();
}

class _HomePublicPageState extends ConsumerState<HomePublicPage> {
  final _whatCtrl = TextEditingController();
  final _whereCtrl = TextEditingController();

  bool _canSearch = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _whatCtrl.addListener(_recomputeCanSearch);
    _whereCtrl.addListener(_recomputeCanSearch);
    _recomputeCanSearch();
  }

  @override
  void dispose() {
    _whatCtrl.removeListener(_recomputeCanSearch);
    _whereCtrl.removeListener(_recomputeCanSearch);
    _whatCtrl.dispose();
    _whereCtrl.dispose();
    super.dispose();
  }

  void _unfocus() => FocusManager.instance.primaryFocus?.unfocus();

  void _recomputeCanSearch() {
    final what = _whatCtrl.text.trim();
    final where = _whereCtrl.text.trim();
    final next = what.isNotEmpty || where.isNotEmpty;

    if (next != _canSearch) {
      setState(() => _canSearch = next);
    }
  }

  Future<void> _navigateSafely(Future<void> Function() action) async {
    if (_isNavigating) return;

    _unfocus();
    setState(() => _isNavigating = true);

    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _isNavigating = false);
      }
    }
  }

  Future<void> _onSearch() async {
    if (!_canSearch) return;

    final what = _whatCtrl.text.trim();
    final where = _whereCtrl.text.trim();

    await _navigateSafely(() async {
      await Navigator.of(context).pushNamed(
        AppRoutes.searchResults,
        arguments: SearchResultsArgs(
          initialWhat: what,
          initialWhere: where,
        ),
      );
    });
  }

  void _goToAuth({required bool isSignup}) {
    _unfocus();
    Navigator.of(context).pushNamed(
      AppRoutes.loginPhone,
      arguments: {'isSignup': isSignup},
    );
  }

  Future<void> _openPharmacies() async {
    await _navigateSafely(() async {
      await Navigator.of(context).pushNamed(AppRoutes.pharmacies);
    });
  }

  Future<void> _openOnDutyPharmacies() async {
    await _navigateSafely(() async {
      await Navigator.of(context).pushNamed(AppRoutes.pharmaciesOnDuty);
    });
  }

  Future<void> _openAppointments() async {
    await _navigateSafely(() async {
      await Navigator.of(context).pushNamed(AppRoutes.appointments);
    });
  }

  Future<void> _openProfile() async {
    await _navigateSafely(() async {
      await Navigator.of(context).pushNamed(AppRoutes.profile);
    });
  }

  Future<void> _openProfessionalSpace() async {
    await _navigateSafely(() async {
      await Navigator.of(context).pushNamed(AppRoutes.professionalHome);
    });
  }

  void _onLogin() => _goToAuth(isSignup: false);

  void _onSignup() => _goToAuth(isSignup: true);

  Future<void> _onLogout() async {
    await ref.read(authControllerProvider.notifier).logout();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Vous êtes déconnecté.'),
      ),
    );
  }

  Future<void> _showAccountSheet() async {
    final authState = ref.read(authControllerProvider);
    final user = authState.user;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final textTheme = Theme.of(context).textTheme;
        final cs = Theme.of(context).colorScheme;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mon compte', style: textTheme.titleLarge),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'Utilisateur',
                        style: textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.phone ?? 'Téléphone non disponible',
                        style: textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _openProfile();
                    },
                    icon: const Icon(Icons.person_outline),
                    label: const Text('Voir mon profil'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _openAppointments();
                    },
                    icon: const Icon(Icons.event_note_outlined),
                    label: const Text('Mes rendez-vous'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await _onLogout();
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Se déconnecter'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isAuthenticated = authState.isAuthenticated;
    final user = authState.user;

    final textTheme = Theme.of(context).textTheme;
    final w = MediaQuery.of(context).size.width;

    final canSubmitSearch = _canSearch && !_isNavigating;
    final canTapQuickActions = !_isNavigating;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverAppBar(
              pinned: true,
              elevation: 0,
              backgroundColor: AppColors.background,
              surfaceTintColor: AppColors.background,
              leadingWidth: 56,
              leading: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      'assets/logo/logo.jpg',
                      height: 28,
                      width: 28,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              title: const Text(
                "Docto'Loman",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                if (!isAuthenticated) ...[
                  if (w < 360)
                    PopupMenuButton<_AuthAction>(
                      tooltip: 'Compte',
                      onSelected: (value) {
                        if (value == _AuthAction.login) _onLogin();
                        if (value == _AuthAction.signup) _onSignup();
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: _AuthAction.login,
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.login),
                            title: Text('Connexion'),
                          ),
                        ),
                        PopupMenuItem(
                          value: _AuthAction.signup,
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.person_add_alt_1),
                            title: Text('Inscription'),
                          ),
                        ),
                      ],
                    )
                  else if (w < 430)
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Connexion',
                          onPressed: _onLogin,
                          icon: const Icon(Icons.login),
                        ),
                        IconButton(
                          tooltip: 'Inscription',
                          onPressed: _onSignup,
                          icon: const Icon(Icons.person_add_alt_1),
                        ),
                        const SizedBox(width: 8),
                      ],
                    )
                  else
                    Row(
                      children: [
                        TextButton(
                          onPressed: _onLogin,
                          child: const Text('Connexion'),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: FilledButton(
                            onPressed: _onSignup,
                            child: const Text('Inscription'),
                          ),
                        ),
                      ],
                    ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Center(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: _showAccountSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person_outline, size: 18),
                              const SizedBox(width: 6),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: w < 380 ? 72 : 110,
                                ),
                                child: Text(
                                  user?.name ?? 'Compte',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.labelLarge,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAuthenticated
                          ? 'Bonjour ${user?.name ?? ''}'.trim()
                          : 'Trouvez un professionnel de santé',
                      style: textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isAuthenticated
                          ? 'Prenez rendez-vous et suivez vos soins simplement.'
                          : 'Prenez rendez-vous partout en Côte d’Ivoire.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickySearchHeader(
                minExtent: 230,
                maxExtent: 230,
                child: _SearchCard(
                  whatCtrl: _whatCtrl,
                  whereCtrl: _whereCtrl,
                  canSearch: canSubmitSearch,
                  isBusy: _isNavigating,
                  onSearch: _onSearch,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isAuthenticated) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                height: 44,
                                width: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.secondary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.verified_user_outlined,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Session active',
                                      style: textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      user?.phone ?? '',
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text('Accès rapide', style: textTheme.titleMedium),
                    const SizedBox(height: 12),
                    _QuickActionCard(
                      icon: Icons.person_outline,
                      title: 'Mon profil',
                      subtitle: 'Consulter mes informations et ma session',
                      enabled: canTapQuickActions && isAuthenticated,
                      onTap: _openProfile,
                    ),
                    const SizedBox(height: 12),
                    _QuickActionCard(
                      icon: Icons.event_note_outlined,
                      title: 'Mes rendez-vous',
                      subtitle: 'Suivre vos rendez-vous confirmés et passés',
                      enabled: canTapQuickActions,
                      onTap: _openAppointments,
                    ),
                    const SizedBox(height: 12),
                    _QuickActionCard(
                      icon: Icons.local_pharmacy_outlined,
                      title: 'Trouver une pharmacie',
                      subtitle: 'Pharmacies proches + horaires',
                      enabled: canTapQuickActions,
                      onTap: _openPharmacies,
                    ),
                    const SizedBox(height: 12),
                    _QuickActionCard(
                      icon: Icons.nightlight_outlined,
                      title: 'Pharmacies de garde',
                      subtitle: 'Voir les pharmacies ouvertes la nuit',
                      enabled: canTapQuickActions,
                      onTap: _openOnDutyPharmacies,
                    ),
                    const SizedBox(height: 12),
                    _QuickActionCard(
                      icon: Icons.business_center_outlined,
                      title: 'Espace professionnel',
                      subtitle:
                          'Accéder au tableau de bord des professionnels de santé',
                      enabled: canTapQuickActions,
                      onTap: _openProfessionalSpace,
                    ),
                    const SizedBox(height: 12),
                    _QuickActionCard(
                      icon: Icons.video_call_outlined,
                      title: 'Téléconsultation',
                      subtitle: isAuthenticated
                          ? 'Consultation à distance bientôt disponible'
                          : 'Consultation à distance (connexion requise)',
                      enabled: canTapQuickActions,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Téléconsultation bientôt disponible.',
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vos données sont protégées',
                              style: textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Hébergement local • Accès sous consentement • Traçabilité',
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _AuthAction { login, signup }

class _SearchCard extends StatelessWidget {
  const _SearchCard({
    required this.whatCtrl,
    required this.whereCtrl,
    required this.canSearch,
    required this.isBusy,
    required this.onSearch,
  });

  final TextEditingController whatCtrl;
  final TextEditingController whereCtrl;
  final bool canSearch;
  final bool isBusy;
  final Future<void> Function() onSearch;

  @override
  Widget build(BuildContext context) {
    const contentPad = EdgeInsets.symmetric(horizontal: 12, vertical: 12);

    return Material(
      color: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                TextField(
                  controller: whatCtrl,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.sentences,
                  autofillHints: const [AutofillHints.jobTitle],
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: contentPad,
                    labelText: 'Spécialité / médecin / établissement',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: whereCtrl,
                  textInputAction: TextInputAction.search,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.addressCity],
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: contentPad,
                    labelText: 'Localisation',
                    prefixIcon: Icon(Icons.place_outlined),
                  ),
                  onSubmitted: (_) => onSearch(),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    onPressed: canSearch ? () => onSearch() : null,
                    child: isBusy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Rechercher'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StickySearchHeader extends SliverPersistentHeaderDelegate {
  _StickySearchHeader({
    required this.minExtent,
    required this.maxExtent,
    required this.child,
  });

  @override
  final double minExtent;

  @override
  final double maxExtent;

  final Widget child;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final showShadow = overlapsContent || shrinkOffset > 0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _StickySearchHeader oldDelegate) {
    return oldDelegate.minExtent != minExtent ||
        oldDelegate.maxExtent != maxExtent ||
        oldDelegate.child != child;
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.enabled,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.6,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
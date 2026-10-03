import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/map_service.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/map_service_provider.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final providerKind = ref.watch(selectedMapProviderProvider);
    final providerNotifier =
        ref.read(selectedMapProviderProvider.notifier);
    final mapService = ref.watch(mapServiceProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle(title: l10n.language),
          _Card(
            child: Column(
              children: [
                _ChoiceTile(
                  title: 'فارسی',
                  selected: settings.locale.languageCode == 'fa',
                  onTap: () => settingsNotifier.setLocale(
                    const Locale('fa', 'IR'),
                  ),
                ),
                _ChoiceTile(
                  title: 'العربية',
                  selected: settings.locale.languageCode == 'ar',
                  onTap: () => settingsNotifier.setLocale(
                    const Locale('ar', 'SA'),
                  ),
                ),
                _ChoiceTile(
                  title: 'English',
                  selected: settings.locale.languageCode == 'en',
                  onTap: () => settingsNotifier.setLocale(
                    const Locale('en', 'US'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: l10n.theme),
          _Card(
            child: Column(
              children: [
                _ChoiceTile(
                  title: l10n.themeLight,
                  selected: settings.themeMode == ThemeMode.light,
                  onTap: () =>
                      settingsNotifier.setThemeMode(ThemeMode.light),
                ),
                _ChoiceTile(
                  title: l10n.themeDark,
                  selected: settings.themeMode == ThemeMode.dark,
                  onTap: () =>
                      settingsNotifier.setThemeMode(ThemeMode.dark),
                ),
                _ChoiceTile(
                  title: l10n.themeSystem,
                  selected: settings.themeMode == ThemeMode.system,
                  onTap: () =>
                      settingsNotifier.setThemeMode(ThemeMode.system),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: l10n.routeType),
          _Card(
            child: Column(
              children: [
                for (final type in RouteType.values)
                  _ChoiceTile(
                    title: _routeTypeLabel(l10n, type),
                    subtitle: mapService.supportedRouteTypes.contains(type)
                        ? null
                        : l10n.comingSoon,
                    selected: settings.routeType == type,
                    enabled:
                        mapService.supportedRouteTypes.contains(type),
                    onTap: () => settingsNotifier.setRouteType(type),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: l10n.voiceGuidance),
          _Card(
            child: SwitchListTile(
              value: settings.voiceEnabled,
              onChanged: settingsNotifier.setVoice,
              title: Text(l10n.voiceGuidance),
              secondary: Icon(
                settings.voiceEnabled
                    ? Icons.volume_up_outlined
                    : Icons.volume_off_outlined,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(title: l10n.mapProvider),
          _Card(
            child: Column(
              children: [
                _ChoiceTile(
                  title: l10n.neshan,
                  selected: providerKind == MapProviderKind.neshan,
                  onTap: () {
                    providerNotifier.state = MapProviderKind.neshan;
                    if (!_neshanSupportedRouteTypes.contains(
                      settings.routeType,
                    )) {
                      settingsNotifier.setRouteType(RouteType.car);
                    }
                  },
                ),
                _ChoiceTile(
                  title: l10n.parsimap,
                  subtitle: l10n.comingSoon,
                  selected: providerKind == MapProviderKind.parsimap,
                  enabled: false,
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              '${l10n.appName} — ${l10n.version} 0.1.0',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.50),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static const Set<RouteType> _neshanSupportedRouteTypes = {
    RouteType.car,
    RouteType.motorcycle,
  };

  String _routeTypeLabel(
    AppLocalizations l10n,
    RouteType type,
  ) {
    return switch (type) {
      RouteType.car => l10n.car,
      RouteType.motorcycle => l10n.motorcycle,
      RouteType.bicycle => l10n.bicycle,
      RouteType.pedestrian => l10n.pedestrian,
    };
  }
}

class _ChoiceTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _ChoiceTile({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListTile(
      enabled: enabled,
      onTap: enabled ? onTap : null,
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: selected
          ? Icon(
              Icons.check_circle,
              color: colors.primary,
            )
          : const Icon(Icons.circle_outlined),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        bottom: 8,
        start: 4,
        end: 4,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: child,
      ),
    );
  }
}

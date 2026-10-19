import 'package:flutter/material.dart';

import '../main.dart';
import '../network.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'devices_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = FluxColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: app,
          builder: (context, _) {
            final p = app.pairing;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ListView(
                children: [
                  PageHeader(
                    title: 'Settings',
                    onBack: () => Navigator.pop(context),
                    trailing: Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Icon(Icons.settings_outlined, color: c.text, size: 22),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _section(context, 'APPEARANCE'),
                  const _ThemeToggle(),
                  const SizedBox(height: 22),
                  Divider(color: c.border, height: 1),
                  const SizedBox(height: 22),
                  _section(context, 'PAIRED DEVICE'),
                  _Row(
                    icon: Icons.laptop,
                    title: p?.name ?? 'No laptop paired',
                    subtitle: p?.activeIp,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const Scaffold(body: DevicesScreen(showBack: true)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Divider(color: c.border, height: 1),
                  const SizedBox(height: 22),
                  _section(context, 'SHORTCUTS'),
                  _Row(
                    icon: Icons.widgets_outlined,
                    title: 'Add home-screen widget',
                    subtitle: 'One tap sends your clipboard',
                    onTap: () async {
                      final r = await LauncherShortcuts.pinWidget();
                      if (r == 'unsupported' && context.mounted) {
                        _toast(context, "Press and hold the home screen, tap Widgets, then pick Flux.");
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  _Row(
                    icon: Icons.tune,
                    title: 'Add quick-settings tile',
                    subtitle: 'Send from the pull-down panel',
                    onTap: () async {
                      final r = await LauncherShortcuts.addTile();
                      if (r != 'requested' && context.mounted) {
                        _toast(context, "Pull down the quick settings, tap the pencil, and drag 'Send clipboard' in.");
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  Divider(color: c.border, height: 1),
                  const SizedBox(height: 22),
                  _section(context, 'HISTORY'),
                  _Row(
                    icon: Icons.delete_outline,
                    title: 'Clear History',
                    onTap: () async {
                      await app.clearHistory();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('History cleared.')));
                      }
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _toast(BuildContext context, String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Widget _section(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(t, style: label(context, size: 11)),
      );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _Row({required this.icon, required this.title, this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = FluxColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            IconCircle(icon: icon, size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: sans(context, size: 15)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!, style: label(context, size: 11)),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: c.text, size: 22),
          ],
        ),
      ),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context) {
    final c = FluxColors.of(context);
    Widget seg(String text, ThemeMode m) {
      final selected = app.themeMode == m;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: text,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => app.setThemeMode(m),
            child: Container(
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? (c.isDark ? c.text : Colors.black) : Colors.transparent,
                borderRadius: BorderRadius.circular(21),
              ),
              child: Text(
                text,
                style: sans(
                  context,
                  size: 13,
                  color: selected ? (c.isDark ? Colors.black : Colors.white) : c.text,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.border),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          seg('System', ThemeMode.system),
          seg('Light', ThemeMode.light),
          seg('Dark', ThemeMode.dark),
        ],
      ),
    );
  }
}

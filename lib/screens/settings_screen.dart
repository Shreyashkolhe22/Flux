import 'package:flutter/material.dart';

import '../main.dart';
import '../theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = FluxColors.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: c.bg,
        elevation: 0,
        title: Text('Settings', style: TextStyle(fontFamily: kMono, color: c.text, fontSize: 16)),
      ),
      body: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final p = app.pairing;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _section(context, 'APPEARANCE'),
              _ThemeToggle(),
              const SizedBox(height: 28),
              _section(context, 'PAIRED DEVICE'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.laptop, color: c.text),
                title: Text(p?.name ?? 'None', style: TextStyle(fontFamily: kMono, color: c.text)),
                subtitle: p == null ? null : Text(p.activeIp, style: label(context, size: 10)),
              ),
              const SizedBox(height: 20),
              _section(context, 'HISTORY'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.delete_outline, color: c.text),
                title: Text('Clear History', style: TextStyle(fontFamily: kMono, color: c.text)),
                onTap: () async {
                  await app.clearHistory();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('History cleared.')));
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _section(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t, style: label(context, size: 10)),
      );
}

class _ThemeToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = FluxColors.of(context);
    Widget seg(String text, ThemeMode m) {
      final selected = app.themeMode == m;
      return Expanded(
        child: GestureDetector(
          onTap: () => app.setThemeMode(m),
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? c.text : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              text,
              style: label(context, color: selected ? c.bg : c.textSecondary, size: 11),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.border),
      ),
      padding: const EdgeInsets.all(2),
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'screens/devices_screen.dart';
import 'screens/home_screen.dart';
import 'screens/send_overlay.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets/common.dart';

final app = AppState();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FluxApp());
  // Shell shows a loading page until this finishes.
  await app.load();
}

class FluxApp extends StatelessWidget {
  const FluxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => MaterialApp(
        title: 'Flux',
        debugShowCheckedModeBanner: false,
        themeMode: app.themeMode,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const Shell(),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int _tab = 0;
  StreamSubscription<List<SharedMediaFile>>? _shareSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shareSub = ReceiveSharingIntent.instance.getMediaStream().listen(_onShared);
    ReceiveSharingIntent.instance.getInitialMedia().then(_onShared);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shareSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && app.phase == Phase.idle) {
      app.refreshConnection();
    }
  }

  Future<void> _onShared(List<SharedMediaFile> files) async {
    if (files.isEmpty) return;
    ReceiveSharingIntent.instance.reset();
    for (final f in files) {
      switch (f.type) {
        case SharedMediaType.text:
        case SharedMediaType.url:
          await app.sendText(f.path, share: true);
        case SharedMediaType.image:
          await app.sendImage(f.path, share: true);
        default:
          break; // video/files are not supported in v1
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = FluxColors.of(context);
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        if (!app.loaded) {
          return const Scaffold(
            body: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 16),
                    FluxHeader(),
                    Expanded(child: LoadingView(text: 'Loading...')),
                  ],
                ),
              ),
            ),
          );
        }
        if (app.phase != Phase.idle) return const SendOverlay();
        return Scaffold(
          body: IndexedStack(
            index: _tab,
            children: const [HomeScreen(), DevicesScreen()],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  children: [
                    _NavItem(
                      icon: Icons.home_filled,
                      text: 'Home',
                      selected: _tab == 0,
                      onTap: () => setState(() => _tab = 0),
                    ),
                    Container(width: 1, height: 28, color: c.border),
                    _NavItem(
                      icon: Icons.laptop,
                      text: 'Devices',
                      selected: _tab == 1,
                      onTap: () => setState(() => _tab = 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = FluxColors.of(context);
    final color = selected ? c.text : c.textSecondary;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: text,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 3),
              Text(text, style: sans(context, color: color, size: 12)),
              const SizedBox(height: 3),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? c.red : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

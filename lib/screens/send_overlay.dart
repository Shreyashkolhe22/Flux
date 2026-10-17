import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dot_text.dart';

/// Full-screen Sending / Sent / Failed states, shown over everything.
class SendOverlay extends StatefulWidget {
  const SendOverlay({super.key});

  @override
  State<SendOverlay> createState() => _SendOverlayState();
}

class _SendOverlayState extends State<SendOverlay> {
  Timer? _auto;

  void _onChange() {
    _auto?.cancel();
    // After sharing from another app, close Flux once it has landed.
    if (app.phase == Phase.sent && app.fromShare) {
      _auto = Timer(const Duration(milliseconds: 1400), () {
        app.dismissPhase();
        SystemNavigator.pop();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    app.addListener(_onChange);
  }

  @override
  void dispose() {
    _auto?.cancel();
    app.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild on every state change. The parent builds this as a const
    // widget, so without this it would stay frozen on "Sending...".
    return ListenableBuilder(listenable: app, builder: _build);
  }

  Widget _build(BuildContext context, Widget? _) {
    final c = FluxColors.of(context);
    final phase = app.phase;
    return Material(
      color: c.bg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const FluxHeader(),
              const Spacer(),
              Center(child: _content(context, phase, c)),
              const Spacer(),
              if (phase == Phase.sent) ...[
                OutlineButton(text: 'OK', onTap: _close),
              ] else if (phase == Phase.failed) ...[
                OutlineButton(text: 'RETRY', onTap: app.retryCurrent),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _close,
                  child: Text('CLOSE', style: label(context, color: c.textSecondary, size: 11)),
                ),
              ],
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  void _close() {
    final share = app.fromShare;
    app.dismissPhase();
    if (share) SystemNavigator.pop();
  }

  Widget _content(BuildContext context, Phase phase, FluxColors c) {
    switch (phase) {
      case Phase.sending:
        return OutlineCard(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          radius: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const DottedRing(size: 64, dots: 24, spin: true),
              const SizedBox(height: 24),
              Text('SENDING...', style: label(context, color: c.text, size: 12)),
              const SizedBox(height: 8),
              Text(
                app.phaseLabel,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: label(context, size: 10),
              ),
            ],
          ),
        );
      case Phase.sent:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DottedRing(
              size: 120,
              dots: 40,
              child: Icon(Icons.check, size: 44, color: c.text),
            ),
            const SizedBox(height: 28),
            const DotText('SENT', dot: 6),
            const SizedBox(height: 18),
            Text(app.phaseMessage, textAlign: TextAlign.center, style: label(context, color: c.text, size: 11)),
          ],
        );
      case Phase.failed:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DottedRing(
              size: 120,
              dots: 40,
              color: c.red,
              child: Icon(Icons.priority_high, size: 48, color: c.red),
            ),
            const SizedBox(height: 28),
            const DotText('FAILED', dot: 6),
            const SizedBox(height: 18),
            Text(app.phaseMessage, textAlign: TextAlign.center, style: label(context, color: c.text, size: 11)),
          ],
        );
      case Phase.idle:
        return const SizedBox.shrink();
    }
  }
}

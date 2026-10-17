import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Full-page Sending / Sent / Failed states, shown over everything.
class SendOverlay extends StatefulWidget {
  const SendOverlay({super.key});

  @override
  State<SendOverlay> createState() => _SendOverlayState();
}

class _SendOverlayState extends State<SendOverlay> {
  Timer? _auto;

  void _onChange() {
    _auto?.cancel();
    if (app.phase != Phase.sent) return;
    // Sent pages close themselves. After a share from another app, Flux also
    // leaves so the user lands back where they were.
    final share = app.fromShare;
    _auto = Timer(Duration(milliseconds: share ? 1400 : 1800), () {
      app.dismissPhase();
      if (share) SystemNavigator.pop();
    });
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

  void _close() {
    final share = app.fromShare;
    app.dismissPhase();
    if (share) SystemNavigator.pop();
  }

  Widget _build(BuildContext context, Widget? _) {
    final c = FluxColors.of(context);
    final phase = app.phase;
    final title = switch (phase) {
      Phase.sending => 'Sending',
      Phase.sent => 'Sent',
      Phase.failed => 'Failed',
      Phase.idle => '',
    };
    return Material(
      color: c.bg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              PageHeader(
                title: title,
                onBack: phase == Phase.sending ? null : _close,
              ),
              const Spacer(),
              _content(context, phase, c),
              const Spacer(),
              if (phase == Phase.failed) ...[
                PillButton(text: 'RETRY', onTap: app.retryCurrent),
                const SizedBox(height: 28),
              ] else
                const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, Phase phase, FluxColors c) {
    switch (phase) {
      case Phase.sending:
        return LoadingView(text: 'Sending...', sub: app.phaseLabel, size: 104);
      case Phase.sent:
        return _result(
          context,
          ring: DottedRing(
            size: 104,
            dots: 36,
            redArc: 7,
            child: Icon(Icons.check, size: 40, color: c.red),
          ),
          title: 'SENT',
          message: app.phaseMessage,
        );
      case Phase.failed:
        return _result(
          context,
          ring: DottedRing(
            size: 104,
            dots: 36,
            color: c.red.withValues(alpha: 0.55),
            child: Text(
              '!',
              style: TextStyle(fontFamily: kSans, fontSize: 40, fontWeight: FontWeight.w700, color: c.red),
            ),
          ),
          title: 'FAILED',
          message: app.phaseMessage,
        );
      case Phase.idle:
        return const SizedBox.shrink();
    }
  }

  Widget _result(
    BuildContext context, {
    required Widget ring,
    required String title,
    required String message,
  }) {
    final c = FluxColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ring,
        const SizedBox(height: 28),
        Text(
          title,
          style: TextStyle(
            fontFamily: kMono,
            fontSize: 20,
            letterSpacing: 2.4,
            fontWeight: FontWeight.w500,
            color: c.text,
          ),
        ),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center, style: label(context, size: 11)),
      ],
    );
  }
}

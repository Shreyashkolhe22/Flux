import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'dot_text.dart';

/// Header: dot-matrix FLUX wordmark, tagline and optional settings button.
class FluxHeader extends StatelessWidget {
  final VoidCallback? onSettings;
  const FluxHeader({super.key, this.onSettings});

  @override
  Widget build(BuildContext context) {
    final c = FluxColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DotText('FLUX.', dot: 6, dotColor: c.red),
              const SizedBox(height: 10),
              Text('LOCAL SHARING. NO CLOUD.', style: label(context, size: 10)),
            ],
          ),
        ),
        if (onSettings != null)
          IconButton(
            tooltip: 'Settings',
            onPressed: onSettings,
            icon: Icon(Icons.settings_outlined, color: c.text),
          ),
      ],
    );
  }
}

/// Ring of dots, optionally spinning. Used for status and loaders.
class DottedRing extends StatefulWidget {
  final double size;
  final Color? color;
  final bool spin;
  final Widget? child;
  final int dots;

  const DottedRing({
    super.key,
    this.size = 56,
    this.color,
    this.spin = false,
    this.child,
    this.dots = 28,
  });

  @override
  State<DottedRing> createState() => _DottedRingState();
}

class _DottedRingState extends State<DottedRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  @override
  void initState() {
    super.initState();
    if (widget.spin) _ctl.repeat();
  }

  @override
  void didUpdateWidget(DottedRing old) {
    super.didUpdateWidget(old);
    if (widget.spin && !_ctl.isAnimating) _ctl.repeat();
    if (!widget.spin && _ctl.isAnimating) _ctl.stop();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? FluxColors.of(context).text;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _ctl,
            builder: (_, _) => CustomPaint(
              size: Size.square(widget.size),
              painter: _RingPainter(color, widget.dots, _ctl.value * 2 * math.pi),
            ),
          ),
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final Color color;
  final int dots;
  final double rotation;
  _RingPainter(this.color, this.dots, this.rotation);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 2;
    for (var i = 0; i < dots; i++) {
      final a = rotation + i * 2 * math.pi / dots;
      // Fade the tail when spinning so the motion reads.
      final alpha = rotation == 0 ? 1.0 : 0.25 + 0.75 * (i / dots);
      final p = Paint()..color = color.withValues(alpha: alpha);
      canvas.drawCircle(
        center + Offset(math.cos(a), math.sin(a)) * radius,
        1.6,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) =>
      o.rotation != rotation || o.color != color || o.dots != dots;
}

class DashedLine extends StatelessWidget {
  const DashedLine({super.key});

  @override
  Widget build(BuildContext context) {
    final color = FluxColors.of(context).border;
    return SizedBox(
      height: 1,
      width: double.infinity,
      child: CustomPaint(painter: _DashPainter(color)),
    );
  }
}

class _DashPainter extends CustomPainter {
  final Color color;
  _DashPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 5) {
      canvas.drawLine(Offset(x, 0), Offset(x + 2, 0), p);
    }
  }

  @override
  bool shouldRepaint(_DashPainter o) => o.color != color;
}

/// Outlined rounded container used for cards.
class OutlineCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? borderColor;

  const OutlineCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = FluxColors.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? c.border),
      ),
      child: child,
    );
  }
}

/// Round outlined action (IMAGE / CAMERA / FILE).
class CircleAction extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? sub;
  final VoidCallback? onTap;

  const CircleAction({
    super.key,
    required this.icon,
    required this.text,
    this.sub,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = FluxColors.of(context);
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: text,
      child: InkResponse(
        onTap: onTap,
        radius: 48,
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: enabled ? c.text : c.border),
              ),
              child: Icon(icon, color: enabled ? c.text : c.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(text, style: label(context, color: c.text, size: 10)),
            if (sub != null) Text(sub!, style: label(context, size: 9)),
          ],
        ),
      ),
    );
  }
}

/// Wide outlined pill button used for primary screen actions.
class OutlineButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback onTap;
  final bool filled;

  const OutlineButton({
    super.key,
    required this.text,
    required this.onTap,
    this.icon,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = FluxColors.of(context);
    final fg = filled ? Colors.white : c.text;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          backgroundColor: filled ? c.red : null,
          side: BorderSide(color: filled ? c.red : c.text),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 10)],
            Text(text, style: label(context, color: fg, size: 12)),
          ],
        ),
      ),
    );
  }
}

String timeAgo(int ts) {
  final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts));
  if (d.inSeconds < 60) return 'JUST NOW';
  if (d.inMinutes < 60) return '${d.inMinutes} MIN AGO';
  if (d.inHours < 24) return '${d.inHours} H AGO';
  return '${d.inDays} D AGO';
}

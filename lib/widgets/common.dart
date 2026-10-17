import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'dot_text.dart';

/// Home header: dot-matrix FLUX wordmark, a status line, and the settings gear.
class FluxHeader extends StatelessWidget {
  final String? status;
  final VoidCallback? onSettings;
  const FluxHeader({super.key, this.status, this.onSettings});

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
              DotText('FLUX.', dot: 3.4, dotColor: c.red, thin: true),
              if (status != null) ...[
                const SizedBox(height: 10),
                Text(status!, style: label(context, size: 11)),
              ],
            ],
          ),
        ),
        if (onSettings != null)
          IconButton(
            tooltip: 'Settings',
            onPressed: onSettings,
            icon: Icon(Icons.settings_outlined, color: c.text, size: 22),
          ),
      ],
    );
  }
}

/// Header for every page except home: the FLUX wordmark on top (with an
/// optional trailing action), then the back arrow and page title below it.
class PageHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;
  const PageHeader({super.key, required this.title, this.onBack, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = FluxColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 52,
          child: Row(
            children: [
              DotText('FLUX.', dot: 3.4, dotColor: c.red, thin: true),
              const Spacer(),
              ?trailing,
            ],
          ),
        ),
        SizedBox(
          height: 48,
          child: Row(
            children: [
              if (onBack != null)
                IconButton(
                  tooltip: 'Back',
                  onPressed: onBack,
                  icon: Icon(Icons.arrow_back, color: c.text, size: 22),
                )
              else
                const SizedBox.shrink(),
              if (onBack != null) const SizedBox(width: 4),
              Expanded(child: Text(title, style: sans(context, size: 16))),
            ],
          ),
        ),
      ],
    );
  }
}

/// Ring of dots. When [spin] is true it rotates, with a red arc at the
/// leading edge (the loading animation used on every loading page).
class DottedRing extends StatefulWidget {
  final double size;
  final Color? color;
  final bool spin;
  final Widget? child;
  final int dots;

  /// Number of red dots at the leading edge of a spinning ring.
  final int redArc;

  const DottedRing({
    super.key,
    this.size = 56,
    this.color,
    this.spin = false,
    this.child,
    this.dots = 28,
    this.redArc = 0,
  });

  @override
  State<DottedRing> createState() => _DottedRingState();
}

class _DottedRingState extends State<DottedRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
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
    final c = FluxColors.of(context);
    final color = widget.color ?? c.text;
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
              painter: _RingPainter(
                color: color,
                accent: c.red,
                dots: widget.dots,
                redArc: widget.redArc,
                spinning: widget.spin,
                rotation: _ctl.value * 2 * math.pi,
              ),
            ),
          ),
          ?widget.child,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final Color color;
  final Color accent;
  final int dots;
  final int redArc;
  final bool spinning;
  final double rotation;

  _RingPainter({
    required this.color,
    required this.accent,
    required this.dots,
    required this.redArc,
    required this.spinning,
    required this.rotation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 3;
    final dotR = math.max(1.2, size.width / 70);
    for (var i = 0; i < dots; i++) {
      // i = 0 is the tail, i = dots - 1 is the head of the moving arc.
      final a = rotation + i * 2 * math.pi / dots;
      final isHead = redArc > 0 && i >= dots - redArc;
      final Paint p;
      if (isHead) {
        p = Paint()..color = accent;
      } else if (spinning) {
        final t = i / dots;
        p = Paint()..color = color.withValues(alpha: 0.12 + 0.55 * t * t);
      } else {
        p = Paint()..color = color;
      }
      canvas.drawCircle(
        center + Offset(math.cos(a), math.sin(a)) * radius,
        isHead ? dotR * 1.25 : dotR,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) =>
      o.rotation != rotation ||
      o.color != color ||
      o.dots != dots ||
      o.redArc != redArc ||
      o.spinning != spinning;
}

/// Loading page body: spinning ring + caption. Used wherever the app waits.
class LoadingView extends StatelessWidget {
  final String text;
  final String? sub;
  final double size;
  const LoadingView({super.key, required this.text, this.sub, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DottedRing(size: size, dots: 36, spin: true, redArc: 4),
          const SizedBox(height: 24),
          Text(text, style: sans(context, size: 16)),
          if (sub != null) ...[
            const SizedBox(height: 8),
            Text(
              sub!,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: label(context, size: 11),
            ),
          ],
        ],
      ),
    );
  }
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

/// Rounded surface card. Light mode gets a soft shadow, dark mode a border only.
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = kCardRadius,
  });

  @override
  Widget build(BuildContext context) {
    final c = FluxColors.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: c.border),
        boxShadow: c.isDark
            ? null
            : const [
                BoxShadow(color: Color(0x0F000000), blurRadius: 18, offset: Offset(0, 6)),
              ],
      ),
      child: child,
    );
  }
}

/// Circular icon holder (list leading icons, round actions).
class IconCircle extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color? color;
  const IconCircle({super.key, required this.icon, this.size = 48, this.color});

  @override
  Widget build(BuildContext context) {
    final c = FluxColors.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.isDark ? Colors.transparent : const Color(0xFFEDEDED),
        border: Border.all(color: c.border),
      ),
      child: Icon(icon, color: color ?? c.text, size: size * 0.42),
    );
  }
}

/// Round action (IMAGE / CAMERA / FILE).
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
        radius: 52,
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.isDark ? c.bg : c.surface,
                border: Border.all(color: c.border),
                boxShadow: c.isDark
                    ? null
                    : const [BoxShadow(color: Color(0x12000000), blurRadius: 14, offset: Offset(0, 5))],
              ),
              child: Icon(icon, color: c.text, size: 26),
            ),
            const SizedBox(height: 10),
            Text(text, style: label(context, color: c.text, size: 11)),
            if (sub != null) ...[
              const SizedBox(height: 2),
              Text(sub!, style: label(context, size: 10)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Wide pill button (SCAN QR CODE, RETRY, OK).
class PillButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onTap;

  const PillButton({super.key, required this.text, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = FluxColors.of(context);
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: c.text,
          backgroundColor: c.surface,
          side: BorderSide(color: c.isDark ? c.text.withValues(alpha: 0.7) : const Color(0xFF9A9A9A)),
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 12)],
            Text(text, style: label(context, color: c.text, size: 12)),
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

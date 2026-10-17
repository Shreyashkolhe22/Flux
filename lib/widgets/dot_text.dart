import 'package:flutter/material.dart';

import '../theme.dart';

/// 5x7 dot-matrix glyphs (the design uses a dot-matrix display face).
const Map<String, List<String>> _glyphs = {
  'A': ['01110', '10001', '10001', '11111', '10001', '10001', '10001'],
  'B': ['11110', '10001', '10001', '11110', '10001', '10001', '11110'],
  'C': ['01110', '10001', '10000', '10000', '10000', '10001', '01110'],
  'D': ['11110', '10001', '10001', '10001', '10001', '10001', '11110'],
  'E': ['11111', '10000', '10000', '11110', '10000', '10000', '11111'],
  'F': ['11111', '10000', '10000', '11110', '10000', '10000', '10000'],
  'G': ['01110', '10001', '10000', '10111', '10001', '10001', '01111'],
  'H': ['10001', '10001', '10001', '11111', '10001', '10001', '10001'],
  'I': ['01110', '00100', '00100', '00100', '00100', '00100', '01110'],
  'J': ['00111', '00010', '00010', '00010', '00010', '10010', '01100'],
  'K': ['10001', '10010', '10100', '11000', '10100', '10010', '10001'],
  'L': ['10000', '10000', '10000', '10000', '10000', '10000', '11111'],
  'M': ['10001', '11011', '10101', '10101', '10001', '10001', '10001'],
  'N': ['10001', '11001', '10101', '10011', '10001', '10001', '10001'],
  'O': ['01110', '10001', '10001', '10001', '10001', '10001', '01110'],
  'P': ['11110', '10001', '10001', '11110', '10000', '10000', '10000'],
  'Q': ['01110', '10001', '10001', '10001', '10101', '10010', '01101'],
  'R': ['11110', '10001', '10001', '11110', '10100', '10010', '10001'],
  'S': ['01111', '10000', '10000', '01110', '00001', '00001', '11110'],
  'T': ['11111', '00100', '00100', '00100', '00100', '00100', '00100'],
  'U': ['10001', '10001', '10001', '10001', '10001', '10001', '01110'],
  'V': ['10001', '10001', '10001', '10001', '10001', '01010', '00100'],
  'W': ['10001', '10001', '10001', '10101', '10101', '11011', '10001'],
  'X': ['10001', '10001', '01010', '00100', '01010', '10001', '10001'],
  'Y': ['10001', '10001', '01010', '00100', '00100', '00100', '00100'],
  'Z': ['11111', '00001', '00010', '00100', '01000', '10000', '11111'],
  '.': ['0', '0', '0', '0', '0', '0', '1'],
  ' ': ['00', '00', '00', '00', '00', '00', '00'],
};

/// Draws [text] as dot-matrix. A trailing "." is drawn in [dotColor]
/// (the red full stop of the FLUX wordmark).
class DotText extends StatelessWidget {
  final String text;
  final double dot;
  final Color? color;
  final Color? dotColor;

  const DotText(this.text, {super.key, this.dot = 4, this.color, this.dotColor});

  @override
  Widget build(BuildContext context) {
    final c = FluxColors.of(context);
    final chars = text.toUpperCase().split('').where(_glyphs.containsKey);
    var cols = 0;
    for (final ch in chars) {
      cols += _glyphs[ch]![0].length + 1;
    }
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: CustomPaint(
          size: Size(cols * dot, 7 * dot),
          painter: _DotTextPainter(
            chars.toList(),
            dot,
            color ?? c.text,
            dotColor ?? color ?? c.text,
          ),
        ),
      ),
    );
  }
}

class _DotTextPainter extends CustomPainter {
  final List<String> chars;
  final double dot;
  final Color color;
  final Color dotColor;

  _DotTextPainter(this.chars, this.dot, this.color, this.dotColor);

  @override
  void paint(Canvas canvas, Size size) {
    final r = dot * 0.4;
    final p = Paint()..isAntiAlias = true;
    var x = 0;
    for (final ch in chars) {
      final g = _glyphs[ch]!;
      p.color = ch == '.' ? dotColor : color;
      for (var row = 0; row < g.length; row++) {
        for (var col = 0; col < g[row].length; col++) {
          if (g[row][col] == '1') {
            canvas.drawCircle(
              Offset((x + col) * dot + dot / 2, row * dot + dot / 2),
              ch == '.' ? r * 1.5 : r,
              p,
            );
          }
        }
      }
      x += g[0].length + 1;
    }
  }

  @override
  bool shouldRepaint(_DotTextPainter o) =>
      o.chars.join() != chars.join() ||
      o.dot != dot ||
      o.color != color ||
      o.dotColor != dotColor;
}

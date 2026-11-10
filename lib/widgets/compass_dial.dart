import 'dart:math' as math;
import 'package:flutter/material.dart';

double headingDelta(double from, double to) => (to - from + 540) % 360 - 180;
String compassDirection(double heading) => const [
  'N',
  'NE',
  'E',
  'SE',
  'S',
  'SW',
  'W',
  'NW',
][((heading % 360) / 45).round() % 8];

/// Pure presentation: no sensor subscription, permission, or network access.
/// The dial turns under a fixed phone indicator; glyphs remain upright.
class CompassDial extends StatefulWidget {
  final double? heading;
  final bool unreliable;
  final String magneticLabel, unavailableLabel, unreliableLabel;
  const CompassDial({
    super.key,
    required this.heading,
    this.unreliable = false,
    required this.magneticLabel,
    required this.unavailableLabel,
    required this.unreliableLabel,
  });
  @override
  State<CompassDial> createState() => _CompassDialState();
}

class _CompassDialState extends State<CompassDial> {
  double angle = 0;
  bool get valid => widget.heading?.isFinite == true && !widget.unreliable;
  @override
  void initState() {
    super.initState();
    if (valid) angle = widget.heading! % 360;
  }

  @override
  void didUpdateWidget(CompassDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (valid) {
      angle = oldWidget.heading == null || oldWidget.unreliable
          ? widget.heading! % 360
          : angle + headingDelta(angle % 360, widget.heading! % 360);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = !valid
        ? (widget.unreliable ? widget.unreliableLabel : widget.unavailableLabel)
        : '${(widget.heading! % 360).round() % 360}° '
              '${compassDirection(widget.heading!)} — ${widget.magneticLabel}';
    return Column(
      children: [
        Semantics(
          label: label,
          image: true,
          child: ExcludeSemantics(
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: SizedBox(
                width: 240,
                height: 240,
                child: valid
                    ? TweenAnimationBuilder<double>(
                        tween: Tween(end: angle),
                        duration: const Duration(milliseconds: 220),
                        builder: (_, value, _) => CustomPaint(
                          painter: _DialPainter(
                            value,
                            Theme.of(context).colorScheme,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.explore_off_outlined,
                        size: 72,
                        color: Theme.of(context).colorScheme.outline,
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    );
  }
}

class _DialPainter extends CustomPainter {
  final double heading;
  final ColorScheme colors;
  _DialPainter(this.heading, this.colors);
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 18;
    final paint = Paint()
      ..color = colors.outline
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, paint);
    Offset at(double degrees, double r) {
      final a = (degrees - heading - 90) * math.pi / 180;
      return center + Offset(math.cos(a), math.sin(a)) * r;
    }

    for (var degree = 0; degree < 360; degree += 5) {
      paint
        ..color = degree == 0 ? colors.error : colors.outline
        ..strokeWidth = degree % 90 == 0 ? 3 : 1;
      canvas.drawLine(
        at(degree.toDouble(), radius - (degree % 30 == 0 ? 13 : 6)),
        at(degree.toDouble(), radius),
        paint,
      );
    }
    for (var i = 0; i < 4; i++) {
      final text = TextPainter(
        text: TextSpan(
          text: const ['N', 'E', 'S', 'W'][i],
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: i == 0 ? colors.error : colors.onSurface,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        at(i * 90.0, radius - 30) - Offset(text.width / 2, text.height / 2),
      );
    }
    paint
      ..style = PaintingStyle.fill
      ..color = colors.primary;
    canvas.drawPath(
      Path()
        ..moveTo(center.dx, 5)
        ..lineTo(center.dx - 7, 17)
        ..lineTo(center.dx + 7, 17)
        ..close(),
      paint,
    );
    canvas.drawCircle(center, 5, paint);
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      heading != old.heading || colors != old.colors;
}

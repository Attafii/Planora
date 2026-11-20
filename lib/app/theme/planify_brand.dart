import 'package:flutter/material.dart';

/// Vector recreation of the supplied Planify path / time-block symbol.
class PlanifyMark extends StatelessWidget {
  final double size;
  const PlanifyMark({super.key, this.size = 40});
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _MarkPainter(Theme.of(context).brightness == Brightness.dark),
    ),
  );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.dark);
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 200, size.height / 200);
    const bounds = Rect.fromLTWH(0, 0, 200, 200);
    final outer = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 30
      ..shader = LinearGradient(
        colors: [
          dark ? const Color(0xFF8EE5B9) : const Color(0xFF21785F),
          const Color(0xFF46A987),
        ],
      ).createShader(bounds);
    canvas.drawPath(
      Path()
        ..moveTo(30, 170)
        ..lineTo(30, 77)
        ..cubicTo(30, 43, 57, 25, 83, 25)
        ..lineTo(130, 25)
        ..cubicTo(164, 25, 176, 46, 176, 69)
        ..cubicTo(176, 95, 156, 111, 132, 111)
        ..lineTo(91, 111),
      outer,
    );
    final branch = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 30
      ..shader = LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [
          const Color(0xFFD3965B),
          const Color(0xFF4CA683),
          const Color(0xFF75D2A7),
        ],
      ).createShader(bounds);
    canvas.drawPath(
      Path()
        ..moveTo(30, 170)
        ..lineTo(30, 149)
        ..cubicTo(30, 102, 70, 75, 115, 75)
        ..lineTo(135, 75),
      branch,
    );
    canvas.drawCircle(
      const Offset(135, 75),
      19,
      Paint()..color = const Color(0xFF74C8A0),
    );
    canvas.drawLine(
      const Offset(78, 143),
      const Offset(125, 143),
      Paint()
        ..color = const Color(0xFF389A79)
        ..strokeWidth = 25
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      const Offset(76, 176),
      const Offset(101, 176),
      Paint()
        ..color = const Color(0xFFD3965B)
        ..strokeWidth = 25
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _MarkPainter oldDelegate) =>
      dark != oldDelegate.dark;
}

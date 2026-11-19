import 'package:flutter/material.dart';

/// Vector recreation of the supplied Planify path / time-block symbol.
class PlanifyMark extends StatelessWidget {
  final double size;
  const PlanifyMark({super.key, this.size = 40});
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: const CustomPaint(painter: _MarkPainter()),
  );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 200, size.height / 200);
    const bounds = Rect.fromLTWH(0, 0, 200, 200);
    final outer = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 30
      ..shader = const LinearGradient(
        colors: [Color(0xFF0078FF), Color(0xFF00D1B2)],
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
      ..shader = const LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6), Color(0xFF00D1B2)],
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
      Paint()..color = const Color(0xFF00C9C4),
    );
    canvas.drawLine(
      const Offset(78, 143),
      const Offset(125, 143),
      Paint()
        ..color = const Color(0xFF0788FF)
        ..strokeWidth = 25
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      const Offset(76, 176),
      const Offset(101, 176),
      Paint()
        ..color = const Color(0xFF7952FF)
        ..strokeWidth = 25
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

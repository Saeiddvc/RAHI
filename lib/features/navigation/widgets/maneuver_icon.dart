import 'package:flutter/material.dart';

import '../../../data/models/route_step.dart';

/// آیکون‌های مانور با خطوط ساده و خوانا برای حالت رانندگی.
class ManeuverIcon extends StatelessWidget {
  final ManeuverType type;
  final double size;
  final Color color;

  const ManeuverIcon({
    super.key,
    required this.type,
    this.size = 32,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ManeuverPainter(type: type, color: color),
      ),
    );
  }
}

class _ManeuverPainter extends CustomPainter {
  final ManeuverType type;
  final Color color;

  _ManeuverPainter({
    required this.type,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (type) {
      case ManeuverType.turnRight:
        _drawTurn(canvas, size, paint, isRight: true);
      case ManeuverType.turnSlightRight:
        _drawSlightTurn(canvas, size, paint, isRight: true);
      case ManeuverType.turnLeft:
        _drawTurn(canvas, size, paint, isRight: false);
      case ManeuverType.turnSlightLeft:
        _drawSlightTurn(canvas, size, paint, isRight: false);
      case ManeuverType.turnSharpLeft:
        _drawTurn(canvas, size, paint, isRight: false);
      case ManeuverType.turnSharpRight:
        _drawTurn(canvas, size, paint, isRight: true);
      case ManeuverType.uTurn:
        _drawUTurn(canvas, size, paint);
      case ManeuverType.straight:
        _drawStraight(canvas, size, paint);
      case ManeuverType.roundabout:
        _drawRoundabout(canvas, size, paint);
      case ManeuverType.arrive:
        _drawFlag(canvas, size, paint, fillPaint);
      case ManeuverType.merge:
      case ManeuverType.fork:
      case ManeuverType.onRamp:
      case ManeuverType.offRamp:
        _drawTurn(canvas, size, paint, isRight: true);
      case ManeuverType.depart:
      case ManeuverType.unknown:
        _drawStraight(canvas, size, paint);
    }
  }

  void _drawTurn(
    Canvas canvas,
    Size size,
    Paint paint, {
    required bool isRight,
  }) {
    final path = Path();
    final w = size.width;
    final h = size.height;

    if (isRight) {
      path.moveTo(w * 0.28, h * 0.88);
      path.lineTo(w * 0.28, h * 0.50);
      path.quadraticBezierTo(
        w * 0.28,
        h * 0.33,
        w * 0.46,
        h * 0.33,
      );
      path.lineTo(w * 0.72, h * 0.33);
      canvas.drawPath(path, paint);

      final arrow = Path()
        ..moveTo(w * 0.58, h * 0.17)
        ..lineTo(w * 0.78, h * 0.33)
        ..lineTo(w * 0.58, h * 0.49);
      canvas.drawPath(arrow, paint);
    } else {
      path.moveTo(w * 0.72, h * 0.88);
      path.lineTo(w * 0.72, h * 0.50);
      path.quadraticBezierTo(
        w * 0.72,
        h * 0.33,
        w * 0.54,
        h * 0.33,
      );
      path.lineTo(w * 0.28, h * 0.33);
      canvas.drawPath(path, paint);

      final arrow = Path()
        ..moveTo(w * 0.42, h * 0.17)
        ..lineTo(w * 0.22, h * 0.33)
        ..lineTo(w * 0.42, h * 0.49);
      canvas.drawPath(arrow, paint);
    }
  }

  void _drawSlightTurn(
    Canvas canvas,
    Size size,
    Paint paint, {
    required bool isRight,
  }) {
    final path = Path();
    final w = size.width;
    final h = size.height;

    if (isRight) {
      path.moveTo(w * 0.38, h * 0.88);
      path.lineTo(w * 0.38, h * 0.62);
      path.lineTo(w * 0.72, h * 0.28);
      canvas.drawPath(path, paint);

      final arrow = Path()
        ..moveTo(w * 0.55, h * 0.28)
        ..lineTo(w * 0.78, h * 0.28)
        ..lineTo(w * 0.78, h * 0.51);
      canvas.drawPath(arrow, paint);
    } else {
      path.moveTo(w * 0.62, h * 0.88);
      path.lineTo(w * 0.62, h * 0.62);
      path.lineTo(w * 0.28, h * 0.28);
      canvas.drawPath(path, paint);

      final arrow = Path()
        ..moveTo(w * 0.45, h * 0.28)
        ..lineTo(w * 0.22, h * 0.28)
        ..lineTo(w * 0.22, h * 0.51);
      canvas.drawPath(arrow, paint);
    }
  }

  void _drawStraight(Canvas canvas, Size size, Paint paint) {
    final w = size.width;
    final h = size.height;

    canvas.drawLine(
      Offset(w * 0.5, h * 0.88),
      Offset(w * 0.5, h * 0.30),
      paint,
    );

    final arrow = Path()
      ..moveTo(w * 0.30, h * 0.45)
      ..lineTo(w * 0.5, h * 0.22)
      ..lineTo(w * 0.70, h * 0.45);
    canvas.drawPath(arrow, paint);
  }

  void _drawUTurn(Canvas canvas, Size size, Paint paint) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.65, h * 0.88)
      ..lineTo(w * 0.65, h * 0.45)
      ..cubicTo(
        w * 0.65,
        h * 0.24,
        w * 0.35,
        h * 0.24,
        w * 0.35,
        h * 0.45,
      )
      ..lineTo(w * 0.35, h * 0.64);
    canvas.drawPath(path, paint);

    final arrow = Path()
      ..moveTo(w * 0.20, h * 0.52)
      ..lineTo(w * 0.35, h * 0.68)
      ..lineTo(w * 0.50, h * 0.52);
    canvas.drawPath(arrow, paint);
  }

  void _drawRoundabout(Canvas canvas, Size size, Paint paint) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w * 0.5, h * 0.55);
    final radius = w * 0.22;

    canvas.drawCircle(center, radius, paint);
    canvas.drawLine(
      Offset(w * 0.5, h * 0.20),
      Offset(w * 0.5, center.dy - radius),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx + radius, center.dy),
      Offset(w * 0.88, center.dy),
      paint,
    );

    final arrow = Path()
      ..moveTo(w * 0.76, h * 0.42)
      ..lineTo(w * 0.90, h * 0.55)
      ..lineTo(w * 0.76, h * 0.68);
    canvas.drawPath(arrow, paint);
  }

  void _drawFlag(
    Canvas canvas,
    Size size,
    Paint paint,
    Paint fillPaint,
  ) {
    final w = size.width;
    final h = size.height;

    canvas.drawLine(
      Offset(w * 0.5, h * 0.88),
      Offset(w * 0.5, h * 0.20),
      paint,
    );

    final flag = Path()
      ..moveTo(w * 0.5, h * 0.20)
      ..lineTo(w * 0.78, h * 0.34)
      ..lineTo(w * 0.5, h * 0.48)
      ..close();
    canvas.drawPath(flag, fillPaint);
  }

  @override
  bool shouldRepaint(_ManeuverPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}

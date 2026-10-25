import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Lightweight native decoration; all content and controls remain interactive.
class CloudBackground extends StatelessWidget {
  const CloudBackground({super.key, this.child, this.floorFraction});
  final Widget? child;
  final double? floorFraction;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: aqua,
    child: CustomPaint(
      painter: _CloudPainter(floorFraction),
      child: child ?? const SizedBox.expand(),
    ),
  );
}

class _CloudPainter extends CustomPainter {
  const _CloudPainter(this.floorFraction);
  final double? floorFraction;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final paint = Paint()..color = Colors.white;
    // Large scalloped corners echo the title reference without covering the scene.
    canvas.drawCircle(Offset(w - 8, -12), w * .24, paint);
    canvas.drawCircle(Offset(w + 16, w * .10), w * .19, paint);
    if (floorFraction case final fraction?) {
      paint.color = floor;
      final y = h * fraction;
      final ground = Path()
        ..moveTo(0, y + 14)
        ..quadraticBezierTo(w * .22, y - 13, w * .48, y + 5)
        ..quadraticBezierTo(w * .8, y + 22, w, y)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
      canvas.drawPath(ground, paint);
    }
    paint.color = Colors.white;
    canvas.drawCircle(Offset(-w * .08, h + 4), w * .29, paint);
    canvas.drawCircle(Offset(w * .17, h + w * .10), w * .23, paint);
    canvas.drawCircle(Offset(w * .36, h + w * .16), w * .20, paint);
  }

  @override
  bool shouldRepaint(_CloudPainter oldDelegate) =>
      oldDelegate.floorFraction != floorFraction;
}

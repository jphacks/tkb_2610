import 'package:flutter/material.dart';
import '../core/theme.dart';

class SpeechBubble extends StatelessWidget {
  const SpeechBubble({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: line),
            boxShadow: const [
              BoxShadow(
                color: Color(0x10126F7B),
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            text,
            key: const ValueKey('character-speech'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: ink,
              height: 1.5,
            ),
          ),
        ),
      ),
      const Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 11,
            child: CustomPaint(painter: _TailPainter()),
          ),
        ),
      ),
    ],
  );
}

class _TailPainter extends CustomPainter {
  const _TailPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final tail = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(
        size.width * .3,
        size.height * .5,
        size.width * .46,
        size.height * .88,
      )
      ..quadraticBezierTo(
        size.width * .52,
        size.height,
        size.width * .6,
        size.height * .86,
      )
      ..quadraticBezierTo(size.width * .8, size.height * .5, size.width, 0);
    canvas.drawPath(tail, Paint()..color = Colors.white);
    canvas.drawPath(
      tail,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_TailPainter oldDelegate) => false;
}

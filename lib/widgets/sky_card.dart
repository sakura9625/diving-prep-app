import 'package:flutter/material.dart';

class SkyCard extends StatelessWidget {
  const SkyCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.emoji,
  });
  final String title;
  final String subtitle;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      height: 78,
      decoration: BoxDecoration(
        color: const Color(0xFF4EC8E8),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          Positioned(
            right: 0,
            bottom: 0,
            width: 120,
            height: 78,
            child: CustomPaint(
              painter: _SkyCardPainter(),
            ),
          ),
          if (emoji != null)
            Positioned(
              right: 14,
              top: 0,
              bottom: 0,
              child: Center(
                child: Text(emoji!, style: const TextStyle(fontSize: 26)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkyCardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // 太陽
    paint.color = const Color(0xFFFFD233).withValues(alpha: 0.9);
    canvas.drawCircle(Offset(size.width * 0.79, size.height * 0.26), 16, paint);

    // 波1
    paint.color = Colors.white.withValues(alpha: 0.25);
    final wave1 = Path();
    wave1.moveTo(0, size.height * 0.71);
    wave1.quadraticBezierTo(size.width * 0.125, size.height * 0.58, size.width * 0.25, size.height * 0.71);
    wave1.quadraticBezierTo(size.width * 0.375, size.height * 0.83, size.width * 0.5, size.height * 0.71);
    wave1.quadraticBezierTo(size.width * 0.625, size.height * 0.58, size.width * 0.75, size.height * 0.71);
    wave1.quadraticBezierTo(size.width * 0.875, size.height * 0.83, size.width, size.height * 0.71);
    wave1.lineTo(size.width, size.height);
    wave1.lineTo(0, size.height);
    wave1.close();
    canvas.drawPath(wave1, paint);

    // 波2
    paint.color = Colors.white.withValues(alpha: 0.35);
    final wave2 = Path();
    wave2.moveTo(0, size.height * 0.81);
    wave2.quadraticBezierTo(size.width * 0.167, size.height * 0.68, size.width * 0.333, size.height * 0.81);
    wave2.quadraticBezierTo(size.width * 0.5, size.height * 0.94, size.width * 0.667, size.height * 0.81);
    wave2.quadraticBezierTo(size.width * 0.833, size.height * 0.68, size.width, size.height * 0.81);
    wave2.lineTo(size.width, size.height);
    wave2.lineTo(0, size.height);
    wave2.close();
    canvas.drawPath(wave2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

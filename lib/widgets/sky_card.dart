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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -10,
            right: 0,
            child: Container(
              width: 64,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            bottom: -6,
            right: 12,
            child: Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Color(0xFFFFD233),
                shape: BoxShape.circle,
              ),
            ),
          ),
          if (emoji != null)
            Positioned(
              top: 0,
              right: 52,
              child: Text(emoji!, style: const TextStyle(fontSize: 18)),
            ),
          Column(
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
        ],
      ),
    );
  }
}

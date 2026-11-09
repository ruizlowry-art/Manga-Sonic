import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SafeBlurredCoverBackground extends StatelessWidget {
  final String imageUrl;
  final Color? dominantColor;

  const SafeBlurredCoverBackground({
    Key? key,
    required this.imageUrl,
    this.dominantColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final accent = dominantColor ?? Colors.black;

    return Stack(
      children: [
        Positioned.fill(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
          ),
        ),
        // Vertical gradient overlay: transparent at top and bottom, dark in the middle for text readability
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.4),
                  Colors.black.withValues(alpha: 0.6),
                  Colors.black.withValues(alpha: 0.4),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
              ),
            ),
          ),
        ),
        // Horizontal gradient overlay: dark on left side for text readability
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.black.withValues(alpha: 0.5),
                  Colors.black.withValues(alpha: 0.2),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.4, 0.7],
              ),
            ),
          ),
        ),
        // Horizontal gradient overlay: dark on right side for balance
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [
                  Colors.black.withValues(alpha: 0.5),
                  Colors.black.withValues(alpha: 0.2),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.4, 0.7],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
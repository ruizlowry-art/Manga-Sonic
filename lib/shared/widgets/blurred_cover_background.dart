import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class BlurredCoverBackground extends StatelessWidget {
  final String imageUrl;
  final Color? dominantColor;
  final double blurSigma;
  final double topOpacity;
  final double bottomOpacity;

  const BlurredCoverBackground({
    super.key,
    required this.imageUrl,
    this.dominantColor,
    this.blurSigma = 12.0,
    this.topOpacity = 0.4,
    this.bottomOpacity = 0.9,
  });

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
        // Vertical gradient overlay: intensified black-only vignette
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: (() {
                final verticalColors = [
                  Colors.black.withValues(alpha: 0.85),
                  Colors.black.withValues(alpha: 0.7),
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.4),
                  Colors.black.withValues(alpha: 0.4),
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.7),
                  Colors.black.withValues(alpha: 0.85),
                ];

                final stops = List<double>.generate(
                  verticalColors.length,
                  (i) => verticalColors.length == 1 ? 0.0 : i / (verticalColors.length - 1),
                );

                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: verticalColors,
                  stops: stops,
                );
              })(),
            ),
          ),
        ),
        // Horizontal gradient overlay: black on left side
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  // Left: Strong black
                  Colors.black.withValues(alpha: 0.85),
                  // Center-left: Fading out
                  Colors.black.withValues(alpha: 0.5),
                  // Center: Lighter
                  Colors.black.withValues(alpha: 0.2),
                  // Right: Transparent
                  Colors.transparent,
                ],
                stops: const [0.0, 0.25, 0.45, 0.7],
              ),
            ),
          ),
        ),
        // Horizontal gradient overlay: black on right side
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [
                  // Right: Strong black
                  Colors.black.withValues(alpha: 0.85),
                  // Center-right: Fading out
                  Colors.black.withValues(alpha: 0.5),
                  // Center: Lighter
                  Colors.black.withValues(alpha: 0.2),
                  // Left: Transparent
                  Colors.transparent,
                ],
                stops: const [0.0, 0.25, 0.45, 0.7],
              ),
            ),
          ),
        ),
        // Stronger blur on middle section
        Positioned(
          left: 0,
          right: 0,
          top: MediaQuery.of(context).size.height * 0.2,
          bottom: MediaQuery.of(context).size.height * 0.2,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
            child: Container(
              color: Colors.transparent,
            ),
          ),
        ),
      ],
    );
  }
}

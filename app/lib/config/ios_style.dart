import 'package:flutter/material.dart';

/// Shared design tokens for iOS-like appearance across platforms.
class IosStyle {
  static const Color accent = Color(0xFF88A4FF);
  static const Color accentAlt = Color(0xFF6B9FFF);

  static const Color background = Color(0xFF0D0D0D);
  static const Color card = Color(0xFF1A1A1A);
  static const Color cardBorder = Color(0xFF242424);
  static const Color cardDeep = Color(0xFF14171D);
  static const Color softSurface = Color(0xFF1E222B);

  static const Color text = Color(0xFFE8E8E8);
  static const Color mutedText = Color(0xFF8C93A1);
  static const Color mutedTextStrong = Color(0xFFAAB1BE);

  static const double radiusSmall = 12;
  static const double radiusMedium = 16;
  static const double radiusLarge = 22;
}

Widget iosWindowsMark({
  required Color color,
  double size = 18,
  double cellSize = 7,
}) {
  Widget cell() => Container(
        width: cellSize,
        height: cellSize,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(1.5),
        ),
      );
  return SizedBox(
    width: size,
    height: size,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [cell(), cell()],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [cell(), cell()],
        ),
      ],
    ),
  );
}

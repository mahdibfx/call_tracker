import 'package:flutter/material.dart';

class AppColors {
  // Core
  static const Color backgroundColor = Color(0xFFFAF6F1);
  static const Color cardColor = Colors.white;
  static const Color textColor = Color(0xFF2B2420);
  static const Color secondaryColor = Color(0xFF9C938C);
  static Color secondaryColorLight = secondaryColor.withValues(alpha: .25);
  static const Color borderColor = Color(0xFFEEE4DA);

  // Primary accent
  static const Color primaryColor = Color(0xFFF2662C);
  static Color primaryColorLight = primaryColor.withValues(alpha: .12);

  // Semantic accents
  static const Color greenColor = Color(0xFF3DA35D);
  static Color greenColorLight = greenColor.withValues(alpha: .15);
  static const Color redColor = Color(0xFFE0473A);
  static Color redColorLight = redColor.withValues(alpha: .12);
  static const Color amberColor = Color(0xFFC98A1F);
  static Color amberColorLight = amberColor.withValues(alpha: .15);

  // Avatar background palette (cycled by name hash)
  static const List<Color> avatarPalette = [
    Color(0xFFF6C9AE),
    Color(0xFFDAD5CE),
    Color(0xFFC9DED2),
    Color(0xFFF3B79C),
  ];
}

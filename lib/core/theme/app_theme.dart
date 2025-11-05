import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color secondaryColor = Color(0xFF03A9F4);
  static const Color accentColor = Color(0xFF43A047);

  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryColor,
      fontFamily: 'NotoSans',
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        secondary: secondaryColor,
      ),
      useMaterial3: true,
    );
  }
}

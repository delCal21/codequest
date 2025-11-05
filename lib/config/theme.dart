import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const _primaryColor = Color(0xFF8BC34A);
  static const _secondaryColor = Color(0xFFC8E6C9);
  static const _errorColor = Color(0xFFD32F2F);
  static const _backgroundColor = Color(0xFFF1F8E9);
  static const _surfaceColor = Colors.white;
  static const _onPrimaryColor = Colors.white;
  static const _onSecondaryColor = Colors.white;
  static const _onSurfaceColor = Colors.black;
  static const _onErrorColor = Colors.white;

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: _primaryColor,
      secondary: _secondaryColor,
      error: _errorColor,
      surface: _surfaceColor,
      background: _backgroundColor,
      onPrimary: _onPrimaryColor,
      onSecondary: _onSecondaryColor,
      onSurface: _onSurfaceColor,
      onError: _onErrorColor,
    ),
    textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme).apply(
      bodyColor: Colors.black,
      displayColor: Colors.black,
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: _primaryColor,
      foregroundColor: _onPrimaryColor,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: _primaryColor,
        foregroundColor: _onPrimaryColor,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.transparent,
      border: UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade400),
      ),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade400),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(
          color: _primaryColor,
          width: 2,
        ),
      ),
      errorBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: _errorColor),
      ),
      focusedErrorBorder: UnderlineInputBorder(
        borderSide: BorderSide(
          color: _errorColor,
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      labelStyle: const TextStyle(color: Colors.black),
      hintStyle: TextStyle(color: Colors.grey.shade600),
    ),
    scaffoldBackgroundColor: _backgroundColor,
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      primary: _primaryColor,
      secondary: _secondaryColor,
      error: _errorColor,
      surface: Color(0xFF1E1E1E),
      onPrimary: _onPrimaryColor,
      onSecondary: _onSecondaryColor,
      onSurface: Colors.white,
      onError: _onErrorColor,
    ),
    textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: Color(0xFF1E1E1E),
      foregroundColor: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1E1E1E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _primaryColor),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _errorColor),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
  );
}

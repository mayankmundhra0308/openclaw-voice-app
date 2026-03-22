import 'package:flutter/material.dart';

class AppTheme {
  static const primaryColor = Color(0xFF6C63FF);
  static const bgColor = Color(0xFF0F0F1A);
  static const surfaceColor = Color(0xFF1A1A2E);
  static const cardColor = Color(0xFF16213E);
  static const userBubble = Color(0xFF6C63FF);
  static const aiBubble = Color(0xFF1E2A4A);
  static const accentColor = Color(0xFF00D4FF);

  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        primaryColor: primaryColor,
        scaffoldBackgroundColor: bgColor,
        colorScheme: const ColorScheme.dark(
          primary: primaryColor,
          secondary: accentColor,
          surface: surfaceColor,
          background: bgColor,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: bgColor,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: CardTheme(
          color: cardColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
        ),
      );
}

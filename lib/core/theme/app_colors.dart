import 'package:flutter/material.dart';

/// Extended color palette for Dytty.
/// Category colors, surface tints, and shared constants.
class AppColors {
  AppColors._();

  // Brand
  static const seedColor = Color(0xFF6B4EFF);

  // Category colors — light mode
  static const positive = Color(0xFFF59E0B);
  static const negative = Color(0xFF6366F1);
  static const gratitude = Color(0xFF10B981);
  static const beauty = Color(0xFFEC4899);
  static const identity = Color(0xFF06B6D4);

  // Category surface tints (12% opacity fills for card backgrounds)
  static Color positiveSurface(Brightness b) =>
      b == Brightness.light ? const Color(0xFFFFF8E1) : const Color(0xFF2D2510);
  static Color negativeSurface(Brightness b) =>
      b == Brightness.light ? const Color(0xFFEEF2FF) : const Color(0xFF1E1B4B);
  static Color gratitudeSurface(Brightness b) =>
      b == Brightness.light ? const Color(0xFFECFDF5) : const Color(0xFF0D3B2E);
  static Color beautySurface(Brightness b) =>
      b == Brightness.light ? const Color(0xFFFDF2F8) : const Color(0xFF3B0D29);
  static Color identitySurface(Brightness b) =>
      b == Brightness.light ? const Color(0xFFECFEFF) : const Color(0xFF0D3B3E);

  // Light theme surfaces
  static const lightSurface = Color(0xFFFAF9F6);
  static const lightBackground = Color(0xFFF5F3EE);
  static const lightCard = Colors.white;

  // Dark theme surfaces
  static const darkSurface = Color(0xFF121212);
  static const darkBackground = Color(0xFF1A1A1A);
  static const darkCard = Color(0xFF1E1E1E);

  /// Get category surface color based on category and brightness.
  static Color categorySurface(String categoryName, Brightness b) {
    switch (categoryName) {
      case 'positive':
        return positiveSurface(b);
      case 'negative':
        return negativeSurface(b);
      case 'gratitude':
        return gratitudeSurface(b);
      case 'beauty':
        return beautySurface(b);
      case 'identity':
        return identitySurface(b);
      default:
        return b == Brightness.light ? lightCard : darkCard;
    }
  }
}

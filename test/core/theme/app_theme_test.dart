import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dytty/core/theme/app_theme.dart';
import 'package:dytty/core/theme/app_colors.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  group('AppTheme.light', () {
    late ThemeData theme;

    setUp(() {
      theme = AppTheme.light;
    });

    test('uses Material 3', () {
      expect(theme.useMaterial3, isTrue);
    });

    test('has light brightness color scheme', () {
      expect(theme.colorScheme.brightness, Brightness.light);
    });

    test('color scheme is seeded from AppColors.seedColor', () {
      final expected = ColorScheme.fromSeed(
        seedColor: AppColors.seedColor,
        brightness: Brightness.light,
        surface: AppColors.lightSurface,
      );
      expect(theme.colorScheme.primary, expected.primary);
    });

    test('scaffold background uses light background color', () {
      expect(theme.scaffoldBackgroundColor, AppColors.lightBackground);
    });

    test('appBar has zero elevation and no center title', () {
      expect(theme.appBarTheme.elevation, 0);
      expect(theme.appBarTheme.centerTitle, isFalse);
      expect(theme.appBarTheme.scrolledUnderElevation, 1);
    });

    test('appBar colors match color scheme surface', () {
      expect(theme.appBarTheme.backgroundColor, theme.colorScheme.surface);
      expect(theme.appBarTheme.foregroundColor, theme.colorScheme.onSurface);
    });

    test('card theme has zero elevation and light card color', () {
      expect(theme.cardTheme.elevation, 0);
      expect(theme.cardTheme.color, AppColors.lightCard);
      expect(theme.cardTheme.margin, EdgeInsets.zero);
    });

    test('card shape has rounded border with radius 16', () {
      final shape = theme.cardTheme.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(16));
    });

    test('input decoration theme is filled with rounded borders', () {
      final inputTheme = theme.inputDecorationTheme;
      expect(inputTheme.filled, isTrue);
      expect(
        inputTheme.contentPadding,
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
    });

    test('snackbar uses floating behavior with rounded shape', () {
      expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
    });

    test('dialog has rounded shape with radius 20', () {
      final shape = theme.dialogTheme.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(20));
    });

    test('bottom sheet shows drag handle and has top-rounded shape', () {
      expect(theme.bottomSheetTheme.showDragHandle, isTrue);
      final shape = theme.bottomSheetTheme.shape as RoundedRectangleBorder;
      expect(
        shape.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(20)),
      );
    });

    test('FAB uses primaryContainer colors with rounded shape', () {
      final fab = theme.floatingActionButtonTheme;
      expect(fab.backgroundColor, theme.colorScheme.primaryContainer);
      expect(fab.foregroundColor, theme.colorScheme.onPrimaryContainer);
    });

    test('divider space is 1', () {
      expect(theme.dividerTheme.space, 1);
    });

    testWidgets('can be used as MaterialApp theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: Text('Hello')),
        ),
      );

      expect(find.text('Hello'), findsOneWidget);
      final context = tester.element(find.text('Hello'));
      expect(Theme.of(context).useMaterial3, isTrue);
      expect(Theme.of(context).colorScheme.brightness, Brightness.light);
    });
  });

  group('AppTheme.dark', () {
    late ThemeData theme;

    setUp(() {
      theme = AppTheme.dark;
    });

    test('uses Material 3', () {
      expect(theme.useMaterial3, isTrue);
    });

    test('has dark brightness color scheme', () {
      expect(theme.colorScheme.brightness, Brightness.dark);
    });

    test('color scheme is seeded from AppColors.seedColor', () {
      final expected = ColorScheme.fromSeed(
        seedColor: AppColors.seedColor,
        brightness: Brightness.dark,
        surface: AppColors.darkSurface,
      );
      expect(theme.colorScheme.primary, expected.primary);
    });

    test('scaffold background uses dark background color', () {
      expect(theme.scaffoldBackgroundColor, AppColors.darkBackground);
    });

    test('card theme uses dark card color', () {
      expect(theme.cardTheme.color, AppColors.darkCard);
    });

    test('appBar has zero elevation and no center title', () {
      expect(theme.appBarTheme.elevation, 0);
      expect(theme.appBarTheme.centerTitle, isFalse);
    });

    test('shared theme properties match light theme structure', () {
      // Both themes should share the same structural properties
      expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
      expect(theme.bottomSheetTheme.showDragHandle, isTrue);
      expect(theme.dividerTheme.space, 1);
      expect(theme.cardTheme.elevation, 0);
    });

    testWidgets('can be used as MaterialApp darkTheme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          home: const Scaffold(body: Text('Dark')),
        ),
      );

      expect(find.text('Dark'), findsOneWidget);
      final context = tester.element(find.text('Dark'));
      expect(Theme.of(context).colorScheme.brightness, Brightness.dark);
    });
  });
}

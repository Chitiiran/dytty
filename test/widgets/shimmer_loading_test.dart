import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/core/widgets/shimmer_loading.dart';

void main() {
  group('ShimmerCategoryCard', () {
    testWidgets('renders in light theme', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ShimmerCategoryCard()),
        ),
      );

      expect(find.byType(ShimmerCategoryCard), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
      expect(find.byType(CircleAvatar), findsOneWidget);
    });

    testWidgets('renders in dark theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(body: ShimmerCategoryCard()),
        ),
      );

      expect(find.byType(ShimmerCategoryCard), findsOneWidget);
    });
  });

  group('ShimmerJournalLoading', () {
    testWidgets('renders 5 shimmer category cards', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ShimmerJournalLoading()),
        ),
      );

      expect(find.byType(ShimmerCategoryCard), findsNWidgets(5));
    });
  });

  group('ShimmerProgressCard', () {
    testWidgets('renders in light theme', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ShimmerProgressCard()),
        ),
      );

      expect(find.byType(ShimmerProgressCard), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
      expect(find.byType(CircleAvatar), findsNWidgets(5));
    });

    testWidgets('renders in dark theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(body: ShimmerProgressCard()),
        ),
      );

      expect(find.byType(ShimmerProgressCard), findsOneWidget);
    });
  });
}

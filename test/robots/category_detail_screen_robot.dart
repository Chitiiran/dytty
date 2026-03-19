import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/features/category_detail/widgets/date_group_header.dart';
import 'package:dytty/features/category_detail/widgets/inline_entry_tile.dart';
import 'package:dytty/features/category_detail/widgets/review_summary_card.dart';
import 'package:dytty/features/category_detail/widgets/empty_category_state.dart';

/// Robot for interacting with and asserting on CategoryDetailScreen.
class CategoryDetailScreenRobot {
  CategoryDetailScreenRobot(this.tester);
  final WidgetTester tester;

  void expectCategoryName(String name) {
    expect(find.text(name), findsOneWidget);
  }

  void expectLoading() {
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  }

  void expectEmptyState() {
    expect(find.byType(EmptyCategoryState), findsOneWidget);
  }

  void expectNoEmptyState() {
    expect(find.byType(EmptyCategoryState), findsNothing);
  }

  void expectDateGroupHeader(String label) {
    expect(find.widgetWithText(DateGroupHeader, label), findsOneWidget);
  }

  void expectEntryText(String text) {
    expect(find.text(text), findsOneWidget);
  }

  void expectEntryTileCount(int count) {
    expect(find.byType(InlineEntryTile), findsNWidgets(count));
  }

  void expectReviewSummaryCard() {
    expect(find.byType(ReviewSummaryCard), findsOneWidget);
  }

  void expectNoReviewSummaryCard() {
    expect(find.byType(ReviewSummaryCard), findsNothing);
  }

  Future<void> tapDateGroupHeader(String label) async {
    await tester.tap(find.widgetWithText(DateGroupHeader, label));
    await tester.pumpAndSettle();
  }

  Future<void> tapBack() async {
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
  }
}

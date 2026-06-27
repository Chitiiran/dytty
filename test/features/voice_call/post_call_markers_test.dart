import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dytty/features/voice_call/bloc/voice_call_bloc.dart';
import 'package:dytty/features/voice_call/voice_call_screen.dart';

void main() {
  Widget wrap(SavedEntry entry, {VoidCallback? onReject}) => MaterialApp(
    home: Scaffold(
      body: SavedEntryTile(entry: entry, onReject: onReject),
    ),
  );

  testWidgets('shows "added by AI" marker for a reconciled add', (
    tester,
  ) async {
    const entry = SavedEntry(
      entryId: 'x',
      categoryId: 'beauty',
      text: 'The sunset was unreal',
      transcript: '',
      addedByAi: true,
    );
    await tester.pumpWidget(wrap(entry));
    expect(find.textContaining('added by AI'), findsOneWidget);
  });

  testWidgets('shows "reworded by AI" marker for a reconciled reword', (
    tester,
  ) async {
    const entry = SavedEntry(
      entryId: 'x',
      categoryId: 'negative',
      text: 'Paid for a sub but needed FIFA',
      transcript: '',
      rewordedByAi: true,
    );
    await tester.pumpWidget(wrap(entry));
    expect(find.textContaining('reworded by AI'), findsOneWidget);
  });

  testWidgets('shows no marker for a normal in-call entry', (tester) async {
    const entry = SavedEntry(
      entryId: 'x',
      categoryId: 'positive',
      text: 'Felt good today',
      transcript: '',
    );
    await tester.pumpWidget(wrap(entry));
    expect(find.textContaining('added by AI'), findsNothing);
    expect(find.textContaining('reworded by AI'), findsNothing);
  });

  testWidgets('reject button fires onReject when provided', (tester) async {
    var rejected = false;
    const entry = SavedEntry(
      entryId: 'x',
      categoryId: 'beauty',
      text: 'sunset',
      transcript: '',
      addedByAi: true,
    );
    await tester.pumpWidget(wrap(entry, onReject: () => rejected = true));
    await tester.tap(find.byTooltip('Reject entry'));
    expect(rejected, isTrue);
  });

  testWidgets('no reject button when onReject is null', (tester) async {
    const entry = SavedEntry(
      entryId: 'x',
      categoryId: 'beauty',
      text: 'sunset',
      transcript: '',
    );
    await tester.pumpWidget(wrap(entry));
    expect(find.byTooltip('Reject entry'), findsNothing);
  });
}

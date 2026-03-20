import 'orchestrator.dart';
import 'rubric.dart';

/// Print scores for a single eval result.
void printSingleResult(EvalResult result) {
  print('\n--- Scores: ${result.persona} ---');
  for (final dim in Dimension.values) {
    final score = result.scores.scores[dim] ?? 0;
    final bar = '${'*' * score}${' ' * (5 - score)}';
    print('  ${dim.label.padRight(28)} [$bar] $score/5');
  }
  print('  ${'Average'.padRight(28)}       '
      '${result.scores.average.toStringAsFixed(1)}/5');

  if (result.scores.judgeNotes.isNotEmpty) {
    print('\n  Notes: ${result.scores.judgeNotes}');
  }
  if (result.scores.flaggedTurns.isNotEmpty) {
    print('  Flagged turns: ${result.scores.flaggedTurns.join(', ')}');
  }
}

/// Print a summary table across multiple persona results.
void printSummaryTable(List<EvalResult> results) {
  if (results.isEmpty) return;

  print('\n${'=' * 80}');
  print('EVAL SUMMARY');
  print('${'=' * 80}\n');

  // Header
  final dimHeaders =
      Dimension.values.map((d) => d.shortLabel.padLeft(7)).join('');
  print('${'Persona'.padRight(20)}$dimHeaders${'AVG'.padLeft(7)}');
  print('-' * 80);

  // Rows
  final allScores = <Dimension, List<int>>{};
  for (final dim in Dimension.values) {
    allScores[dim] = [];
  }

  for (final result in results) {
    final cells = <String>[];
    for (final dim in Dimension.values) {
      final score = result.scores.scores[dim] ?? 0;
      allScores[dim]!.add(score);
      cells.add(score.toString().padLeft(7));
    }
    final avg = result.scores.average.toStringAsFixed(1).padLeft(7);
    print('${result.persona.padRight(20)}${cells.join('')}$avg');
  }

  // Average row
  if (results.length > 1) {
    print('-' * 80);
    final avgCells = <String>[];
    var totalAvg = 0.0;
    for (final dim in Dimension.values) {
      final scores = allScores[dim]!;
      final avg = scores.reduce((a, b) => a + b) / scores.length;
      totalAvg += avg;
      avgCells.add(avg.toStringAsFixed(1).padLeft(7));
    }
    totalAvg /= Dimension.values.length;
    print(
      '${'AVERAGE'.padRight(20)}${avgCells.join('')}'
      '${totalAvg.toStringAsFixed(1).padLeft(7)}',
    );
  }

  print('');
}

// Unified test report dashboard — combines Flutter, Playwright, and Maestro results.
// Usage: dart run tool/test_report.dart [--run-dir <path>] [input] [output] [--no-screenshots]
//   --run-dir   resolve all paths relative to this directory (e.g. test-output/runs/<timestamp>)
//   input       defaults to test-results.json (legacy) or <run-dir>/flutter/results.json
//   output      defaults to test-report.html (legacy) or <run-dir>/report.html

import 'dart:io';

import 'test_report/models.dart';
import 'test_report/parsers.dart';
import 'test_report/html_renderer.dart';

void main(List<String> args) {
  final noScreenshots = args.contains('--no-screenshots');

  // Parse --run-dir flag
  String? runDir;
  final filteredArgs = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--run-dir' && i + 1 < args.length) {
      runDir = args[i + 1];
      i++; // skip value
    } else if (!args[i].startsWith('--')) {
      filteredArgs.add(args[i]);
    }
  }

  // Auto-detect run-dir: if not provided, try test-output/latest
  if (runDir == null && Directory('test-output/latest').existsSync()) {
    runDir = 'test-output/latest';
  }

  // Resolve paths based on run-dir or legacy defaults
  final String inputPath;
  final String outputPath;
  final String covPath;
  final String playwrightPath;
  final String maestroDir;
  final String playwrightScreenshotDir;
  final String flutterEnvPath;
  final String playwrightEnvPath;
  final String maestroEnvPath;

  if (runDir != null) {
    inputPath = filteredArgs.isNotEmpty
        ? filteredArgs[0]
        : '$runDir/flutter/results.json';
    outputPath = filteredArgs.length > 1
        ? filteredArgs[1]
        : '$runDir/report.html';
    covPath = '$runDir/flutter/lcov.info';
    playwrightPath = '$runDir/playwright/results.json';
    maestroDir = '$runDir/device-e2e/maestro';
    playwrightScreenshotDir = '$runDir/playwright/screenshots';
    flutterEnvPath = '$runDir/flutter/env.json';
    playwrightEnvPath = '$runDir/playwright/env.json';
    maestroEnvPath = '$runDir/device-e2e/maestro/env.json';
  } else {
    inputPath = filteredArgs.isNotEmpty ? filteredArgs[0] : 'test-results.json';
    outputPath = filteredArgs.length > 1 ? filteredArgs[1] : 'test-report.html';
    covPath = 'coverage/lcov.info';
    playwrightPath = 'playwright-results.json';
    maestroDir = '.maestro/screenshots/latest';
    playwrightScreenshotDir = 'test-results';
    flutterEnvPath = '';
    playwrightEnvPath = '';
    maestroEnvPath = '';
  }

  // --- Parse all data sources ---
  final flutterResults = parseFlutterResults(inputPath);
  final flutterSuites = flutterResults.suites;
  final covFiles = parseLcov(covPath);
  final playwrightResults = parsePlaywrightResults(playwrightPath);
  final maestroResults = parseMaestroResults(maestroDir);
  final maestroScreenshots = noScreenshots
      ? <Screenshot>[]
      : collectScreenshots(maestroDir);
  final playwrightScreenshots = noScreenshots
      ? <Screenshot>[]
      : collectScreenshots(playwrightScreenshotDir);
  final e2eCoverage = parseScreenCoverage('tool/screen-coverage.yaml');

  // --- Categorize Flutter suites ---
  final unitSuites = <String, List<Test>>{};
  final widgetSuites = <String, List<Test>>{};
  final goldenSuites = <String, List<Test>>{};

  for (final entry in flutterSuites.entries) {
    final path = entry.key;
    if (path.contains('test/goldens/') || path.contains('test\\goldens\\')) {
      goldenSuites[path] = entry.value;
    } else if (path.contains('test/widgets/') ||
        path.contains('test\\widgets\\')) {
      widgetSuites[path] = entry.value;
    } else {
      unitSuites[path] = entry.value;
    }
  }

  // --- Read environment metadata ---
  final flutterEnv = readEnvLabel(flutterEnvPath);
  final playwrightEnv = readEnvLabel(playwrightEnvPath);
  final maestroEnv = readEnvLabel(maestroEnvPath);

  // --- Build test layers ---
  final layers = <TestLayer>[
    buildFlutterLayer(
      'Unit Tests',
      'unit',
      unitSuites,
      'flutter test --machine > test-results.json',
      flutterEnv,
    ),
    buildFlutterLayer(
      'Widget Tests',
      'widget',
      widgetSuites,
      'flutter test test/widgets/ --machine > test-results.json',
      flutterEnv,
    ),
    buildFlutterLayer(
      'Golden Tests',
      'golden',
      goldenSuites,
      'flutter test test/goldens/ --machine > test-results.json',
      flutterEnv,
    ),
    buildPlaywrightLayer(
      playwrightResults,
      playwrightScreenshots,
      playwrightEnv,
    ),
    buildMaestroLayer(maestroResults, maestroScreenshots, maestroEnv),
  ];

  // --- Generate HTML ---
  final html = renderReport(
    layers: layers,
    covFiles: covFiles,
    e2eCoverage: e2eCoverage,
  );

  File(outputPath).writeAsStringSync(html);

  // --- Summary ---
  var covLineHit = 0, covLineTotal = 0;
  for (final f in covFiles) {
    covLineHit += f.lineHit;
    covLineTotal += f.lineTotal;
  }
  final covPct = covLineTotal > 0 ? (covLineHit / covLineTotal * 100) : 0.0;

  var totalTests = 0, totalPassed = 0, totalFailed = 0;
  for (final c in layers) {
    totalTests += c.total;
    totalPassed += c.passed;
    totalFailed += c.failed;
  }

  final covMsg = covFiles.isNotEmpty
      ? ', coverage ${covPct.toStringAsFixed(1)}%'
      : '';
  final srcCount = layers.where((c) => c.total > 0).length;
  print(
    'Test report: $outputPath '
    '($totalPassed/$totalTests passed, $totalFailed failed$covMsg, $srcCount data sources)',
  );
}

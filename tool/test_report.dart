// Unified test report dashboard — combines Flutter, Playwright, and Maestro results.
// Usage: dart run tool/test_report.dart [--run-dir <path>] [input] [output] [--no-screenshots]
//   --run-dir   resolve all paths relative to this directory (e.g. test-output/runs/<timestamp>)
//   input       defaults to test-results.json (legacy) or <run-dir>/flutter/results.json
//   output      defaults to test-report.html (legacy) or <run-dir>/report.html

import 'dart:convert';
import 'dart:io';

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
    inputPath = filteredArgs.isNotEmpty ? filteredArgs[0] : '$runDir/flutter/results.json';
    outputPath = filteredArgs.length > 1 ? filteredArgs[1] : '$runDir/report.html';
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
  final flutterResults = _parseFlutterResults(inputPath);
  final flutterSuites = flutterResults.suites;
  final covFiles = _parseLcov(covPath);
  final playwrightResults = _parsePlaywrightResults(playwrightPath);
  final maestroResults = _parseMaestroResults(maestroDir);
  final maestroScreenshots =
      noScreenshots ? <_Screenshot>[] : _collectScreenshots(maestroDir);
  final playwrightScreenshots =
      noScreenshots ? <_Screenshot>[] : _collectScreenshots(playwrightScreenshotDir);
  final e2eCoverage = _parseScreenCoverage('tool/screen-coverage.yaml');

  // --- Categorize Flutter suites ---
  final unitSuites = <String, List<_Test>>{};
  final widgetSuites = <String, List<_Test>>{};
  final goldenSuites = <String, List<_Test>>{};

  for (final entry in flutterSuites.entries) {
    final path = entry.key;
    if (path.contains('test/goldens/') || path.contains('test\\goldens\\')) {
      goldenSuites[path] = entry.value;
    } else if (path.contains('test/widgets/') || path.contains('test\\widgets\\')) {
      widgetSuites[path] = entry.value;
    } else {
      unitSuites[path] = entry.value;
    }
  }

  // --- Read environment metadata ---
  final flutterEnv = _readEnvLabel(flutterEnvPath);
  final playwrightEnv = _readEnvLabel(playwrightEnvPath);
  final maestroEnv = _readEnvLabel(maestroEnvPath);

  // --- Build category stats ---
  final categories = <_Category>[
    _buildCategory('Unit Tests', 'unit', unitSuites,
        'flutter test --machine > test-results.json', flutterEnv),
    _buildCategory('Widget Tests', 'widget', widgetSuites,
        'flutter test test/widgets/ --machine > test-results.json', flutterEnv),
    _buildCategory('Golden Tests', 'golden', goldenSuites,
        'flutter test test/goldens/ --machine > test-results.json', flutterEnv),
    _buildPlaywrightCategory(playwrightResults, playwrightScreenshots, playwrightEnv),
    _buildMaestroCategory(maestroResults, maestroScreenshots, maestroEnv),
  ];

  // --- Overall stats ---
  var totalTests = 0, totalPassed = 0, totalFailed = 0, totalSkipped = 0;
  for (final c in categories) {
    totalTests += c.total;
    totalPassed += c.passed;
    totalFailed += c.failed;
    totalSkipped += c.skipped;
  }
  final overallPct = totalTests > 0 ? (totalPassed / totalTests * 100) : 0.0;

  var covHit = 0, covTotal = 0;
  for (final f in covFiles) {
    covHit += f.hit;
    covTotal += f.total;
  }
  final covPct = covTotal > 0 ? (covHit / covTotal * 100) : 0.0;

  // --- Generate HTML ---
  final buf = StringBuffer();
  buf.writeln('<!DOCTYPE html>');
  buf.writeln('<html lang="en"><head>');
  buf.writeln('<meta charset="UTF-8">');
  buf.writeln(
    '<meta name="viewport" content="width=device-width, initial-scale=1.0">',
  );
  buf.writeln('<title>Dytty Test Report</title>');
  buf.writeln('<style>');
  buf.writeln(_css);
  buf.writeln('</style></head><body>');
  buf.writeln('<h1>Dytty Test Report</h1>');
  buf.writeln(
    '<p class="timestamp">Generated: ${DateTime.now().toIso8601String()}</p>',
  );

  // Overall summary bar
  buf.writeln('<div class="summary">');
  buf.writeln(_summaryCard(totalTests, 'Total', 'total'));
  buf.writeln(_summaryCard(totalPassed, 'Passed', 'pass'));
  buf.writeln(_summaryCard(totalFailed, 'Failed', 'fail'));
  buf.writeln(_summaryCard(totalSkipped, 'Skipped', 'skip'));
  final pctColor = _pctColor(overallPct);
  buf.writeln(
    '<div class="card"><div class="num" style="color:$pctColor">'
    '${overallPct.toStringAsFixed(1)}%</div>'
    '<div class="label">Pass Rate</div></div>',
  );
  if (covTotal > 0) {
    final cc = _pctColor(covPct);
    buf.writeln(
      '<div class="card"><div class="num" style="color:$cc">'
      '${covPct.toStringAsFixed(1)}%</div>'
      '<div class="label">Line Coverage</div></div>',
    );
  }
  if (e2eCoverage.screens.isNotEmpty) {
    final covScreens = e2eCoverage.screens.where((s) => s.hasCoverage).length;
    final screenPct = covScreens / e2eCoverage.screens.length * 100;
    final sc = _pctColor(screenPct);
    buf.writeln(
      '<div class="card"><div class="num" style="color:$sc">'
      '${screenPct.toStringAsFixed(0)}%</div>'
      '<div class="label">Screen E2E</div></div>',
    );
  }
  if (e2eCoverage.flows.isNotEmpty) {
    final covFlows = e2eCoverage.flows.where((f) => f.hasCoverage).length;
    final flowPct = covFlows / e2eCoverage.flows.length * 100;
    final fc = _pctColor(flowPct);
    buf.writeln(
      '<div class="card"><div class="num" style="color:$fc">'
      '${flowPct.toStringAsFixed(0)}%</div>'
      '<div class="label">Flow E2E</div></div>',
    );
  }
  final totalDurationMs = categories.fold<int>(0, (s, c) => s + c.durationMs);
  if (totalDurationMs > 0) {
    buf.writeln(
      '<div class="card"><div class="num">'
      '${_formatDuration(totalDurationMs)}</div>'
      '<div class="label">Duration</div></div>',
    );
    if (totalTests > 0) {
      final throughput = totalTests / (totalDurationMs / 1000);
      buf.writeln(
        '<div class="card"><div class="num">'
        '${throughput.toStringAsFixed(1)}/s</div>'
        '<div class="label">Throughput</div></div>',
      );
    }
  }
  buf.writeln('</div>');

  // Category summary cards (boxed with timing bars)
  final maxDur = categories.fold<int>(0, (m, c) => c.durationMs > m ? c.durationMs : m);
  buf.writeln('<div class="cat-grid">');
  for (final c in categories) {
    final cls = c.failed > 0
        ? 'fail'
        : c.total == 0
            ? 'muted'
            : 'pass';
    final layerColor = _layerColor(c.id);
    final durStr = c.durationMs > 0 ? _formatDuration(c.durationMs) : '';
    final barPct = maxDur > 0 && c.durationMs > 0
        ? (c.durationMs / maxDur * 100).clamp(0, 100)
        : 0.0;
    final envStr = c.environment.isNotEmpty
        ? '<div class="cat-env">${_esc(c.environment)}</div>'
        : '';

    buf.writeln(
      '<a href="#${c.id}" class="cat-box $cls" style="border-left:4px solid $layerColor;text-decoration:none;color:inherit">'
      '<div class="cat-box-top">'
      '<div class="cat-box-num">${c.total > 0 ? '${c.passed}/${c.total}' : '--'}</div>'
      '<div class="cat-box-name">${_esc(c.name)}</div>'
      '</div>',
    );
    if (durStr.isNotEmpty) {
      buf.writeln(
        '<div class="cat-box-dur">'
        '<div class="dur-bar"><div class="dur-fill" style="width:${barPct.toStringAsFixed(0)}%;background:$layerColor"></div></div>'
        '<span class="dur-label">$durStr</span>'
        '</div>',
      );
    }
    if (envStr.isNotEmpty) buf.writeln(envStr);
    buf.writeln('</a>');
  }
  buf.writeln('</div>');

  // Category sections (collapsible)
  for (final c in categories) {
    final secDur = c.durationMs > 0 ? ' — ${_formatDuration(c.durationMs)}' : '';
    final secEnv = c.environment.isNotEmpty
        ? ' <span class="env-badge">${_esc(c.environment)}</span>'
        : '';
    final hasFails = c.failed > 0;
    final hasData = c.total > 0 || c.screenshots.isNotEmpty;

    if (!hasData) {
      buf.writeln('<h2 id="${c.id}">${_esc(c.name)}$secDur$secEnv</h2>');
      buf.writeln(
        '<div class="no-data">No data available. Run: <code>${_esc(c.generateCmd)}</code></div>',
      );
      continue;
    }

    // Collapsible section — auto-expand if failures
    buf.writeln('<details class="cat-section"${hasFails ? ' open' : ''}>');
    buf.writeln(
      '<summary><h2 id="${c.id}" class="cat-section-header">'
      '${_esc(c.name)}$secDur$secEnv</h2></summary>',
    );

    // Test suites — folder-grouped for Flutter, flat for others
    final isFlutter = const ['unit', 'widget', 'golden'].contains(c.id);
    if (isFlutter && c.suiteKeys.length > 1) {
      _writeFolderGroupedSuites(buf, c);
    } else {
      _writeFlatSuites(buf, c);
    }

    // Screenshots (collapsed by default)
    if (c.screenshots.isNotEmpty) {
      final grouped = <String, List<_Screenshot>>{};
      for (final s in c.screenshots) {
        grouped.putIfAbsent(s.folder, () => []).add(s);
      }
      final folders = grouped.keys.toList()..sort();
      final totalScreenshots = c.screenshots.length;

      buf.writeln('<details class="suite">');
      buf.writeln(
        '<summary class="suite-header"><span>Screenshots</span>'
        '<span class="counts">$totalScreenshots screenshots</span></summary>',
      );
      for (final folder in folders) {
        buf.writeln('<div class="screenshot-folder-label">${_esc(folder)}/</div>');
        buf.writeln('<div class="screenshot-grid">');
        for (final s in grouped[folder]!) {
          buf.writeln(
            '<div class="screenshot"><img src="data:image/png;base64,${s.base64}" '
            'alt="${_esc(s.name)}" loading="lazy">'
            '<div class="screenshot-label">${_esc(s.name)}</div></div>',
          );
        }
        buf.writeln('</div>');
      }
      buf.writeln('</details>');
    }

    buf.writeln('</details>');
  }

  // E2E screen/flow coverage
  if (e2eCoverage.screens.isNotEmpty || e2eCoverage.flows.isNotEmpty) {
    _writeE2eCoverage(buf, e2eCoverage);
  }

  // Coverage by file
  if (covFiles.isNotEmpty) {
    final covColor = _pctColor(covPct);
    buf.writeln('<h2 id="coverage">Coverage: ${covPct.toStringAsFixed(1)}%</h2>');
    buf.writeln('<div class="summary">');
    buf.writeln(
      '<div class="card" style="flex:1;max-width:400px">'
      '<div class="num" style="color:$covColor">${covPct.toStringAsFixed(1)}%</div>'
      '<div class="label">$covHit / $covTotal lines</div></div>',
    );
    buf.writeln('</div>');

    // Zero-coverage callout
    final zeroCov = covFiles.where((f) => f.pct == 0).toList();
    if (zeroCov.isNotEmpty) {
      buf.writeln('<div class="zero-cov-callout">');
      buf.writeln('<strong>0% coverage (${zeroCov.length} files)</strong>');
      buf.writeln('<ul>');
      for (final f in zeroCov) {
        final name = f.path.split('/').last;
        buf.writeln('<li><code>${_esc(name)}</code> — ${f.total} lines</li>');
      }
      buf.writeln('</ul></div>');
    }

    // Group coverage by folder
    covFiles.sort((a, b) => a.pct.compareTo(b.pct));
    final covFolders = <String, List<_CovFile>>{};
    for (final f in covFiles) {
      final parts = f.path.split('/');
      final folder = parts.length > 2
          ? parts.sublist(0, parts.length - 1).join('/')
          : 'lib';
      covFolders.putIfAbsent(folder, () => []).add(f);
    }

    final covFolderKeys = covFolders.keys.toList()..sort();
    for (final folder in covFolderKeys) {
      final files = covFolders[folder]!;
      var fHit = 0, fTotal = 0;
      for (final f in files) {
        fHit += f.hit;
        fTotal += f.total;
      }
      final fPct = fTotal > 0 ? (fHit / fTotal * 100) : 0.0;
      final fColor = _pctColor(fPct);
      final autoOpen = fPct < 50;

      buf.writeln('<details class="suite folder-group"${autoOpen ? ' open' : ''}>');
      buf.writeln(
        '<summary class="suite-header folder-header"><span>${_esc(folder)}/</span>'
        '<span class="counts" style="color:$fColor">${fPct.toStringAsFixed(0)}% — ${files.length} files</span></summary>',
      );
      for (final f in files) {
        final pctStr = f.pct.toStringAsFixed(0);
        final barColor = _pctColor(f.pct);
        buf.writeln('<div class="cov-row">');
        buf.writeln('<span class="file">${_esc(f.path.split('/').last)}</span>');
        buf.writeln(
          '<div class="coverage-bar"><div class="fill" '
          'style="width:${f.pct.clamp(0, 100)}%;background:$barColor"></div></div>',
        );
        buf.writeln('<span class="pct" style="color:$barColor">$pctStr%</span>');
        buf.writeln('<span class="ratio">${f.hit}/${f.total}</span>');
        buf.writeln('</div>');
      }
      buf.writeln('</details>');
    }
  }

  buf.writeln('</body></html>');

  File(outputPath).writeAsStringSync(buf.toString());
  final covMsg = covFiles.isNotEmpty ? ', coverage ${covPct.toStringAsFixed(1)}%' : '';
  final srcCount = categories.where((c) => c.total > 0).length;
  print(
    'Test report: $outputPath '
    '($totalPassed/$totalTests passed, $totalFailed failed$covMsg, $srcCount data sources)',
  );
}

// --- Data classes ---

class _Test {
  _Test({required this.name, required this.suiteId});

  final String name;
  final int suiteId;
  String? result;
  bool hidden = false;
  bool skipped = false;
  int time = 0;
  String? error;
  String? stackTrace;
}

class _FlutterResults {
  _FlutterResults(this.suites, this.durationMs);

  final Map<String, List<_Test>> suites;
  final int durationMs;
}

class _ParsedResults {
  _ParsedResults(this.suites, this.durationMs);

  final Map<String, List<_Test>> suites;
  final int durationMs;
}

class _CovFile {
  _CovFile(this.path, this.hit, this.total);

  final String path;
  final int hit;
  final int total;
  double get pct => total > 0 ? (hit / total * 100) : 0;
}

class _Screenshot {
  _Screenshot(this.folder, this.name, this.base64);

  final String folder;
  final String name;
  final String base64;
}

class _Category {
  _Category({
    required this.name,
    required this.id,
    required this.suites,
    required this.generateCmd,
    this.screenshots = const [],
    this.durationMs = 0,
    this.environment = '',
  });

  final String name;
  final String id;
  final Map<String, List<_Test>> suites;
  final String generateCmd;
  final List<_Screenshot> screenshots;
  final int durationMs;
  final String environment;

  late final suiteKeys = suites.keys.toList()..sort();
  late final total = suites.values.fold<int>(0, (s, v) => s + v.length);
  late final passed = suites.values
      .fold<int>(0, (s, v) => s + v.where((t) => t.result == 'success').length);
  late final failed = suites.values
      .fold<int>(0, (s, v) => s + v.where((t) => t.result == 'failure').length);
  late final skipped =
      suites.values.fold<int>(0, (s, v) => s + v.where((t) => t.skipped).length);
}

class _E2eItem {
  _E2eItem({
    required this.id,
    required this.name,
    this.path,
    this.playwright,
    this.maestro,
  });

  final String id;
  final String name;
  final String? path;
  final String? playwright;
  final String? maestro;

  bool get hasPlaywright => playwright != null;
  bool get hasMaestro => maestro != null;
  bool get hasCoverage => hasPlaywright || hasMaestro;
}

class _E2eCoverage {
  _E2eCoverage(this.screens, this.flows);

  final List<_E2eItem> screens;
  final List<_E2eItem> flows;
}

// --- Flutter test JSON parser ---

_FlutterResults _parseFlutterResults(String path) {
  final file = File(path);
  if (!file.existsSync()) return _FlutterResults({}, 0);

  final lines = file.readAsLinesSync().where((l) => l.trim().isNotEmpty);
  final events = <Map<String, dynamic>>[];
  for (final line in lines) {
    try {
      events.add(jsonDecode(line) as Map<String, dynamic>);
    } catch (_) {}
  }

  final tests = <int, _Test>{};
  final suiteNames = <int, String>{};
  var durationMs = 0;

  for (final e in events) {
    final type = e['type'] as String?;
    if (type == 'suite') {
      final suite = e['suite'] as Map<String, dynamic>;
      suiteNames[suite['id'] as int] = suite['path'] as String? ?? '';
    } else if (type == 'testStart') {
      final test = e['test'] as Map<String, dynamic>;
      final id = test['id'] as int;
      tests[id] = _Test(
        name: test['name'] as String? ?? '',
        suiteId: test['suiteID'] as int? ?? 0,
      );
    } else if (type == 'testDone') {
      final id = e['testID'] as int;
      final t = tests[id];
      if (t != null) {
        t.result = e['result'] as String? ?? 'unknown';
        t.hidden = e['hidden'] as bool? ?? false;
        t.skipped = e['skipped'] as bool? ?? false;
        t.time = e['time'] as int? ?? 0;
      }
    } else if (type == 'error') {
      final id = e['testID'] as int;
      final t = tests[id];
      if (t != null) {
        t.error = e['error'] as String? ?? '';
        t.stackTrace = e['stackTrace'] as String? ?? '';
      }
    } else if (type == 'done') {
      durationMs = e['time'] as int? ?? 0;
    }
  }

  final visible =
      tests.values.where((t) => !t.hidden && t.result != null).toList();

  final grouped = <String, List<_Test>>{};
  for (final t in visible) {
    final suite = suiteNames[t.suiteId] ?? 'unknown';
    grouped.putIfAbsent(suite, () => []).add(t);
  }
  return _FlutterResults(grouped, durationMs);
}

// --- Playwright JSON parser ---

_ParsedResults _parsePlaywrightResults(String path) {
  final file = File(path);
  if (!file.existsSync()) return _ParsedResults({}, 0);

  try {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final suites = json['suites'] as List<dynamic>? ?? [];
    final result = <String, List<_Test>>{};

    // Extract total duration from stats.duration (ms, may be double)
    final stats = json['stats'] as Map<String, dynamic>?;
    final durationMs = stats != null
        ? (stats['duration'] as num?)?.round() ?? 0
        : 0;

    void walkSuite(Map<String, dynamic> suite, String parentTitle) {
      final title = suite['title'] as String? ?? '';
      final fullTitle = parentTitle.isEmpty ? title : '$parentTitle > $title';
      final specs = suite['specs'] as List<dynamic>? ?? [];

      for (final spec in specs) {
        final specMap = spec as Map<String, dynamic>;
        final specTitle = specMap['title'] as String? ?? '';
        final tests = specMap['tests'] as List<dynamic>? ?? [];

        for (final test in tests) {
          final testMap = test as Map<String, dynamic>;
          final results = testMap['results'] as List<dynamic>? ?? [];
          final status = testMap['status'] as String? ?? 'unknown';

          final t = _Test(name: specTitle, suiteId: 0);
          if (status == 'expected') {
            t.result = 'success';
          } else if (status == 'skipped') {
            t.result = 'success';
            t.skipped = true;
          } else {
            t.result = 'failure';
            // Extract error from last result
            if (results.isNotEmpty) {
              final lastResult = results.last as Map<String, dynamic>;
              final errors = lastResult['errors'] as List<dynamic>? ?? [];
              if (errors.isNotEmpty) {
                final errMap = errors.first as Map<String, dynamic>;
                t.error = errMap['message'] as String? ?? '';
              }
              final duration = lastResult['duration'] as int? ?? 0;
              t.time = duration;
            }
          }

          if (results.isNotEmpty && t.time == 0) {
            final lastResult = results.last as Map<String, dynamic>;
            t.time = lastResult['duration'] as int? ?? 0;
          }

          final suiteName = fullTitle.isNotEmpty ? fullTitle : 'Playwright';
          result.putIfAbsent(suiteName, () => []).add(t);
        }
      }

      final childSuites = suite['suites'] as List<dynamic>? ?? [];
      for (final child in childSuites) {
        walkSuite(child as Map<String, dynamic>, fullTitle);
      }
    }

    for (final suite in suites) {
      walkSuite(suite as Map<String, dynamic>, '');
    }
    return _ParsedResults(result, durationMs);
  } catch (e) {
    stderr.writeln('Warning: Could not parse playwright-results.json: $e');
    return _ParsedResults({}, 0);
  }
}

// --- Maestro JUnit XML parser ---

_ParsedResults _parseMaestroResults(String dirPath) {
  final xmlFile = File('$dirPath/results.xml');
  if (!xmlFile.existsSync()) return _ParsedResults({}, 0);

  try {
    final content = xmlFile.readAsStringSync();
    final result = <String, List<_Test>>{};

    // Extract total duration by summing all <testsuite> time attributes (seconds)
    var durationMs = 0;
    final suiteTimeMatches =
        RegExp(r'<testsuite\s+[^>]*time="([^"]*)"').allMatches(content);
    for (final m in suiteTimeMatches) {
      durationMs +=
          ((double.tryParse(m.group(1)!) ?? 0) * 1000).round();
    }

    // Simple XML parsing — extract <testcase> elements
    final testCasePattern =
        RegExp(r'<testcase\s+([^>]*)(?:/>|>(.*?)</testcase>)', dotAll: true);
    final attrPattern = RegExp(r'(\w+)="([^"]*)"');

    for (final match in testCasePattern.allMatches(content)) {
      final attrs = <String, String>{};
      for (final a in attrPattern.allMatches(match.group(1)!)) {
        attrs[a.group(1)!] = a.group(2)!;
      }
      final body = match.group(2) ?? '';

      final name = attrs['name'] ?? 'Unknown';
      final className = attrs['classname'] ?? 'Maestro';
      final timeStr = attrs['time'] ?? '0';
      final timeMs = ((double.tryParse(timeStr) ?? 0) * 1000).round();

      final t = _Test(name: name, suiteId: 0);
      t.time = timeMs;

      if (body.contains('<failure') || body.contains('<error')) {
        t.result = 'failure';
        // Extract failure message
        final msgMatch = RegExp(r'message="([^"]*)"').firstMatch(body);
        if (msgMatch != null) {
          t.error = msgMatch.group(1);
        }
      } else if (body.contains('<skipped')) {
        t.result = 'success';
        t.skipped = true;
      } else {
        t.result = 'success';
      }

      result.putIfAbsent(className, () => []).add(t);
    }

    // Fallback: sum individual test times if no suite-level time
    if (durationMs == 0) {
      for (final tests in result.values) {
        for (final t in tests) {
          durationMs += t.time;
        }
      }
    }

    return _ParsedResults(result, durationMs);
  } catch (e) {
    stderr.writeln('Warning: Could not parse Maestro results.xml: $e');
    return _ParsedResults({}, 0);
  }
}

// --- Screenshot collector ---

List<_Screenshot> _collectScreenshots(String dirPath) {
  final dir = Directory(dirPath);
  if (!dir.existsSync()) return [];

  final screenshots = <_Screenshot>[];
  for (final entity in dir.listSync(recursive: true)) {
    if (entity is File && entity.path.toLowerCase().endsWith('.png')) {
      try {
        final bytes = entity.readAsBytesSync();
        final b64 = base64Encode(bytes);
        final normalizedDir = dirPath.replaceAll('\\', '/');
        final relative = entity.path
            .replaceAll('\\', '/')
            .replaceAll(RegExp('^${RegExp.escape(normalizedDir)}/'), '');
        final parts = relative.split('/');
        final folder = parts.length > 1 ? parts[parts.length - 2] : 'root';
        final name = parts.last.replaceAll('.png', '');
        screenshots.add(_Screenshot(folder, name, b64));
      } catch (_) {}
    }
  }
  screenshots.sort((a, b) {
    final c = a.folder.compareTo(b.folder);
    return c != 0 ? c : a.name.compareTo(b.name);
  });
  return screenshots;
}

// --- Category builders ---

_Category _buildCategory(
  String name,
  String id,
  Map<String, List<_Test>> suites,
  String generateCmd,
  String environment,
) {
  // Compute duration as max test time (tests report wall-clock offsets)
  var maxTime = 0;
  for (final tests in suites.values) {
    for (final t in tests) {
      if (t.time > maxTime) maxTime = t.time;
    }
  }
  return _Category(
    name: name,
    id: id,
    suites: suites,
    generateCmd: generateCmd,
    durationMs: maxTime,
    environment: environment,
  );
}

_Category _buildPlaywrightCategory(
  _ParsedResults results,
  List<_Screenshot> screenshots,
  String environment,
) {
  return _Category(
    name: 'Web E2E — Playwright',
    id: 'playwright',
    suites: results.suites,
    generateCmd: 'npx playwright test',
    screenshots: screenshots,
    durationMs: results.durationMs,
    environment: environment,
  );
}

_Category _buildMaestroCategory(
  _ParsedResults results,
  List<_Screenshot> screenshots,
  String environment,
) {
  return _Category(
    name: 'Device E2E — Maestro',
    id: 'maestro',
    suites: results.suites,
    generateCmd: 'bash scripts/maestro-test.sh',
    screenshots: screenshots,
    durationMs: results.durationMs,
    environment: environment,
  );
}

// --- Coverage parser ---

List<_CovFile> _parseLcov(String path) {
  final file = File(path);
  if (!file.existsSync()) return [];

  final results = <_CovFile>[];
  String? currentFile;
  var hit = 0;
  var total = 0;

  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      currentFile = line
          .substring(3)
          .replaceAll(RegExp(r'^.*[/\\]lib[/\\]'), 'lib/');
    } else if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      if (parts.length >= 2) {
        total++;
        if (int.tryParse(parts[1]) case final count? when count > 0) {
          hit++;
        }
      }
    } else if (line == 'end_of_record') {
      if (currentFile != null && total > 0) {
        results.add(_CovFile(currentFile, hit, total));
      }
      currentFile = null;
      hit = 0;
      total = 0;
    }
  }
  return results;
}

// --- Screen/flow coverage parser ---

_E2eCoverage _parseScreenCoverage(String path) {
  final file = File(path);
  if (!file.existsSync()) return _E2eCoverage([], []);

  final lines = file.readAsLinesSync();
  final screens = <_E2eItem>[];
  final flows = <_E2eItem>[];
  List<_E2eItem>? currentList;
  Map<String, String?>? currentItem;

  void flushItem() {
    final item = currentItem;
    final list = currentList;
    if (item != null && list != null) {
      list.add(_E2eItem(
        id: item['id'] ?? '',
        name: item['name'] ?? '',
        path: item['path'],
        playwright: item['playwright'],
        maestro: item['maestro'],
      ));
    }
    currentItem = null;
  }

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

    if (trimmed == 'screens:') {
      flushItem();
      currentList = screens;
      continue;
    }
    if (trimmed == 'flows:') {
      flushItem();
      currentList = flows;
      continue;
    }

    if (trimmed.startsWith('- id:')) {
      flushItem();
      currentItem = {'id': trimmed.substring(5).trim()};
      continue;
    }

    if (currentItem != null && trimmed.contains(':')) {
      final colonIdx = trimmed.indexOf(':');
      final key = trimmed.substring(0, colonIdx).trim();
      final value = trimmed.substring(colonIdx + 1).trim();
      currentItem![key] = value == 'null' ? null : value;
    }
  }
  flushItem();

  return _E2eCoverage(screens, flows);
}

// --- Helpers ---

String _esc(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

String _pctColor(double pct) =>
    pct >= 80 ? '#2e7d32' : pct >= 50 ? '#f57f17' : '#c62828';

String _layerColor(String id) {
  switch (id) {
    case 'unit':
    case 'widget':
    case 'golden':
      return '#1565c0'; // blue — Flutter
    case 'playwright':
      return '#2e7d32'; // green — Web E2E
    case 'maestro':
      return '#e65100'; // orange — Device E2E
    default:
      return '#666';
  }
}

String _summaryCard(int value, String label, String cls) =>
    '<div class="card $cls"><div class="num">$value</div>'
    '<div class="label">$label</div></div>';

String _shortenPath(String path) =>
    path.replaceAll('\\', '/').replaceAll(RegExp(r'^.*[/\\]test[/\\]'), 'test/');

void _writeFlatSuites(StringBuffer buf, _Category c) {
  for (final suitePath in c.suiteKeys) {
    final suiteTests = c.suites[suitePath]!;
    final sp = suiteTests.where((t) => t.result == 'success').length;
    final sf = suiteTests.where((t) => t.result == 'failure').length;
    final shortPath = _shortenPath(suitePath);
    final hasFails = sf > 0;

    buf.writeln('<details class="suite"${hasFails ? ' open' : ''}>');
    buf.writeln(
      '<summary class="suite-header"><span>${_esc(shortPath)}</span>'
      '<span class="counts">$sp/${suiteTests.length} passed</span></summary>',
    );
    _writeTests(buf, suiteTests);
    buf.writeln('</details>');
  }
}

void _writeFolderGroupedSuites(StringBuffer buf, _Category c) {
  // Group suites by parent folder
  final folders = <String, List<String>>{};
  for (final suitePath in c.suiteKeys) {
    final shortPath = _shortenPath(suitePath);
    final parts = shortPath.split('/');
    // Folder is everything except filename: e.g. test/core/constants/
    final folder = parts.length > 1
        ? parts.sublist(0, parts.length - 1).join('/')
        : 'test';
    folders.putIfAbsent(folder, () => []).add(suitePath);
  }

  final folderKeys = folders.keys.toList()..sort();
  for (final folder in folderKeys) {
    final suitePaths = folders[folder]!;
    var folderTotal = 0;
    var folderPassed = 0;
    var folderFailed = 0;
    for (final sp in suitePaths) {
      final tests = c.suites[sp]!;
      folderTotal += tests.length;
      folderPassed += tests.where((t) => t.result == 'success').length;
      folderFailed += tests.where((t) => t.result == 'failure').length;
    }
    final hasFails = folderFailed > 0;

    buf.writeln('<details class="suite folder-group"${hasFails ? ' open' : ''}>');
    buf.writeln(
      '<summary class="suite-header folder-header"><span>${_esc(folder)}/</span>'
      '<span class="counts">$folderPassed/$folderTotal passed</span></summary>',
    );

    for (final suitePath in suitePaths) {
      final suiteTests = c.suites[suitePath]!;
      final sp = suiteTests.where((t) => t.result == 'success').length;
      final sf = suiteTests.where((t) => t.result == 'failure').length;
      final shortPath = _shortenPath(suitePath).split('/').last;
      final suiteHasFails = sf > 0;

      buf.writeln('<details class="suite nested-suite"${suiteHasFails ? ' open' : ''}>');
      buf.writeln(
        '<summary class="suite-header"><span>${_esc(shortPath)}</span>'
        '<span class="counts">$sp/${suiteTests.length} passed</span></summary>',
      );
      _writeTests(buf, suiteTests);
      buf.writeln('</details>');
    }
    buf.writeln('</details>');
  }
}

void _writeTests(StringBuffer buf, List<_Test> tests) {
  for (final t in tests) {
    final cls = t.result == 'success' ? 'pass' : 'fail';
    final icon = t.result == 'success' ? '&#10003;' : '&#10007;';
    final timeStr = t.time > 0 ? '${t.time}ms' : '';
    buf.writeln(
      '<div class="test $cls"><span class="icon">$icon</span>'
      '<span class="name">${_esc(t.name)}</span>'
      '<span class="time">$timeStr</span></div>',
    );
    if (t.error != null && t.error!.isNotEmpty) {
      buf.writeln('<div class="error">${_esc(t.error!)}</div>');
    }
  }
}

void _writeE2eCoverage(StringBuffer buf, _E2eCoverage cov) {
  final covScreens = cov.screens.where((s) => s.hasCoverage).length;
  final covFlows = cov.flows.where((f) => f.hasCoverage).length;
  final screenPct = cov.screens.isNotEmpty
      ? covScreens / cov.screens.length * 100
      : 0.0;
  final flowPct = cov.flows.isNotEmpty
      ? covFlows / cov.flows.length * 100
      : 0.0;

  buf.writeln('<h2 id="e2e-coverage">E2E Screen/Flow Coverage</h2>');
  buf.writeln('<div class="summary">');
  buf.writeln(
    '<div class="card"><div class="num" style="color:${_pctColor(screenPct)}">'
    '${screenPct.toStringAsFixed(0)}%</div>'
    '<div class="label">Screens ($covScreens/${cov.screens.length})</div></div>',
  );
  buf.writeln(
    '<div class="card"><div class="num" style="color:${_pctColor(flowPct)}">'
    '${flowPct.toStringAsFixed(0)}%</div>'
    '<div class="label">Flows ($covFlows/${cov.flows.length})</div></div>',
  );
  buf.writeln('</div>');

  void writeTable(String title, List<_E2eItem> items) {
    if (items.isEmpty) return;
    buf.writeln('<details class="suite" open>');
    buf.writeln(
      '<summary class="suite-header"><span>$title</span>'
      '<span class="counts">${items.where((i) => i.hasCoverage).length}/${items.length} covered</span></summary>',
    );
    buf.writeln('<table class="e2e-table">');
    buf.writeln(
      '<tr><th style="text-align:left">Name</th>'
      '<th>Playwright</th><th>Maestro</th></tr>',
    );
    for (final item in items) {
      final pw = item.hasPlaywright
          ? '<td class="check">&#10003;</td>'
          : '<td class="miss">&#10007;</td>';
      final ma = item.hasMaestro
          ? '<td class="check">&#10003;</td>'
          : '<td class="miss">&#10007;</td>';
      final rowCls = item.hasCoverage ? '' : ' class="uncovered-row"';
      buf.writeln('<tr$rowCls><td>${_esc(item.name)}</td>$pw$ma</tr>');
    }
    buf.writeln('</table></details>');
  }

  writeTable('Screens', cov.screens);
  writeTable('Flows', cov.flows);
}

String _formatDuration(int ms) {
  final sec = ms ~/ 1000;
  if (sec < 60) return '${sec}s';
  return '${sec ~/ 60}m ${sec % 60}s';
}

String _readEnvLabel(String path) {
  if (path.isEmpty) return '';
  final file = File(path);
  if (!file.existsSync()) return '';
  try {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final parts = <String>[];
    // Flutter: platform + flutter version
    if (json.containsKey('flutter')) {
      parts.add('Flutter ${json['flutter']}');
      if (json.containsKey('dart')) parts.add('Dart ${json['dart']}');
    }
    // Playwright: browser
    if (json.containsKey('browser')) {
      parts.add(json['browser'] as String);
    }
    // Maestro: device + SDK
    if (json.containsKey('device')) {
      final device = json['device'] as String;
      final sdk = json['sdk'] as String? ?? '';
      parts.add(device);
      if (sdk.isNotEmpty && sdk != 'unknown') parts.add('API $sdk');
    }
    // Platform
    if (json.containsKey('platform') && !json.containsKey('flutter')) {
      final p = json['platform'] as String;
      if (p != 'android') {
        parts.add(p.startsWith('MINGW') || p.startsWith('MSYS') ? 'Windows' : p);
      }
    }
    return parts.join(' · ');
  } catch (_) {
    return '';
  }
}

const _css = '''
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f5f5f5; color: #333; padding: 24px; }
  h1 { font-size: 24px; margin-bottom: 8px; }
  h2 { font-size: 20px; margin: 32px 0 16px; padding-top: 8px; border-top: 2px solid #e0e0e0; }
  h3 { font-size: 16px; color: #555; }
  .summary { display: flex; gap: 16px; margin-bottom: 24px; flex-wrap: wrap; }
  .card { background: white; border-radius: 8px; padding: 16px 24px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); min-width: 120px; }
  .card .num { font-size: 32px; font-weight: bold; }
  .card .label { font-size: 14px; color: #666; }
  .card .label-sub { font-size: 12px; color: #999; }
  .card.pass .num { color: #2e7d32; }
  .card.fail .num { color: #c62828; }
  .card.skip .num { color: #f57f17; }
  .card.total .num { color: #1565c0; }
  .card.muted .num { color: #bbb; }
  .cat-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 12px; margin-bottom: 24px; }
  .cat-box { background: white; border-radius: 8px; padding: 14px 16px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); cursor: pointer; transition: transform 0.1s; display: flex; flex-direction: column; gap: 8px; }
  .cat-box:hover { transform: translateY(-2px); box-shadow: 0 3px 8px rgba(0,0,0,0.15); }
  .cat-box-top { display: flex; align-items: baseline; gap: 10px; }
  .cat-box-num { font-size: 24px; font-weight: bold; }
  .cat-box-name { font-size: 13px; color: #555; }
  .cat-box.pass .cat-box-num { color: #2e7d32; }
  .cat-box.fail .cat-box-num { color: #c62828; }
  .cat-box.muted .cat-box-num { color: #bbb; }
  .cat-box-dur { display: flex; align-items: center; gap: 8px; }
  .dur-bar { flex: 1; height: 6px; background: #e8e8e8; border-radius: 3px; overflow: hidden; }
  .dur-fill { height: 100%; border-radius: 3px; }
  .dur-label { font-size: 12px; font-weight: 600; color: #666; white-space: nowrap; }
  .cat-env { font-size: 11px; color: #999; }
  .cat-card { cursor: pointer; transition: transform 0.1s; }
  .cat-card:hover { transform: translateY(-2px); box-shadow: 0 3px 8px rgba(0,0,0,0.15); }
  .no-data { background: white; border-radius: 8px; padding: 24px; color: #999; box-shadow: 0 1px 3px rgba(0,0,0,0.1); margin-bottom: 16px; }
  .no-data code { background: #f0f0f0; padding: 2px 8px; border-radius: 4px; font-size: 13px; color: #555; }
  .coverage-bar { background: #e0e0e0; border-radius: 4px; height: 8px; flex: 1; }
  .coverage-bar .fill { height: 100%; border-radius: 4px; }
  .cov-row { display: flex; align-items: center; gap: 12px; padding: 8px 16px; border-bottom: 1px solid #f0f0f0; font-size: 13px; }
  .cov-row:last-child { border-bottom: none; }
  .cov-row .file { flex: 2; font-family: monospace; font-size: 12px; }
  .cov-row .pct { width: 50px; text-align: right; font-weight: 600; font-size: 13px; }
  .cov-row .ratio { width: 80px; text-align: right; color: #999; font-size: 12px; }
  .suite { background: white; border-radius: 8px; margin-bottom: 16px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); overflow: hidden; }
  .suite-header { padding: 12px 16px; background: #fafafa; border-bottom: 1px solid #eee; font-weight: 600; font-size: 13px; color: #555; cursor: pointer; display: flex; justify-content: space-between; }
  .suite-header:hover { background: #f0f0f0; }
  .suite-header .counts { font-weight: normal; }
  .test { padding: 8px 16px; border-bottom: 1px solid #f0f0f0; display: flex; align-items: center; gap: 8px; font-size: 14px; }
  .test:last-child { border-bottom: none; }
  .test .icon { width: 20px; text-align: center; flex-shrink: 0; }
  .test .name { flex: 1; }
  .test .time { color: #999; font-size: 12px; flex-shrink: 0; }
  .test.pass .icon { color: #2e7d32; }
  .test.fail .icon { color: #c62828; }
  .test.fail { background: #fff5f5; }
  .error { padding: 8px 16px 12px 44px; background: #fff5f5; font-size: 12px; font-family: monospace; white-space: pre-wrap; color: #c62828; border-bottom: 1px solid #f0f0f0; }
  .timestamp { font-size: 12px; color: #999; margin-bottom: 24px; }
  .screenshot-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 12px; padding: 16px; }
  .screenshot { text-align: center; }
  .screenshot img { width: 100%; border-radius: 4px; border: 1px solid #e0e0e0; cursor: pointer; }
  .screenshot img:hover { box-shadow: 0 2px 8px rgba(0,0,0,0.2); }
  .screenshot-label { font-size: 11px; color: #777; margin-top: 4px; word-break: break-all; }
  .cat-section { margin-bottom: 8px; }
  .cat-section > summary { list-style: none; cursor: pointer; }
  .cat-section > summary::-webkit-details-marker { display: none; }
  .cat-section > summary h2 { display: inline; }
  .cat-section > summary::before { content: "\\25B6"; font-size: 12px; margin-right: 8px; color: #999; }
  .cat-section[open] > summary::before { content: "\\25BC"; }
  .cat-section-header { display: inline; }
  .screenshot-folder-label { font-size: 13px; font-weight: 600; color: #555; padding: 8px 16px 4px; }
  .env-badge { font-size: 12px; font-weight: normal; color: #666; background: #e8eaf6; padding: 2px 10px; border-radius: 12px; vertical-align: middle; }
  .folder-header { background: #e8eaf6; }
  .folder-header:hover { background: #dde0f0; }
  .nested-suite { margin: 0 0 0 16px; border-radius: 0; box-shadow: none; border-left: 3px solid #c5cae9; }
  .nested-suite .suite-header { background: #fafafa; }
  .e2e-table { width: 100%; border-collapse: collapse; }
  .e2e-table th { padding: 8px 16px; font-size: 13px; color: #555; border-bottom: 2px solid #eee; }
  .e2e-table td { padding: 6px 16px; border-bottom: 1px solid #f0f0f0; font-size: 14px; }
  .e2e-table .check { color: #2e7d32; text-align: center; font-size: 16px; }
  .e2e-table .miss { color: #ccc; text-align: center; font-size: 16px; }
  .e2e-table .uncovered-row { background: #fff5f5; }
  .e2e-table .uncovered-row .miss { color: #c62828; }
  .zero-cov-callout { background: #fff3e0; border: 1px solid #ffb74d; border-radius: 8px; padding: 16px; margin-bottom: 16px; }
  .zero-cov-callout strong { color: #e65100; }
  .zero-cov-callout ul { margin: 8px 0 0 20px; font-size: 13px; }
  .zero-cov-callout li { margin-bottom: 4px; }
  .zero-cov-callout code { background: #fff8e1; padding: 1px 6px; border-radius: 3px; font-size: 12px; }
  details > summary { list-style: none; }
  details > summary::-webkit-details-marker { display: none; }
''';

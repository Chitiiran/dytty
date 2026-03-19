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

  if (runDir != null) {
    inputPath = filteredArgs.isNotEmpty ? filteredArgs[0] : '$runDir/flutter/results.json';
    outputPath = filteredArgs.length > 1 ? filteredArgs[1] : '$runDir/report.html';
    covPath = '$runDir/flutter/lcov.info';
    playwrightPath = '$runDir/playwright/results.json';
    maestroDir = '$runDir/device-e2e/maestro';
    playwrightScreenshotDir = '$runDir/playwright/screenshots';
  } else {
    inputPath = filteredArgs.isNotEmpty ? filteredArgs[0] : 'test-results.json';
    outputPath = filteredArgs.length > 1 ? filteredArgs[1] : 'test-report.html';
    covPath = 'coverage/lcov.info';
    playwrightPath = 'playwright-results.json';
    maestroDir = '.maestro/screenshots/latest';
    playwrightScreenshotDir = 'test-results';
  }

  // --- Parse all data sources ---
  final flutterSuites = _parseFlutterResults(inputPath);
  final covFiles = _parseLcov(covPath);
  final playwrightSuites = _parsePlaywrightResults(playwrightPath);
  final maestroResult = _parseMaestroResults(maestroDir);
  final maestroScreenshots =
      noScreenshots ? <_Screenshot>[] : _collectScreenshots(maestroDir);
  final playwrightScreenshots =
      noScreenshots ? <_Screenshot>[] : _collectScreenshots(playwrightScreenshotDir);

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

  // --- Build category stats ---
  final categories = <_Category>[
    _buildCategory('Unit Tests', 'unit', unitSuites,
        'flutter test --machine > test-results.json'),
    _buildCategory('Widget Tests', 'widget', widgetSuites,
        'flutter test test/widgets/ --machine > test-results.json'),
    _buildCategory('Golden Tests', 'golden', goldenSuites,
        'flutter test test/goldens/ --machine > test-results.json'),
    _buildPlaywrightCategory(playwrightSuites, playwrightScreenshots),
    _buildMaestroCategory(maestroResult, maestroScreenshots),
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
      '<div class="label">Coverage</div></div>',
    );
  }
  buf.writeln('</div>');

  // Category summary cards (clickable)
  buf.writeln('<div class="summary">');
  for (final c in categories) {
    final cls = c.failed > 0
        ? 'fail'
        : c.total == 0
            ? 'muted'
            : 'pass';
    buf.writeln(
      '<a href="#${c.id}" class="card cat-card $cls" style="text-decoration:none;color:inherit">'
      '<div class="num">${c.total > 0 ? '${c.passed}/${c.total}' : '--'}</div>'
      '<div class="label">${_esc(c.name)}</div></a>',
    );
  }
  buf.writeln('</div>');

  // Category sections
  for (final c in categories) {
    buf.writeln('<h2 id="${c.id}">${_esc(c.name)}</h2>');

    if (c.total == 0 && c.screenshots.isEmpty) {
      buf.writeln(
        '<div class="no-data">No data available. Run: <code>${_esc(c.generateCmd)}</code></div>',
      );
      continue;
    }

    // Test suites
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

      for (final t in suiteTests) {
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
      buf.writeln('</details>');
    }

    // Screenshots for Maestro
    if (c.screenshots.isNotEmpty) {
      final grouped = <String, List<_Screenshot>>{};
      for (final s in c.screenshots) {
        grouped.putIfAbsent(s.folder, () => []).add(s);
      }
      final folders = grouped.keys.toList()..sort();

      buf.writeln('<h3 style="margin-top:16px">Screenshots</h3>');
      for (final folder in folders) {
        buf.writeln('<details class="suite" open>');
        buf.writeln(
          '<summary class="suite-header"><span>$folder/</span>'
          '<span class="counts">${grouped[folder]!.length} screenshots</span></summary>',
        );
        buf.writeln('<div class="screenshot-grid">');
        for (final s in grouped[folder]!) {
          buf.writeln(
            '<div class="screenshot"><img src="data:image/png;base64,${s.base64}" '
            'alt="${_esc(s.name)}" loading="lazy">'
            '<div class="screenshot-label">${_esc(s.name)}</div></div>',
          );
        }
        buf.writeln('</div></details>');
      }
    }
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

    covFiles.sort((a, b) => a.pct.compareTo(b.pct));
    buf.writeln('<details class="suite" open>');
    buf.writeln(
      '<summary class="suite-header"><span>Coverage by file</span>'
      '<span class="counts">${covFiles.length} files</span></summary>',
    );
    for (final f in covFiles) {
      final pctStr = f.pct.toStringAsFixed(0);
      final barColor = _pctColor(f.pct);
      buf.writeln('<div class="cov-row">');
      buf.writeln('<span class="file">${_esc(f.path)}</span>');
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
  });

  final String name;
  final String id;
  final Map<String, List<_Test>> suites;
  final String generateCmd;
  final List<_Screenshot> screenshots;

  late final suiteKeys = suites.keys.toList()..sort();
  late final total = suites.values.fold<int>(0, (s, v) => s + v.length);
  late final passed = suites.values
      .fold<int>(0, (s, v) => s + v.where((t) => t.result == 'success').length);
  late final failed = suites.values
      .fold<int>(0, (s, v) => s + v.where((t) => t.result == 'failure').length);
  late final skipped =
      suites.values.fold<int>(0, (s, v) => s + v.where((t) => t.skipped).length);
}

// --- Flutter test JSON parser ---

Map<String, List<_Test>> _parseFlutterResults(String path) {
  final file = File(path);
  if (!file.existsSync()) return {};

  final lines = file.readAsLinesSync().where((l) => l.trim().isNotEmpty);
  final events = <Map<String, dynamic>>[];
  for (final line in lines) {
    try {
      events.add(jsonDecode(line) as Map<String, dynamic>);
    } catch (_) {}
  }

  final tests = <int, _Test>{};
  final suiteNames = <int, String>{};

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
    }
  }

  final visible =
      tests.values.where((t) => !t.hidden && t.result != null).toList();

  final grouped = <String, List<_Test>>{};
  for (final t in visible) {
    final suite = suiteNames[t.suiteId] ?? 'unknown';
    grouped.putIfAbsent(suite, () => []).add(t);
  }
  return grouped;
}

// --- Playwright JSON parser ---

Map<String, List<_Test>> _parsePlaywrightResults(String path) {
  final file = File(path);
  if (!file.existsSync()) return {};

  try {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final suites = json['suites'] as List<dynamic>? ?? [];
    final result = <String, List<_Test>>{};

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
    return result;
  } catch (e) {
    stderr.writeln('Warning: Could not parse playwright-results.json: $e');
    return {};
  }
}

// --- Maestro JUnit XML parser ---

Map<String, List<_Test>> _parseMaestroResults(String dirPath) {
  final xmlFile = File('$dirPath/results.xml');
  if (!xmlFile.existsSync()) return {};

  try {
    final content = xmlFile.readAsStringSync();
    final result = <String, List<_Test>>{};

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
    return result;
  } catch (e) {
    stderr.writeln('Warning: Could not parse Maestro results.xml: $e');
    return {};
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
) {
  return _Category(
    name: name,
    id: id,
    suites: suites,
    generateCmd: generateCmd,
  );
}

_Category _buildPlaywrightCategory(
  Map<String, List<_Test>> suites,
  List<_Screenshot> screenshots,
) {
  return _Category(
    name: 'Web E2E — Playwright',
    id: 'playwright',
    suites: suites,
    generateCmd: 'npx playwright test',
    screenshots: screenshots,
  );
}

_Category _buildMaestroCategory(
  Map<String, List<_Test>> suites,
  List<_Screenshot> screenshots,
) {
  return _Category(
    name: 'Device E2E — Maestro',
    id: 'maestro',
    suites: suites,
    generateCmd: 'bash scripts/maestro-test.sh',
    screenshots: screenshots,
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

// --- Helpers ---

String _esc(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

String _pctColor(double pct) =>
    pct >= 80 ? '#2e7d32' : pct >= 50 ? '#f57f17' : '#c62828';

String _summaryCard(int value, String label, String cls) =>
    '<div class="card $cls"><div class="num">$value</div>'
    '<div class="label">$label</div></div>';

String _shortenPath(String path) =>
    path.replaceAll('\\', '/').replaceAll(RegExp(r'^.*[/\\]test[/\\]'), 'test/');

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
  .card.pass .num { color: #2e7d32; }
  .card.fail .num { color: #c62828; }
  .card.skip .num { color: #f57f17; }
  .card.total .num { color: #1565c0; }
  .card.muted .num { color: #bbb; }
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
  details > summary { list-style: none; }
  details > summary::-webkit-details-marker { display: none; }
''';

// Converts flutter test --machine JSON output to an HTML report.
// Usage: dart run tool/test_report.dart [input] [output]
//   input  defaults to test-results.json
//   output defaults to test-report.html

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final inputPath = args.isNotEmpty ? args[0] : 'test-results.json';
  final outputPath = args.length > 1 ? args[1] : 'test-report.html';

  final file = File(inputPath);
  if (!file.existsSync()) {
    stderr.writeln('Input file not found: $inputPath');
    exit(1);
  }

  final lines = file.readAsLinesSync().where((l) => l.trim().isNotEmpty);
  final events = <Map<String, dynamic>>[];
  for (final line in lines) {
    try {
      events.add(jsonDecode(line) as Map<String, dynamic>);
    } catch (_) {
      // skip non-JSON lines
    }
  }

  // Build test info from events
  final tests = <int, _Test>{};
  final suites = <int, String>{};

  for (final e in events) {
    final type = e['type'] as String?;
    if (type == 'suite') {
      final suite = e['suite'] as Map<String, dynamic>;
      suites[suite['id'] as int] = suite['path'] as String? ?? '';
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

  // Filter out hidden/loading tests
  final visible = tests.values
      .where((t) => !t.hidden && t.result != null)
      .toList();

  final passed = visible.where((t) => t.result == 'success').length;
  final failed = visible.where((t) => t.result == 'failure').length;
  final skipped = visible.where((t) => t.skipped).length;
  final total = visible.length;

  // Group by suite
  final grouped = <String, List<_Test>>{};
  for (final t in visible) {
    final suite = suites[t.suiteId] ?? 'unknown';
    grouped.putIfAbsent(suite, () => []).add(t);
  }

  final sortedSuites = grouped.keys.toList()..sort();

  // Generate HTML
  final buf = StringBuffer();
  buf.writeln('<!DOCTYPE html>');
  buf.writeln('<html lang="en"><head>');
  buf.writeln('<meta charset="UTF-8">');
  buf.writeln(
    '<meta name="viewport" content="width=device-width, initial-scale=1.0">',
  );
  buf.writeln('<title>Dytty Test Report</title>');
  buf.writeln('<style>');
  buf.writeln('''
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f5f5f5; color: #333; padding: 24px; }
    h1 { font-size: 24px; margin-bottom: 16px; }
    .summary { display: flex; gap: 16px; margin-bottom: 24px; flex-wrap: wrap; }
    .card { background: white; border-radius: 8px; padding: 16px 24px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); min-width: 120px; }
    .card .num { font-size: 32px; font-weight: bold; }
    .card .label { font-size: 14px; color: #666; }
    .card.pass .num { color: #2e7d32; }
    .card.fail .num { color: #c62828; }
    .card.skip .num { color: #f57f17; }
    .card.total .num { color: #1565c0; }
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
    details > summary { list-style: none; }
    details > summary::-webkit-details-marker { display: none; }
  ''');
  buf.writeln('</style></head><body>');
  buf.writeln('<h1>Dytty Test Report</h1>');
  buf.writeln(
    '<p class="timestamp">Generated: ${DateTime.now().toIso8601String()}</p>',
  );

  // Summary cards
  buf.writeln('<div class="summary">');
  buf.writeln(
    '<div class="card total"><div class="num">$total</div><div class="label">Total</div></div>',
  );
  buf.writeln(
    '<div class="card pass"><div class="num">$passed</div><div class="label">Passed</div></div>',
  );
  buf.writeln(
    '<div class="card fail"><div class="num">$failed</div><div class="label">Failed</div></div>',
  );
  buf.writeln(
    '<div class="card skip"><div class="num">$skipped</div><div class="label">Skipped</div></div>',
  );
  buf.writeln('</div>');

  // Suites
  for (final suitePath in sortedSuites) {
    final suiteTests = grouped[suitePath]!;
    final suitePassed = suiteTests.where((t) => t.result == 'success').length;
    final suiteFailed = suiteTests.where((t) => t.result == 'failure').length;
    final shortPath = suitePath.replaceAll(
      RegExp(r'^.*[/\\]test[/\\]'),
      'test/',
    );
    final hasFails = suiteFailed > 0;

    buf.writeln('<details class="suite"${hasFails ? ' open' : ''}>');
    buf.writeln(
      '<summary class="suite-header"><span>$shortPath</span><span class="counts">$suitePassed/${suiteTests.length} passed</span></summary>',
    );

    for (final t in suiteTests) {
      final cls = t.result == 'success' ? 'pass' : 'fail';
      final icon = t.result == 'success' ? '&#10003;' : '&#10007;';
      final timeMs = t.time;
      final timeStr = timeMs > 0 ? '${timeMs}ms' : '';
      // Strip suite prefix from test name for readability
      final name = _escapeHtml(t.name);
      buf.writeln(
        '<div class="test $cls"><span class="icon">$icon</span><span class="name">$name</span><span class="time">$timeStr</span></div>',
      );
      if (t.error != null && t.error!.isNotEmpty) {
        buf.writeln('<div class="error">${_escapeHtml(t.error!)}</div>');
      }
    }

    buf.writeln('</details>');
  }

  buf.writeln('</body></html>');

  File(outputPath).writeAsStringSync(buf.toString());
  print('Test report: $outputPath ($passed/$total passed, $failed failed)');
}

String _escapeHtml(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

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

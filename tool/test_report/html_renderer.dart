/// HTML report renderer — generates the unified test dashboard.

import 'models.dart';

String renderReport({
  required List<TestLayer> layers,
  required List<CovFile> covFiles,
  required E2eCoverage e2eCoverage,
}) {
  // Overall stats
  var totalTests = 0, totalPassed = 0, totalFailed = 0, totalSkipped = 0;
  for (final c in layers) {
    totalTests += c.total;
    totalPassed += c.passed;
    totalFailed += c.failed;
    totalSkipped += c.skipped;
  }
  final overallPct = totalTests > 0 ? (totalPassed / totalTests * 100) : 0.0;

  var covLineHit = 0, covLineTotal = 0;
  var covFnHit = 0, covFnTotal = 0;
  var covBrHit = 0, covBrTotal = 0;
  for (final f in covFiles) {
    covLineHit += f.lineHit;
    covLineTotal += f.lineTotal;
    covFnHit += f.fnHit;
    covFnTotal += f.fnTotal;
    covBrHit += f.brHit;
    covBrTotal += f.brTotal;
  }
  final linePct = covLineTotal > 0 ? (covLineHit / covLineTotal * 100) : 0.0;
  final fnPct = covFnTotal > 0 ? (covFnHit / covFnTotal * 100) : 0.0;
  final brPct = covBrTotal > 0 ? (covBrHit / covBrTotal * 100) : 0.0;

  final buf = StringBuffer();
  buf.writeln('<!DOCTYPE html>');
  buf.writeln('<html lang="en"><head>');
  buf.writeln('<meta charset="UTF-8">');
  buf.writeln(
    '<meta name="viewport" content="width=device-width, initial-scale=1.0">',
  );
  buf.writeln('<title>Dytty Test Report</title>');
  buf.writeln('<style>');
  buf.writeln(css);
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
  if (covLineTotal > 0) {
    final cc = _pctColor(linePct);
    buf.writeln(
      '<div class="card"><div class="num" style="color:$cc">'
      '${linePct.toStringAsFixed(1)}%</div>'
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
  final totalDurationMs = layers.fold<int>(0, (s, c) => s + c.durationMs);
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

  // Layer summary cards (boxed with timing bars) — includes Coverage as 6th card
  final maxDur = layers.fold<int>(0, (m, c) => c.durationMs > m ? c.durationMs : m);
  buf.writeln('<div class="cat-grid">');
  for (final c in layers) {
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
  // Coverage as 6th clickable card
  if (covLineTotal > 0) {
    final covColor = _pctColor(linePct);
    final covCls = linePct >= 80 ? 'pass' : linePct >= 50 ? '' : 'fail';
    buf.writeln(
      '<a href="#coverage" class="cat-box $covCls" style="border-left:4px solid #7b1fa2;text-decoration:none;color:inherit">'
      '<div class="cat-box-top">'
      '<div class="cat-box-num" style="color:$covColor">${linePct.toStringAsFixed(0)}%</div>'
      '<div class="cat-box-name">Coverage</div>'
      '</div>',
    );
    final subParts = <String>[];
    if (covFnTotal > 0) subParts.add('Fn: ${fnPct.toStringAsFixed(0)}%');
    if (covBrTotal > 0) subParts.add('Br: ${brPct.toStringAsFixed(0)}%');
    if (subParts.isNotEmpty) {
      buf.writeln('<div class="cat-env">${subParts.join(' · ')}</div>');
    }
    buf.writeln('</a>');
  }
  buf.writeln('</div>');

  // Layer sections (collapsible)
  for (final c in layers) {
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

    buf.writeln('<details class="cat-section"${hasFails ? ' open' : ''}>');
    buf.writeln(
      '<summary><h2 id="${c.id}" class="cat-section-header">'
      '${_esc(c.name)}$secDur$secEnv</h2></summary>',
    );

    final isFlutter = const ['unit', 'widget', 'golden'].contains(c.id);
    if (isFlutter && c.suiteKeys.length > 1) {
      _writeFolderGroupedSuites(buf, c);
    } else {
      _writeFlatSuites(buf, c);
    }

    if (c.screenshots.isNotEmpty) {
      final grouped = <String, List<Screenshot>>{};
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

  // Coverage by file (with function + branch breakdown)
  if (covFiles.isNotEmpty) {
    final covColor = _pctColor(linePct);
    buf.writeln('<h2 id="coverage">Coverage: ${linePct.toStringAsFixed(1)}%</h2>');
    buf.writeln('<div class="summary">');
    buf.writeln(
      '<div class="card" style="flex:1;max-width:300px">'
      '<div class="num" style="color:$covColor">${linePct.toStringAsFixed(1)}%</div>'
      '<div class="label">Lines — $covLineHit / $covLineTotal</div></div>',
    );
    if (covFnTotal > 0) {
      final fColor = _pctColor(fnPct);
      buf.writeln(
        '<div class="card" style="flex:1;max-width:300px">'
        '<div class="num" style="color:$fColor">${fnPct.toStringAsFixed(1)}%</div>'
        '<div class="label">Functions — $covFnHit / $covFnTotal</div></div>',
      );
    }
    if (covBrTotal > 0) {
      final bColor = _pctColor(brPct);
      buf.writeln(
        '<div class="card" style="flex:1;max-width:300px">'
        '<div class="num" style="color:$bColor">${brPct.toStringAsFixed(1)}%</div>'
        '<div class="label">Branches — $covBrHit / $covBrTotal</div></div>',
      );
    }
    buf.writeln('</div>');

    // Zero-coverage callout
    final zeroCov = covFiles.where((f) => f.linePct == 0).toList();
    if (zeroCov.isNotEmpty) {
      buf.writeln('<div class="zero-cov-callout">');
      buf.writeln('<strong>0% coverage (${zeroCov.length} files)</strong>');
      buf.writeln('<ul>');
      for (final f in zeroCov) {
        final name = f.path.split('/').last;
        buf.writeln('<li><code>${_esc(name)}</code> — ${f.lineTotal} lines</li>');
      }
      buf.writeln('</ul></div>');
    }

    // Group coverage by folder
    final sortedCov = List<CovFile>.from(covFiles)
      ..sort((a, b) => a.linePct.compareTo(b.linePct));
    final covFolders = <String, List<CovFile>>{};
    for (final f in sortedCov) {
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
        fHit += f.lineHit;
        fTotal += f.lineTotal;
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
        final pctStr = f.linePct.toStringAsFixed(0);
        final barColor = _pctColor(f.linePct);
        buf.writeln('<div class="cov-row">');
        buf.writeln('<span class="file">${_esc(f.path.split('/').last)}</span>');
        buf.writeln(
          '<div class="coverage-bar"><div class="fill" '
          'style="width:${f.linePct.clamp(0, 100)}%;background:$barColor"></div></div>',
        );
        buf.writeln('<span class="pct" style="color:$barColor">$pctStr%</span>');
        buf.writeln('<span class="ratio">${f.lineHit}/${f.lineTotal}</span>');
        buf.writeln('</div>');
      }
      buf.writeln('</details>');
    }
  }

  buf.writeln('</body></html>');
  return buf.toString();
}

// --- Layer builders ---

TestLayer buildFlutterLayer(
  String name,
  String id,
  Map<String, List<Test>> suites,
  String generateCmd,
  String environment,
) {
  var maxTime = 0;
  for (final tests in suites.values) {
    for (final t in tests) {
      if (t.time > maxTime) maxTime = t.time;
    }
  }
  return TestLayer(
    name: name,
    id: id,
    suites: suites,
    generateCmd: generateCmd,
    durationMs: maxTime,
    environment: environment,
  );
}

TestLayer buildPlaywrightLayer(
  TestLayerResults results,
  List<Screenshot> screenshots,
  String environment,
) {
  return TestLayer(
    name: 'Web E2E — Playwright',
    id: 'playwright',
    suites: results.suites,
    generateCmd: 'npx playwright test',
    screenshots: screenshots,
    durationMs: results.durationMs,
    environment: environment,
  );
}

TestLayer buildMaestroLayer(
  TestLayerResults results,
  List<Screenshot> screenshots,
  String environment,
) {
  return TestLayer(
    name: 'Device E2E — Maestro',
    id: 'maestro',
    suites: results.suites,
    generateCmd: 'bash scripts/maestro-test.sh',
    screenshots: screenshots,
    durationMs: results.durationMs,
    environment: environment,
  );
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

String _formatDuration(int ms) {
  final sec = ms ~/ 1000;
  if (sec < 60) return '${sec}s';
  return '${sec ~/ 60}m ${sec % 60}s';
}

void _writeFlatSuites(StringBuffer buf, TestLayer c) {
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

void _writeFolderGroupedSuites(StringBuffer buf, TestLayer c) {
  final folders = <String, List<String>>{};
  for (final suitePath in c.suiteKeys) {
    final shortPath = _shortenPath(suitePath);
    final parts = shortPath.split('/');
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

void _writeTests(StringBuffer buf, List<Test> tests) {
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

void _writeE2eCoverage(StringBuffer buf, E2eCoverage cov) {
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

  void writeTable(String title, List<E2eItem> items) {
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

// --- CSS ---

const css = '''
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

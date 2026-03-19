/// Parsers for all test data sources: Flutter JSON, Playwright JSON,
/// Maestro JUnit XML, LCOV coverage, and screen-coverage YAML.

import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

import 'models.dart';

// --- Flutter test JSON parser ---

TestLayerResults parseFlutterResults(String path) {
  final file = File(path);
  if (!file.existsSync()) return TestLayerResults({}, 0);

  final lines = file.readAsLinesSync().where((l) => l.trim().isNotEmpty);
  final events = <Map<String, dynamic>>[];
  for (final line in lines) {
    try {
      events.add(jsonDecode(line) as Map<String, dynamic>);
    } catch (_) {}
  }

  final tests = <int, Test>{};
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
      tests[id] = Test(
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

  final grouped = <String, List<Test>>{};
  for (final t in visible) {
    final suite = suiteNames[t.suiteId] ?? 'unknown';
    grouped.putIfAbsent(suite, () => []).add(t);
  }
  return TestLayerResults(grouped, durationMs);
}

// --- Playwright JSON parser ---

TestLayerResults parsePlaywrightResults(String path) {
  final file = File(path);
  if (!file.existsSync()) return TestLayerResults({}, 0);

  try {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final suites = json['suites'] as List<dynamic>? ?? [];
    final result = <String, List<Test>>{};

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

          final t = Test(name: specTitle, suiteId: 0);
          if (status == 'expected') {
            t.result = 'success';
          } else if (status == 'skipped') {
            t.result = 'success';
            t.skipped = true;
          } else {
            t.result = 'failure';
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
    return TestLayerResults(result, durationMs);
  } catch (e) {
    stderr.writeln('Warning: Could not parse playwright-results.json: $e');
    return TestLayerResults({}, 0);
  }
}

// --- Maestro JUnit XML parser ---

TestLayerResults parseMaestroResults(String dirPath) {
  final xmlFile = File('$dirPath/results.xml');
  if (!xmlFile.existsSync()) return TestLayerResults({}, 0);

  try {
    final content = xmlFile.readAsStringSync();
    final result = <String, List<Test>>{};

    var durationMs = 0;
    final suiteTimeMatches =
        RegExp(r'<testsuite\s+[^>]*time="([^"]*)"').allMatches(content);
    for (final m in suiteTimeMatches) {
      durationMs +=
          ((double.tryParse(m.group(1)!) ?? 0) * 1000).round();
    }

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

      final t = Test(name: name, suiteId: 0);
      t.time = timeMs;

      if (body.contains('<failure') || body.contains('<error')) {
        t.result = 'failure';
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

    if (durationMs == 0) {
      for (final tests in result.values) {
        for (final t in tests) {
          durationMs += t.time;
        }
      }
    }

    return TestLayerResults(result, durationMs);
  } catch (e) {
    stderr.writeln('Warning: Could not parse Maestro results.xml: $e');
    return TestLayerResults({}, 0);
  }
}

// --- Coverage parser (line + function + branch) ---

List<CovFile> parseLcov(String path) {
  final file = File(path);
  if (!file.existsSync()) return [];

  final results = <CovFile>[];
  String? currentFile;
  var lineHit = 0, lineTotal = 0;
  var fnHit = 0, fnTotal = 0;
  var brHit = 0, brTotal = 0;

  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      currentFile = line
          .substring(3)
          .replaceAll(RegExp(r'^.*[/\\]lib[/\\]'), 'lib/');
    } else if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      if (parts.length >= 2) {
        lineTotal++;
        if (int.tryParse(parts[1]) case final count? when count > 0) {
          lineHit++;
        }
      }
    } else if (line.startsWith('FN:')) {
      fnTotal++;
    } else if (line.startsWith('FNDA:')) {
      final parts = line.substring(5).split(',');
      if (parts.isNotEmpty) {
        if (int.tryParse(parts[0]) case final count? when count > 0) {
          fnHit++;
        }
      }
    } else if (line.startsWith('BRDA:')) {
      final parts = line.substring(5).split(',');
      if (parts.length >= 4) {
        brTotal++;
        if (parts[3] != '-' && parts[3] != '0') {
          brHit++;
        }
      }
    } else if (line == 'end_of_record') {
      if (currentFile != null && (lineTotal > 0 || fnTotal > 0)) {
        results.add(CovFile(currentFile,
            lineHit: lineHit, lineTotal: lineTotal,
            fnHit: fnHit, fnTotal: fnTotal,
            brHit: brHit, brTotal: brTotal));
      }
      currentFile = null;
      lineHit = 0; lineTotal = 0;
      fnHit = 0; fnTotal = 0;
      brHit = 0; brTotal = 0;
    }
  }
  return results;
}

// --- Screenshot collector ---

List<Screenshot> collectScreenshots(String dirPath) {
  final dir = Directory(dirPath);
  if (!dir.existsSync()) return [];

  final screenshots = <Screenshot>[];
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
        screenshots.add(Screenshot(folder, name, b64));
      } catch (_) {}
    }
  }
  screenshots.sort((a, b) {
    final c = a.folder.compareTo(b.folder);
    return c != 0 ? c : a.name.compareTo(b.name);
  });
  return screenshots;
}

// --- Screen/flow coverage parser (using yaml package) ---

E2eCoverage parseScreenCoverage(String path) {
  final file = File(path);
  if (!file.existsSync()) return E2eCoverage([], []);

  try {
    final doc = loadYaml(file.readAsStringSync()) as YamlMap?;
    if (doc == null) return E2eCoverage([], []);

    List<E2eItem> parseItems(YamlList? list) {
      if (list == null) return [];
      return list.map((item) {
        final map = item as YamlMap;
        return E2eItem(
          id: map['id']?.toString() ?? '',
          name: map['name']?.toString() ?? '',
          path: map['path']?.toString(),
          playwright: map['playwright']?.toString(),
          maestro: map['maestro']?.toString(),
        );
      }).toList();
    }

    return E2eCoverage(
      parseItems(doc['screens'] as YamlList?),
      parseItems(doc['flows'] as YamlList?),
    );
  } catch (e) {
    stderr.writeln('Warning: Could not parse screen-coverage.yaml: $e');
    return E2eCoverage([], []);
  }
}

// --- Environment metadata reader ---

String readEnvLabel(String path) {
  if (path.isEmpty) return '';
  final file = File(path);
  if (!file.existsSync()) return '';
  try {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final parts = <String>[];
    if (json.containsKey('flutter')) {
      parts.add('Flutter ${json['flutter']}');
      if (json.containsKey('dart')) parts.add('Dart ${json['dart']}');
    }
    if (json.containsKey('browser')) {
      parts.add(json['browser'] as String);
    }
    if (json.containsKey('device')) {
      final device = json['device'] as String;
      final sdk = json['sdk'] as String? ?? '';
      parts.add(device);
      if (sdk.isNotEmpty && sdk != 'unknown') parts.add('API $sdk');
    }
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

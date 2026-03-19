/// Data models for the test report.

class Test {
  Test({required this.name, required this.suiteId});

  final String name;
  final int suiteId;
  String? result;
  bool hidden = false;
  bool skipped = false;
  int time = 0;
  String? error;
  String? stackTrace;
}

class TestLayerResults {
  TestLayerResults(this.suites, this.durationMs);

  final Map<String, List<Test>> suites;
  final int durationMs;
}

class CovFile {
  CovFile(this.path, {this.lineHit = 0, this.lineTotal = 0, this.fnHit = 0, this.fnTotal = 0, this.brHit = 0, this.brTotal = 0});

  final String path;
  final int lineHit;
  final int lineTotal;
  final int fnHit;
  final int fnTotal;
  final int brHit;
  final int brTotal;

  double get linePct => lineTotal > 0 ? (lineHit / lineTotal * 100) : 0;
  double get fnPct => fnTotal > 0 ? (fnHit / fnTotal * 100) : 0;
  double get brPct => brTotal > 0 ? (brHit / brTotal * 100) : 0;

  /// Legacy alias for line coverage percentage.
  double get pct => linePct;
  int get hit => lineHit;
  int get total => lineTotal;
}

class Screenshot {
  Screenshot(this.folder, this.name, this.base64);

  final String folder;
  final String name;
  final String base64;
}

class TestLayer {
  TestLayer({
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
  final Map<String, List<Test>> suites;
  final String generateCmd;
  final List<Screenshot> screenshots;
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

class E2eItem {
  E2eItem({
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

class E2eCoverage {
  E2eCoverage(this.screens, this.flows);

  final List<E2eItem> screens;
  final List<E2eItem> flows;
}

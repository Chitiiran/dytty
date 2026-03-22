/// Collects per-turn latency measurements and computes percentiles.
class LatencyTracker {
  final List<int> _data = [];

  /// Record a latency measurement in milliseconds.
  void add(int ms) => _data.add(ms);

  /// Median latency, or null if no measurements.
  int? get p50 => _percentile(0.5);

  /// 95th percentile latency, or null if no measurements.
  int? get p95 => _percentile(0.95);

  /// Unmodifiable view of all recorded measurements.
  List<int> get measurements => List.unmodifiable(_data);

  /// Clear all measurements.
  void reset() => _data.clear();

  int? _percentile(double p) {
    if (_data.isEmpty) return null;
    final sorted = List<int>.of(_data)..sort();
    final index = ((sorted.length - 1) * p).ceil();
    return sorted[index];
  }
}

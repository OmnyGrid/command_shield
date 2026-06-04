// Fails (non-zero exit) when LCOV line coverage is below a threshold.
//
// Usage: dart run tool/check_coverage.dart <lcov-file> <min-percent>
import 'dart:io';

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln('Usage: check_coverage.dart <lcov-file> <min-percent>');
    exit(64);
  }
  final file = File(args[0]);
  final threshold = double.parse(args[1]);

  if (!file.existsSync()) {
    stderr.writeln('Coverage file not found: ${args[0]}');
    exit(66);
  }

  var found = 0;
  var hit = 0;
  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      if (parts.length == 2) {
        found++;
        if (int.parse(parts[1]) > 0) hit++;
      }
    }
  }

  if (found == 0) {
    stderr.writeln('No coverage data found.');
    exit(1);
  }

  final pct = hit / found * 100;
  stdout.writeln(
    'Line coverage: ${pct.toStringAsFixed(2)}% '
    '($hit/$found lines), threshold ${threshold.toStringAsFixed(0)}%.',
  );
  if (pct + 1e-9 < threshold) {
    stderr.writeln('Coverage below threshold.');
    exit(1);
  }
}

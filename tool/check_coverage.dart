import 'dart:io';

void main(List<String> args) {
  final path = args.isNotEmpty ? args[0] : 'coverage/lcov.info';
  final minimum = args.length > 1 ? double.parse(args[1]) : 40.0;
  final file = File(path);

  if (!file.existsSync()) {
    stderr.writeln('Coverage file not found: $path');
    exitCode = 1;
    return;
  }

  var linesFound = 0;
  var linesHit = 0;
  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('LF:')) {
      linesFound += int.parse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      linesHit += int.parse(line.substring(3));
    }
  }

  if (linesFound == 0) {
    stderr.writeln('Coverage file has no line records: $path');
    exitCode = 1;
    return;
  }

  final coverage = linesHit * 100 / linesFound;
  stdout.writeln(
    'Line coverage: ${coverage.toStringAsFixed(2)}% '
    '($linesHit/$linesFound), minimum ${minimum.toStringAsFixed(2)}%',
  );

  if (coverage < minimum) {
    stderr.writeln('Coverage is below the required threshold.');
    exitCode = 1;
  }
}

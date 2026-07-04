import 'dart:io';

Iterable<File> dartFilesUnder(String path) {
  return Directory(path)
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));
}

List<String> patternOffenders(Iterable<File> files, RegExp pattern) {
  final offenders = <String>[];
  for (final file in files) {
    final source = file.readAsStringSync();
    for (final match in pattern.allMatches(source)) {
      final line = lineNumber(source, match.start);
      offenders.add('${file.path}:$line ${match.group(0)}');
    }
  }
  return offenders;
}

int lineNumber(String source, int offset) {
  return '\n'.allMatches(source.substring(0, offset)).length + 1;
}

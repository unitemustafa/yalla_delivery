import 'dart:io';

const _maximumLines = 800;
const _sourceRoots = ['lib', 'test', 'integration_test', 'tool'];

void main() {
  final oversized = <String, int>{};

  for (final root in _sourceRoots) {
    final directory = Directory(root);
    if (!directory.existsSync()) continue;

    for (final entity in directory.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync().length;
      if (lines > _maximumLines) {
        oversized[entity.path.replaceAll('\\', '/')] = lines;
      }
    }
  }

  if (oversized.isEmpty) {
    stdout.writeln(
      'Source-size check passed; no Dart file exceeds $_maximumLines lines.',
    );
    return;
  }

  stderr.writeln('Dart files exceeding $_maximumLines lines:');
  for (final entry
      in oversized.entries.toList()
        ..sort((left, right) => right.value.compareTo(left.value))) {
    stderr.writeln('- ${entry.key}: ${entry.value}');
  }
  exitCode = 1;
}

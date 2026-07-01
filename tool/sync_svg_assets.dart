import 'dart:io';

const String beginMarker = '    # BEGIN AUTO-GENERATED SVG ASSET DIRS';
const String endMarker = '    # END AUTO-GENERATED SVG ASSET DIRS';

void main() {
  final repoRoot = Directory.current;
  final pubspecFile = File('${repoRoot.path}/pubspec.yaml');
  final assetsRoot = Directory('${repoRoot.path}/assets');

  if (!pubspecFile.existsSync()) {
    stderr.writeln('pubspec.yaml non trovato in ${repoRoot.path}');
    exitCode = 1;
    return;
  }

  if (!assetsRoot.existsSync()) {
    stderr.writeln('Cartella assets non trovata in ${repoRoot.path}');
    exitCode = 1;
    return;
  }

  final svgDirs = _collectSvgDirectories(repoRoot.path, assetsRoot.path);
  final pubspecLines = pubspecFile.readAsLinesSync();

  final beginIndex = pubspecLines.indexOf(beginMarker);
  final endIndex = pubspecLines.indexOf(endMarker);
  if (beginIndex == -1 || endIndex == -1 || beginIndex >= endIndex) {
    stderr.writeln(
      'Marker blocco asset non trovati o invalidi in pubspec.yaml',
    );
    exitCode = 1;
    return;
  }

  final generated = <String>[beginMarker];
  for (final dir in svgDirs) {
    generated.add('    - $dir/');
  }
  generated.add(endMarker);

  final updated = <String>[
    ...pubspecLines.take(beginIndex),
    ...generated,
    ...pubspecLines.skip(endIndex + 1),
  ];

  pubspecFile.writeAsStringSync('${updated.join('\n')}\n');

  stdout.writeln('Aggiornate ${svgDirs.length} directory SVG in pubspec.yaml');
}

List<String> _collectSvgDirectories(String repoRoot, String assetsRoot) {
  final result = <String>{};

  for (final entity in Directory(
    assetsRoot,
  ).listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    if (!entity.path.toLowerCase().endsWith('.svg')) continue;

    final parent = entity.parent.path;
    final relative = parent
        .replaceFirst('$repoRoot${Platform.pathSeparator}', '')
        .replaceAll('\\', '/');
    result.add(relative);
  }

  final sorted = result.toList()..sort();
  return sorted;
}

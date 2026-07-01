import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class SvgAssetIconInfo {
  final String assetPath;
  final String category;
  final String name;
  final String searchText;

  const SvgAssetIconInfo({
    required this.assetPath,
    required this.category,
    required this.name,
    required this.searchText,
  });
}

class SvgAssetIconCatalog {
  static const String _drawioTreeUrl =
      'https://api.github.com/repos/jgraph/drawio/git/trees/dev?recursive=1';
  static const String _drawioRawBase =
      'https://raw.githubusercontent.com/jgraph/drawio/dev/src/main/webapp/img/lib/';
  static const String _drawioPrefix = 'src/main/webapp/img/lib/';

  static Future<List<SvgAssetIconInfo>>? _cached;
  static Future<List<SvgAssetIconInfo>>? _cachedDrawio;
  static Future<List<SvgAssetIconInfo>>? _cachedAll;
  static final RegExp _sizeSegment = RegExp(r'/(16|32|48|64)/');
  static final RegExp _sizeToken = RegExp(r'([_-])(16|32|48|64)(?=([_.-]|$))');

  static Future<List<SvgAssetIconInfo>> load() {
    _cached ??= _loadFromManifest();
    return _cached!;
  }

  static Future<List<SvgAssetIconInfo>> loadDrawio() {
    _cachedDrawio ??= _loadDrawioFromGitHub();
    return _cachedDrawio!;
  }

  static Future<List<SvgAssetIconInfo>> loadAll({
    bool includeLocal = true,
    bool includeDrawio = true,
  }) {
    if (includeLocal && includeDrawio) {
      _cachedAll ??= _loadAll();
      return _cachedAll!;
    }
    if (includeLocal) return load();
    if (includeDrawio) return loadDrawio();
    return Future.value(const <SvgAssetIconInfo>[]);
  }

  static SvgAssetIconInfo fromAssetPath(String assetPath) {
    final normalizedPath = assetPath.replaceAll('\\', '/');
    final parts = normalizedPath.split('/');
    final rawFileName = parts.isNotEmpty
        ? Uri.decodeComponent(parts.last)
        : normalizedPath;
    final category = parts.length > 1
        ? Uri.decodeComponent(parts[1])
        : 'general';
    final fileNameNoExt = rawFileName.replaceAll(
      RegExp(r'\.svg$', caseSensitive: false),
      '',
    );
    final prettyName = _prettifyName(fileNameNoExt);
    final decodedPath = parts.map(Uri.decodeComponent).join(' ');

    print(prettyName);
    return SvgAssetIconInfo(
      assetPath: normalizedPath,
      category: _capitalizeWords(category),
      name: prettyName,
      searchText: '$prettyName $category $fileNameNoExt $decodedPath'
          .toLowerCase(),
    );
  }

  static SvgAssetIconInfo fromDrawioPath(String drawioRelativePath) {
    final normalizedPath = drawioRelativePath.replaceAll('\\', '/');
    final parts = normalizedPath.split('/');
    final rawFileName = parts.isNotEmpty
        ? Uri.decodeComponent(parts.last)
        : normalizedPath;
    final category = parts.isNotEmpty
        ? Uri.decodeComponent(parts.first)
        : 'general';
    final fileNameNoExt = rawFileName.replaceAll(
      RegExp(r'\.svg$', caseSensitive: false),
      '',
    );
    final prettyName = _prettifyName(fileNameNoExt);
    final url = '$_drawioRawBase$normalizedPath';

    return SvgAssetIconInfo(
      assetPath: url,
      category: '${_capitalizeWords(category)}',
      name: prettyName,
      searchText: '$prettyName $category $normalizedPath'.toLowerCase(),
    );
  }

  static Future<List<SvgAssetIconInfo>> _loadFromManifest() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);

    final rawPaths = manifest
        .listAssets()
        .where(
          (path) =>
              path.startsWith('assets/') && path.toLowerCase().endsWith('.svg'),
        )
        .toList(growable: false);

    final bestByCanonical = <String, String>{};
    for (final path in rawPaths) {
      final canonical = _canonicalPath(path);
      final current = bestByCanonical[canonical];
      if (current == null || _isBetterCandidate(path, current)) {
        bestByCanonical[canonical] = path;
      }
    }

    final paths = bestByCanonical.values.toList()..sort();

    final icons = paths.map(fromAssetPath).toList(growable: false);
    icons.sort((a, b) {
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      if (byName != 0) return byName;
      return a.category.toLowerCase().compareTo(b.category.toLowerCase());
    });

    return icons;
  }

  static Future<List<SvgAssetIconInfo>> _loadDrawioFromGitHub() async {
    try {
      final response = await http
          .get(
            Uri.parse(_drawioTreeUrl),
            headers: const {'User-Agent': 'in-graph'},
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        return const <SvgAssetIconInfo>[];
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final tree = decoded['tree'];
      if (tree is! List) {
        return const <SvgAssetIconInfo>[];
      }

      final paths = <String>{};
      for (final node in tree) {
        if (node is! Map<String, dynamic>) continue;
        final path = node['path'];
        if (path is! String) continue;
        if (!path.startsWith(_drawioPrefix)) continue;
        if (!path.toLowerCase().endsWith('.svg')) continue;
        paths.add(path.substring(_drawioPrefix.length));
      }

      final icons = paths.map(fromDrawioPath).toList(growable: false)
        ..sort((a, b) {
          final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          if (byName != 0) return byName;
          return a.category.toLowerCase().compareTo(b.category.toLowerCase());
        });

      return icons;
    } catch (_) {
      return const <SvgAssetIconInfo>[];
    }
  }

  static Future<List<SvgAssetIconInfo>> _loadAll() async {
    final results = await Future.wait([load(), loadDrawio()]);
    final combined = <SvgAssetIconInfo>[...results[0], ...results[1]];
    return combined;
  }

  static String _canonicalPath(String path) {
    final withNormalizedFolder = path.replaceFirst(_sizeSegment, '/{size}/');
    final lastSlash = withNormalizedFolder.lastIndexOf('/');
    if (lastSlash == -1) return withNormalizedFolder;

    final prefix = withNormalizedFolder.substring(0, lastSlash + 1);
    final fileName = withNormalizedFolder.substring(lastSlash + 1);
    final normalizedFileName = fileName.replaceAllMapped(
      _sizeToken,
      (match) => '${match.group(1)}{size}',
    );

    return '$prefix$normalizedFileName';
  }

  static bool _isBetterCandidate(String candidate, String current) {
    final candidatePriority = _sizePriority(candidate);
    final currentPriority = _sizePriority(current);
    if (candidatePriority != currentPriority) {
      return candidatePriority < currentPriority;
    }
    return candidate.length < current.length;
  }

  static int _sizePriority(String path) {
    final folderMatch = _sizeSegment.firstMatch(path);
    final folderSize = folderMatch?.group(1);

    final lastSlash = path.lastIndexOf('/');
    final fileName = lastSlash == -1 ? path : path.substring(lastSlash + 1);
    final fileMatch = _sizeToken.firstMatch(fileName);
    final fileSize = fileMatch?.group(2);

    final size = folderSize ?? fileSize;
    if (size == null) return 4;

    switch (size) {
      case '64':
        return 0;
      case '48':
        return 1;
      case '32':
        return 2;
      case '16':
        return 3;
      default:
        return 4;
    }
  }

  static String _prettifyName(String raw) {
    var name = raw;
    name = name.replaceFirst(RegExp(r'^\d+\s*-?\s*'), '');
    name = name.replaceFirst(
      RegExp(r'^icon-service-', caseSensitive: false),
      '',
    );
    name = name.replaceAll('-', ' ');
    name = name.replaceAll('_', ' ');
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    return _capitalizeWords(name);
  }

  static String _capitalizeWords(String value) {
    if (value.isEmpty) return value;
    final words = value.split(' ');
    return words
        .map((word) {
          if (word.isEmpty) return word;
          return '${word[0].toUpperCase()}${word.substring(1)}';
        })
        .join(' ');
  }
}

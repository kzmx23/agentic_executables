import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../models/artifact_pack.dart';
import '../models/heuristic_artifact.dart';
import '../ports/heuristic_extractor.dart';

/// Heuristic extractor for Dart packages.
///
/// Recognizes a directory containing `pubspec.yaml`. Hashes every `.dart`
/// file under `lib/`; extracts public class/mixin/enum/typedef/extension
/// declarations via regex; harvests preceding `///` doc-comments; emits an
/// `index.md` with title, README excerpt, public-API summary, and dependency
/// list. Bridge-package detection: flags presence of `ffi` dep or any
/// `MethodChannel` reference in source.
class DartHeuristicExtractor implements HeuristicExtractor {
  const DartHeuristicExtractor();

  @override
  String get languageId => 'dart';

  @override
  Future<bool> canHandle(final Directory sourceDir) async {
    return File(p.join(sourceDir.path, 'pubspec.yaml')).exists();
  }

  @override
  Future<HeuristicArtifact> extract(final Directory sourceDir) async {
    final pubspec = await _readPubspec(sourceDir);
    final name = pubspec['name']?.toString() ?? p.basename(sourceDir.path);
    final description = pubspec['description']?.toString() ?? '';
    final dependencies = _readDeps(pubspec, 'dependencies');
    final devDependencies = _readDeps(pubspec, 'dev_dependencies');

    final dartFiles = await _collectDartFiles(sourceDir);
    final hashedFiles = <ArtifactSourceFile>[];
    final allSourceText = StringBuffer();
    for (final file in dartFiles) {
      final relative = p.relative(file.path, from: sourceDir.path);
      final bytes = await file.readAsBytes();
      hashedFiles.add(ArtifactSourceFile(
        path: relative.replaceAll(r'\', '/'),
        sha256: sha256.convert(bytes).toString(),
      ));
      allSourceText.write(utf8.decode(bytes, allowMalformed: true));
      allSourceText.write('\n');
    }

    final publicSymbols = _extractPublicSymbols(dartFiles, sourceDir);
    final readmeExcerpt = await _readReadmeExcerpt(sourceDir);
    final license = await _detectLicense(sourceDir);
    final hasFfiDep = dependencies.containsKey('ffi') ||
        devDependencies.containsKey('ffi');
    final hasMethodChannel =
        allSourceText.toString().contains('MethodChannel');
    final isBridge = hasFfiDep || hasMethodChannel;

    final indexMd = _buildIndexMd(
      name: name,
      description: description,
      readmeExcerpt: readmeExcerpt,
      publicSymbols: publicSymbols,
      runtimeDeps: dependencies.keys.toList()..sort(),
      devDeps: devDependencies.keys.toList()..sort(),
      isBridge: isBridge,
    );

    final meta = ArtifactMeta(
      kind: ArtifactKind.local,
      title: name,
      source: ArtifactSource(
        type: ArtifactSourceType.path,
        path: sourceDir.path,
        files: hashedFiles,
      ),
      scannedAt: DateTime.now().toUtc(),
      license: license,
      authors: const [],
      referencesCanonical: const [],
      extractor: 'dart_v1',
      distill: const ArtifactDistill(engine: 'heuristic'),
    );

    return HeuristicArtifact(
      name: name,
      languageId: languageId,
      meta: meta,
      indexMd: indexMd,
    );
  }

  Future<Map> _readPubspec(final Directory sourceDir) async {
    final file = File(p.join(sourceDir.path, 'pubspec.yaml'));
    if (!await file.exists()) return const {};
    final yaml = loadYaml(await file.readAsString());
    return yaml is Map ? yaml : const {};
  }

  Map<String, String> _readDeps(final Map pubspec, final String key) {
    final raw = pubspec[key];
    final out = <String, String>{};
    if (raw is Map) {
      for (final entry in raw.entries) {
        out[entry.key.toString()] = entry.value?.toString() ?? '';
      }
    }
    return out;
  }

  Future<List<File>> _collectDartFiles(final Directory sourceDir) async {
    final libDir = Directory(p.join(sourceDir.path, 'lib'));
    if (!await libDir.exists()) return const [];
    final files = <File>[];
    await for (final entity in libDir.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        files.add(entity);
      }
    }
    files.sort((final a, final b) => a.path.compareTo(b.path));
    return files;
  }

  /// Map of public symbol name -> doc-comment headline (first non-empty line
  /// of the `///` block immediately preceding the declaration). Headline is
  /// empty if no doc-comment present.
  List<_PublicSymbol> _extractPublicSymbols(
    final List<File> files,
    final Directory sourceDir,
  ) {
    final symbols = <_PublicSymbol>[];
    final declPattern = RegExp(
      r'^(?:abstract\s+|final\s+|sealed\s+|interface\s+|base\s+)*'
      r'(class|mixin|enum|typedef|extension)\s+(\w+)\b',
    );
    for (final file in files) {
      final lines = file.readAsStringSync().split('\n');
      final docBuffer = <String>[];
      for (final line in lines) {
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('///')) {
          docBuffer.add(trimmed.substring(3).trim());
          continue;
        }
        final match = declPattern.firstMatch(line);
        if (match != null) {
          final name = match.group(2)!;
          if (!name.startsWith('_')) {
            final headline = docBuffer
                .firstWhere((final l) => l.isNotEmpty, orElse: () => '')
                .trim();
            symbols.add(_PublicSymbol(
              kind: match.group(1)!,
              name: name,
              headline: headline,
              file: p.relative(file.path, from: sourceDir.path)
                  .replaceAll(r'\', '/'),
            ));
          }
          docBuffer.clear();
          continue;
        }
        if (trimmed.isEmpty) continue;
        // Any other non-blank line resets pending docs.
        docBuffer.clear();
      }
    }
    return symbols;
  }

  Future<String> _readReadmeExcerpt(final Directory sourceDir) async {
    final file = File(p.join(sourceDir.path, 'README.md'));
    if (!await file.exists()) return '';
    final lines = (await file.readAsString()).split('\n');
    final buffer = StringBuffer();
    var seenH1 = false;
    for (final line in lines) {
      if (!seenH1) {
        if (line.startsWith('# ')) seenH1 = true;
        continue;
      }
      // Stop at the next heading.
      if (line.startsWith('#')) break;
      if (line.trim().isEmpty && buffer.isEmpty) continue;
      buffer.writeln(line);
      // Excerpt = first paragraph: stop on blank line after content started.
      if (line.trim().isEmpty && buffer.isNotEmpty) break;
    }
    return buffer.toString().trim();
  }

  Future<ArtifactLicense?> _detectLicense(final Directory sourceDir) async {
    final candidates = ['LICENSE', 'LICENSE.md', 'LICENSE.txt'];
    for (final candidate in candidates) {
      final file = File(p.join(sourceDir.path, candidate));
      if (await file.exists()) {
        final text = await file.readAsString();
        return ArtifactLicense(
          spdx: _guessSpdx(text),
          detectedFrom: 'license_file',
        );
      }
    }
    return null;
  }

  String _guessSpdx(final String text) {
    final lower = text.toLowerCase();
    if (lower.contains('mit license')) return 'MIT';
    if (lower.contains('apache license')) return 'Apache-2.0';
    if (lower.contains('bsd 3-clause')) return 'BSD-3-Clause';
    if (lower.contains('bsd 2-clause')) return 'BSD-2-Clause';
    if (lower.contains('mozilla public license')) return 'MPL-2.0';
    if (lower.contains('gnu general public license')) return 'GPL-3.0';
    return 'unknown';
  }

  String _buildIndexMd({
    required final String name,
    required final String description,
    required final String readmeExcerpt,
    required final List<_PublicSymbol> publicSymbols,
    required final List<String> runtimeDeps,
    required final List<String> devDeps,
    required final bool isBridge,
  }) {
    final buffer = StringBuffer()
      ..writeln('# $name')
      ..writeln();
    if (description.isNotEmpty) {
      buffer
        ..writeln(description)
        ..writeln();
    }
    if (readmeExcerpt.isNotEmpty) {
      buffer
        ..writeln('## Overview')
        ..writeln()
        ..writeln(readmeExcerpt)
        ..writeln();
    }
    if (publicSymbols.isNotEmpty) {
      buffer
        ..writeln('## Public API')
        ..writeln();
      for (final s in publicSymbols) {
        buffer.write('- `${s.name}` (${s.kind})');
        if (s.headline.isNotEmpty) {
          buffer.write(' — ${s.headline}');
        }
        buffer.writeln(' [${s.file}]');
      }
      buffer.writeln();
    }
    if (runtimeDeps.isNotEmpty) {
      buffer
        ..writeln('## Dependencies')
        ..writeln();
      for (final d in runtimeDeps) {
        buffer.writeln('- $d');
      }
      buffer.writeln();
    }
    if (devDeps.isNotEmpty) {
      buffer
        ..writeln('## Dev Dependencies')
        ..writeln();
      for (final d in devDeps) {
        buffer.writeln('- $d');
      }
      buffer.writeln();
    }
    if (isBridge) {
      buffer
        ..writeln('## Notes')
        ..writeln()
        ..writeln('Bridge package: depends on `ffi` or uses `MethodChannel`.')
        ..writeln();
    }
    return buffer.toString();
  }
}

class _PublicSymbol {
  const _PublicSymbol({
    required this.kind,
    required this.name,
    required this.headline,
    required this.file,
  });

  final String kind;
  final String name;
  final String headline;
  final String file;
}

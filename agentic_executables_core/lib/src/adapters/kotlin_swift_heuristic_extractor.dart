import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../models/artifact_pack.dart';
import '../models/heuristic_artifact.dart';
import '../ports/heuristic_extractor.dart';

/// Best-effort heuristic extractor for Kotlin / Swift projects.
///
/// Recognizes `Package.swift` (Swift Package), `build.gradle.kts`, or
/// `build.gradle` (Kotlin / JVM / Android). Lists source files and counts
/// public top-level types via regex. No deep semantic parse in 3.0.
class KotlinSwiftHeuristicExtractor implements HeuristicExtractor {
  const KotlinSwiftHeuristicExtractor();

  @override
  String get languageId => 'kotlin_swift';

  static const _manifestCandidates = [
    'Package.swift',
    'build.gradle.kts',
    'build.gradle',
  ];

  @override
  Future<bool> canHandle(final Directory sourceDir) async {
    for (final candidate in _manifestCandidates) {
      if (await File(p.join(sourceDir.path, candidate)).exists()) return true;
    }
    return false;
  }

  @override
  Future<HeuristicArtifact> extract(final Directory sourceDir) async {
    final name = await _detectName(sourceDir) ?? p.basename(sourceDir.path);

    final sourceFiles = await _collectSourceFiles(sourceDir);
    final hashedFiles = <ArtifactSourceFile>[];
    final allText = StringBuffer();
    for (final file in sourceFiles) {
      final relative = p.relative(file.path, from: sourceDir.path);
      final bytes = await file.readAsBytes();
      hashedFiles.add(ArtifactSourceFile(
        path: relative.replaceAll(r'\', '/'),
        sha256: sha256.convert(bytes).toString(),
      ));
      allText.write(utf8.decode(bytes, allowMalformed: true));
      allText.write('\n');
    }

    final publicTypes = _extractPublicTypes(allText.toString());
    final readmeExcerpt = await _readReadmeExcerpt(sourceDir);
    final license = await _detectLicense(sourceDir);

    final indexMd = _buildIndexMd(
      name: name,
      readmeExcerpt: readmeExcerpt,
      publicTypes: publicTypes,
      sourceFileCount: sourceFiles.length,
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
      extractor: 'kotlin_swift_v1',
      distill: const ArtifactDistill(engine: 'heuristic'),
    );

    return HeuristicArtifact(
      name: name,
      languageId: languageId,
      meta: meta,
      indexMd: indexMd,
    );
  }

  Future<String?> _detectName(final Directory sourceDir) async {
    final swiftFile = File(p.join(sourceDir.path, 'Package.swift'));
    if (await swiftFile.exists()) {
      final text = await swiftFile.readAsString();
      final m = RegExp(r'name:\s*"([^"]+)"').firstMatch(text);
      if (m != null) return m.group(1);
    }
    final settingsKts = File(p.join(sourceDir.path, 'settings.gradle.kts'));
    if (await settingsKts.exists()) {
      final text = await settingsKts.readAsString();
      final m =
          RegExp(r'rootProject\.name\s*=\s*"([^"]+)"').firstMatch(text);
      if (m != null) return m.group(1);
    }
    final settingsGroovy = File(p.join(sourceDir.path, 'settings.gradle'));
    if (await settingsGroovy.exists()) {
      final text = await settingsGroovy.readAsString();
      final m = RegExp(r"rootProject\.name\s*=\s*'([^']+)'").firstMatch(text);
      if (m != null) return m.group(1);
    }
    return null;
  }

  Future<List<File>> _collectSourceFiles(final Directory sourceDir) async {
    final files = <File>[];
    final candidateDirs = [
      Directory(p.join(sourceDir.path, 'Sources')),
      Directory(p.join(sourceDir.path, 'src')),
    ];
    for (final dir in candidateDirs) {
      if (!await dir.exists()) continue;
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File &&
            (entity.path.endsWith('.swift') ||
                entity.path.endsWith('.kt') ||
                entity.path.endsWith('.kts'))) {
          files.add(entity);
        }
      }
    }
    files.sort((final a, final b) => a.path.compareTo(b.path));
    return files;
  }

  /// Returns names of public top-level types (Swift `public class/struct/
  /// protocol/enum`, Kotlin `public class/object/interface`).
  List<String> _extractPublicTypes(final String text) {
    final patterns = <RegExp>[
      RegExp(r'\bpublic\s+(?:final\s+)?(?:class|struct|protocol|enum)\s+(\w+)'),
      RegExp(r'\bpublic\s+(?:object|interface)\s+(\w+)'),
    ];
    final names = <String>{};
    for (final pattern in patterns) {
      for (final match in pattern.allMatches(text)) {
        final name = match.group(1)!;
        if (!name.startsWith('_')) names.add(name);
      }
    }
    final list = names.toList()..sort();
    return list;
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
      if (line.startsWith('#')) break;
      if (line.trim().isEmpty && buffer.isEmpty) continue;
      buffer.writeln(line);
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
        final lower = text.toLowerCase();
        String spdx = 'unknown';
        if (lower.contains('apache license')) {
          spdx = 'Apache-2.0';
        } else if (lower.contains('mit license')) {
          spdx = 'MIT';
        } else if (lower.contains('bsd 3-clause')) spdx = 'BSD-3-Clause';
        return ArtifactLicense(spdx: spdx, detectedFrom: 'license_file');
      }
    }
    return null;
  }

  String _buildIndexMd({
    required final String name,
    required final String readmeExcerpt,
    required final List<String> publicTypes,
    required final int sourceFileCount,
  }) {
    final buffer = StringBuffer()
      ..writeln('# $name')
      ..writeln();
    if (readmeExcerpt.isNotEmpty) {
      buffer
        ..writeln('## Overview')
        ..writeln()
        ..writeln(readmeExcerpt)
        ..writeln();
    }
    buffer
      ..writeln('## Inventory')
      ..writeln()
      ..writeln('- Source files: $sourceFileCount')
      ..writeln('- public types: ${publicTypes.length}')
      ..writeln();
    if (publicTypes.isNotEmpty) {
      buffer
        ..writeln('## Public types')
        ..writeln();
      for (final t in publicTypes) {
        buffer.writeln('- `$t`');
      }
      buffer.writeln();
    }
    return buffer.toString();
  }
}

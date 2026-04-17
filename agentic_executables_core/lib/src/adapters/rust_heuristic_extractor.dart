import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../models/artifact_pack.dart';
import '../models/heuristic_artifact.dart';
import '../ports/heuristic_extractor.dart';

/// Heuristic extractor for Rust crates.
///
/// Recognizes a directory containing `Cargo.toml`. Parses `[package]` for
/// name/description/version; reads `[features]`; walks `src/lib.rs` and
/// `src/main.rs`; regex-extracts `pub fn`, `pub struct`, `pub enum`,
/// `pub trait`; harvests `///` doc-comments. Emits `index.md` with title,
/// README excerpt, public-API summary, dependencies, feature flags.
class RustHeuristicExtractor implements HeuristicExtractor {
  const RustHeuristicExtractor();

  @override
  String get languageId => 'rust';

  @override
  Future<bool> canHandle(final Directory sourceDir) async =>
      File(p.join(sourceDir.path, 'Cargo.toml')).exists();

  @override
  Future<HeuristicArtifact> extract(final Directory sourceDir) async {
    final cargo = await _readCargo(sourceDir);
    final name = cargo.packageName ?? p.basename(sourceDir.path);
    final description = cargo.packageDescription ?? '';

    final files = await _collectRustFiles(sourceDir);
    final hashedFiles = <ArtifactSourceFile>[];
    for (final file in files) {
      final relative = p.relative(file.path, from: sourceDir.path);
      final bytes = await file.readAsBytes();
      hashedFiles.add(ArtifactSourceFile(
        path: relative.replaceAll(r'\', '/'),
        sha256: sha256.convert(bytes).toString(),
      ));
    }

    final publicSymbols = _extractPublicSymbols(files, sourceDir);
    final readmeExcerpt = await _readReadmeExcerpt(sourceDir);
    final license = await _detectLicense(sourceDir);

    final indexMd = _buildIndexMd(
      name: name,
      description: description,
      readmeExcerpt: readmeExcerpt,
      publicSymbols: publicSymbols,
      dependencies: cargo.dependencies,
      features: cargo.features,
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
      extractor: 'rust_v1',
      distill: const ArtifactDistill(engine: 'heuristic'),
    );

    return HeuristicArtifact(
      name: name,
      languageId: languageId,
      meta: meta,
      indexMd: indexMd,
    );
  }

  Future<_CargoSummary> _readCargo(final Directory sourceDir) async {
    final file = File(p.join(sourceDir.path, 'Cargo.toml'));
    if (!await file.exists()) return const _CargoSummary();
    final text = await file.readAsString();
    return _parseCargo(text);
  }

  /// Minimal TOML parser for the subset of Cargo.toml we care about:
  /// `[package]` name/description/version, `[dependencies]` keys,
  /// `[features]` keys. Avoids a TOML dep — string scanning is enough.
  _CargoSummary _parseCargo(final String text) {
    String? name;
    String? description;
    final dependencies = <String>[];
    final features = <String>[];
    String section = '';

    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      if (line.startsWith('[') && line.endsWith(']')) {
        section = line.substring(1, line.length - 1).trim();
        continue;
      }
      final eq = line.indexOf('=');
      if (eq < 0) continue;
      final key = line.substring(0, eq).trim();
      final value = line.substring(eq + 1).trim();
      String unquote(final String v) {
        var x = v;
        if (x.endsWith(',')) x = x.substring(0, x.length - 1).trim();
        if ((x.startsWith('"') && x.endsWith('"')) ||
            (x.startsWith("'") && x.endsWith("'"))) {
          return x.substring(1, x.length - 1);
        }
        return x;
      }

      if (section == 'package') {
        if (key == 'name') name = unquote(value);
        if (key == 'description') description = unquote(value);
      } else if (section == 'dependencies') {
        dependencies.add(key);
      } else if (section == 'features') {
        features.add(key);
      }
    }
    dependencies.sort();
    features.sort();
    return _CargoSummary(
      packageName: name,
      packageDescription: description,
      dependencies: dependencies,
      features: features,
    );
  }

  Future<List<File>> _collectRustFiles(final Directory sourceDir) async {
    final srcDir = Directory(p.join(sourceDir.path, 'src'));
    if (!await srcDir.exists()) return const [];
    final files = <File>[];
    await for (final entity in srcDir.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith('.rs')) {
        files.add(entity);
      }
    }
    files.sort((final a, final b) => a.path.compareTo(b.path));
    return files;
  }

  List<_PublicSymbol> _extractPublicSymbols(
    final List<File> files,
    final Directory sourceDir,
  ) {
    final symbols = <_PublicSymbol>[];
    final declPattern = RegExp(
      r'^\s*pub(?:\([^)]*\))?\s+(fn|struct|enum|trait|type|const|static)\s+(\w+)',
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
        if (trimmed.startsWith('//!')) continue;
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
    if (lower.contains('apache license')) return 'Apache-2.0';
    if (lower.contains('mit license')) return 'MIT';
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
    required final List<String> dependencies,
    required final List<String> features,
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
    if (dependencies.isNotEmpty) {
      buffer
        ..writeln('## Dependencies')
        ..writeln();
      for (final d in dependencies) {
        buffer.writeln('- $d');
      }
      buffer.writeln();
    }
    if (features.isNotEmpty) {
      buffer
        ..writeln('## Feature flags')
        ..writeln();
      for (final f in features) {
        buffer.writeln('- $f');
      }
      buffer.writeln();
    }
    return buffer.toString();
  }
}

class _CargoSummary {
  const _CargoSummary({
    this.packageName,
    this.packageDescription,
    this.dependencies = const [],
    this.features = const [],
  });

  final String? packageName;
  final String? packageDescription;
  final List<String> dependencies;
  final List<String> features;
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

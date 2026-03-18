import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/know.dart';
import '../ports/know_extractor.dart';

class RepoExtractor implements KnowledgeExtractor {
  @override
  bool canHandle(final KnowSource source) =>
      source.type == KnowSourceType.repo;

  @override
  Future<KnowPack> extract(final String name, final KnowSource source) async {
    final repoUrl = source.url!;
    final tempDir = await Directory.systemTemp.createTemp('ae_repo_');

    try {
      await _cloneRepo(repoUrl, tempDir.path);
      final content = await _buildIndex(name, repoUrl, tempDir.path);
      final fingerprint = _computeFingerprint(content);

      final meta = KnowMeta(
        name: name,
        source: KnowSource(
          type: KnowSourceType.repo,
          url: repoUrl,
          format: KnowFormat.repo,
        ),
        distillEngine: KnowDistillEngine.passthrough,
        tokenEstimate: content.length ~/ 4,
        fetchedAt: DateTime.now(),
        sha256: fingerprint,
      );

      return KnowPack(meta: meta, indexContent: content);
    } finally {
      await tempDir.delete(recursive: true);
    }
  }

  Future<void> _cloneRepo(final String url, final String targetDir) async {
    final result = await Process.run(
      'git',
      ['clone', '--depth', '1', '--single-branch', url, targetDir],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    if (result.exitCode != 0) {
      throw ProcessException(
        'git',
        ['clone'],
        'Git clone failed: ${result.stderr}',
        result.exitCode,
      );
    }
  }

  Future<String> _buildIndex(
    final String name,
    final String repoUrl,
    final String repoDir,
  ) async {
    final buffer = StringBuffer()
      ..writeln('# $name')
      ..writeln()
      ..writeln('> Extracted from $repoUrl')
      ..writeln();

    final readme = await _readIfExists(p.join(repoDir, 'README.md'));
    if (readme != null) {
      buffer
        ..writeln('## Overview')
        ..writeln()
        ..writeln(readme)
        ..writeln();
    }

    final changelog = await _readIfExists(p.join(repoDir, 'CHANGELOG.md'));
    if (changelog != null) {
      buffer
        ..writeln('## Recent Changes')
        ..writeln()
        ..writeln(_truncate(changelog, 3000))
        ..writeln();
    }

    final docsContent = await _scanDirectory(
      repoDir,
      'docs',
      ['.md', '.txt'],
      maxFiles: 10,
      maxPerFile: 5000,
    );
    if (docsContent.isNotEmpty) {
      buffer.writeln('## Documentation');
      for (final entry in docsContent.entries) {
        buffer
          ..writeln()
          ..writeln('### ${entry.key}')
          ..writeln()
          ..writeln(entry.value);
      }
      buffer.writeln();
    }

    var examplesContent = await _scanDirectory(
      repoDir,
      'examples',
      _codeExtensions,
      maxFiles: 5,
      maxPerFile: 3000,
    );
    if (examplesContent.isEmpty) {
      examplesContent = await _scanDirectory(
        repoDir,
        'example',
        _codeExtensions,
        maxFiles: 5,
        maxPerFile: 3000,
      );
    }
    if (examplesContent.isNotEmpty) {
      buffer.writeln('## Examples');
      for (final entry in examplesContent.entries) {
        buffer
          ..writeln()
          ..writeln('### ${entry.key}')
          ..writeln()
          ..writeln('```')
          ..writeln(entry.value)
          ..writeln('```');
      }
      buffer.writeln();
    }

    final structure = await _projectStructure(repoDir);
    if (structure.isNotEmpty) {
      buffer
        ..writeln('## Project Structure')
        ..writeln()
        ..writeln('```')
        ..writeln(structure)
        ..writeln('```')
        ..writeln();
    }

    return buffer.toString();
  }

  static const _codeExtensions = [
    '.dart',
    '.py',
    '.js',
    '.ts',
    '.go',
    '.rs',
  ];

  static const _ignoredDirs = {
    'node_modules',
    '.dart_tool',
    'build',
    '.git',
  };

  Future<String?> _readIfExists(final String filePath) async {
    final file = File(filePath);
    if (await file.exists()) return file.readAsString();
    return null;
  }

  String _truncate(final String content, final int maxLength) {
    if (content.length <= maxLength) return content;
    return '${content.substring(0, maxLength)}\n\n... (truncated)';
  }

  Future<Map<String, String>> _scanDirectory(
    final String repoDir,
    final String subDir,
    final List<String> extensions, {
    required final int maxFiles,
    required final int maxPerFile,
  }) async {
    final dir = Directory(p.join(repoDir, subDir));
    if (!await dir.exists()) return const {};

    final results = <String, String>{};
    var count = 0;

    await for (final entity in dir.list(recursive: true)) {
      if (count >= maxFiles) break;
      if (entity is! File) continue;
      if (!extensions.any((final ext) => entity.path.endsWith(ext))) continue;

      final relativePath = p.relative(entity.path, from: repoDir);
      final content = await entity.readAsString();
      results[relativePath] = _truncate(content, maxPerFile);
      count++;
    }
    return results;
  }

  Future<String> _projectStructure(final String repoDir) async {
    final buffer = StringBuffer();

    await for (final entity in Directory(repoDir).list()) {
      final name = p.basename(entity.path);
      if (name.startsWith('.')) continue;
      if (entity is Directory) {
        if (_ignoredDirs.contains(name)) continue;
        buffer.writeln('$name/');
      } else if (entity is File) {
        buffer.writeln(name);
      }
    }
    return buffer.toString();
  }

  String _computeFingerprint(final String content) {
    final bytes = utf8.encode(content);
    var sum = 0;
    for (final b in bytes) {
      sum = (sum + b) & 0xFFFFFFFF;
    }
    return sum.toRadixString(16).padLeft(8, '0');
  }
}

import 'dart:io';

import 'package:path/path.dart' as p;

import '../config/ae_core_config.dart';
import '../models/ae_result.dart';
import '../models/know.dart';
import '../models/know_matrix.dart';
import '../ports/know_extractor.dart';
import '../ports/know_store.dart';
import 'ae_know_service.dart';

class DefaultAeKnowService implements AeKnowService {
  const DefaultAeKnowService({
    required this.store,
    required this.extractors,
  });

  final KnowledgeStore store;
  final List<KnowledgeExtractor> extractors;

  KnowledgeExtractor? _findExtractor(final KnowSource source) {
    for (final e in extractors) {
      if (e.canHandle(source)) return e;
    }
    return null;
  }

  @override
  Future<AeResult<KnowBuildOutput>> build(final KnowBuildInput input) async {
    try {
      if (!KnowNamePattern.isValid(input.name)) {
        return AeResult.fail(
          code: 'invalid_name',
          message:
              'Name must match [a-z][a-z0-9_]* and be <= 64 chars: ${input.name}',
        );
      }

      final source = _resolveSource(input);
      if (source == null) {
        return AeResult.fail(
          code: 'missing_source',
          message: 'Provide url, repo_url, or local_path.',
        );
      }

      final extractor = _findExtractor(source);
      if (extractor == null) {
        return AeResult.fail(
          code: 'unsupported_source',
          message: 'No extractor can handle source type: ${source.type}'
              '${source.format != null ? ' format: ${source.format}' : ''}',
        );
      }

      final resolvedFormat = source.format ?? input.format ??
          (source.type == KnowSourceType.repo ? KnowFormat.repo : null);
      final sourceId = KnowCanonicalId.sourceId(
        source,
        resolvedFormat,
        input.distillEngine,
      );
      final typeStr = source.type.value;
      final formatStr = (resolvedFormat ?? KnowFormat.markdown).value;

      final existing = await store.findBySourceId(sourceId);

      if (existing != null) {
        switch (input.onConflict) {
          case KnowOnConflict.fail:
            return AeResult.fail(
              code: 'already_exists',
              message:
                  'Source already stored (canonical_source_id: $sourceId). '
                  'Use --on-conflict reuse|update|new_version or remove existing first.',
            );
          case KnowOnConflict.reuse:
            final pack = await store.loadCanonical(
              existing.canonicalPath,
              existing.contentSha,
            );
            if (pack == null) {
              return AeResult.fail(
                code: 'know_build_failed',
                message: 'Canonical pack missing for $sourceId',
              );
            }
            await store.attachAlias(
              input.name,
              sourceId,
              contentSha: existing.contentSha,
            );
            return AeResult.ok(KnowBuildOutput(
              name: input.name,
              meta: pack.meta,
              filesWritten: const [],
              noOp: true,
              canonicalSourceId: sourceId,
              canonicalPath: existing.canonicalPath,
              aliasAttached: true,
              conflictResolution: 'reused',
            ));
          case KnowOnConflict.update:
          case KnowOnConflict.newVersion:
            break;
        }
      }

      final pack = await extractor.extract(input.name, source);
      final contentSha = KnowCanonicalId.contentSha256(pack.indexContent);
      final metaWithCanonical = KnowMeta(
        name: pack.meta.name,
        version: pack.meta.version,
        source: pack.meta.source,
        distillEngine: pack.meta.distillEngine,
        tokenEstimate: pack.meta.tokenEstimate,
        tags: pack.meta.tags,
        fetchedAt: pack.meta.fetchedAt,
        sha256: pack.meta.sha256,
        sourceId: sourceId,
        contentSha: contentSha,
        aliases: pack.meta.aliases,
        artifacts: pack.meta.artifacts,
      );
      final packWithMeta = KnowPack(
        meta: metaWithCanonical,
        indexContent: pack.indexContent,
        patternsContent: pack.patternsContent,
        matrixYamlContent: pack.matrixYamlContent,
      );

      final filesWritten = await store.saveCanonical(
        sourceId,
        contentSha,
        packWithMeta,
        typeStr,
        formatStr,
      );
      await store.attachAlias(input.name, sourceId, contentSha: contentSha);

      return AeResult.ok(KnowBuildOutput(
        name: input.name,
        meta: metaWithCanonical,
        filesWritten: filesWritten,
        canonicalSourceId: sourceId,
        canonicalPath: '$typeStr/$formatStr/$sourceId',
        aliasAttached: true,
        conflictResolution: existing != null ? 'updated' : null,
      ));
    } catch (e) {
      return AeResult.fail(
        code: 'know_build_failed',
        message: 'Failed to build know pack: $e',
      );
    }
  }

  @override
  Future<AeResult<KnowShowOutput>> show(final KnowShowInput input) async {
    try {
      final pack = await store.load(input.name);
      if (pack == null) {
        return AeResult.fail(
          code: 'not_found',
          message: 'Know pack "${input.name}" not found.',
        );
      }

      String? matrixMd;
      if (pack.matrixYamlContent != null) {
        matrixMd = KnowFeatureMatrix.parseYamlString(pack.matrixYamlContent!)
            .renderMarkdown();
      }
      return AeResult.ok(KnowShowOutput(
        name: input.name,
        meta: pack.meta,
        content: pack.indexContent,
        matrixYaml: pack.matrixYamlContent,
        matrixMarkdown: matrixMd,
        normative: pack.meta.artifacts?.normative,
      ));
    } catch (e) {
      return AeResult.fail(
        code: 'know_show_failed',
        message: 'Failed to show know pack: $e',
      );
    }
  }

  @override
  Future<AeResult<KnowListOutput>> list(final KnowListInput input) async {
    try {
      final metas = await store.list();
      return AeResult.ok(KnowListOutput(packs: metas));
    } catch (e) {
      return AeResult.fail(
        code: 'know_list_failed',
        message: 'Failed to list know packs: $e',
      );
    }
  }

  @override
  Future<AeResult<void>> remove(final KnowRemoveInput input) async {
    try {
      final existed = await store.remove(input.name);
      if (!existed) {
        return AeResult.fail(
          code: 'not_found',
          message: 'Know pack "${input.name}" not found.',
        );
      }
      return AeResult.ok(null);
    } catch (e) {
      return AeResult.fail(
        code: 'know_remove_failed',
        message: 'Failed to remove know pack: $e',
      );
    }
  }

  @override
  Future<AeResult<KnowBuildOutput>> update(
      final KnowUpdateInput input) async {
    try {
      final existing = await store.load(input.name);
      if (existing == null) {
        return AeResult.fail(
          code: 'not_found',
          message: 'Know pack "${input.name}" not found.',
        );
      }

      final source = existing.meta.source;
      final extractor = _findExtractor(source);
      if (extractor == null) {
        return AeResult.fail(
          code: 'unsupported_source',
          message: 'No extractor can handle source type: ${source.type}',
        );
      }

      final pack = await extractor.extract(input.name, source);

      if (pack.meta.sha256 == existing.meta.sha256) {
        return AeResult.ok(KnowBuildOutput(
          name: input.name,
          meta: existing.meta,
          filesWritten: const [],
          noOp: true,
        ));
      }

      final filesWritten = await store.save(input.name, pack);

      return AeResult.ok(KnowBuildOutput(
        name: input.name,
        meta: pack.meta,
        filesWritten: filesWritten,
      ));
    } catch (e) {
      return AeResult.fail(
        code: 'know_update_failed',
        message: 'Failed to update know pack: $e',
      );
    }
  }

  @override
  Future<AeResult<KnowDiffOutput>> diff(final KnowDiffInput input) async {
    try {
      final fromPack = await store.load(input.fromName);
      if (fromPack == null) {
        return AeResult.fail(
          code: 'not_found',
          message: 'Know pack "${input.fromName}" not found.',
        );
      }

      final toPack = await store.load(input.toName);
      if (toPack == null) {
        return AeResult.fail(
          code: 'not_found',
          message: 'Know pack "${input.toName}" not found.',
        );
      }

      final fromSections = _parseSections(fromPack.indexContent);
      final toSections = _parseSections(toPack.indexContent);

      final allHeadings = <String>{...fromSections.keys, ...toSections.keys};
      final diffSections = <KnowDiffSection>[];

      var added = 0;
      var removed = 0;
      var changed = 0;

      for (final heading in allHeadings) {
        final fromContent = fromSections[heading];
        final toContent = toSections[heading];

        if (fromContent == null) {
          diffSections.add(KnowDiffSection(
            heading: heading,
            status: 'added',
            toContent: toContent,
          ));
          added++;
        } else if (toContent == null) {
          diffSections.add(KnowDiffSection(
            heading: heading,
            status: 'removed',
            fromContent: fromContent,
          ));
          removed++;
        } else if (fromContent != toContent) {
          diffSections.add(KnowDiffSection(
            heading: heading,
            status: 'changed',
            fromContent: fromContent,
            toContent: toContent,
          ));
          changed++;
        } else {
          diffSections.add(KnowDiffSection(
            heading: heading,
            status: 'unchanged',
          ));
        }
      }

      final summary =
          '$added added, $removed removed, $changed changed';

      return AeResult.ok(KnowDiffOutput(
        fromName: input.fromName,
        toName: input.toName,
        fromMeta: fromPack.meta,
        toMeta: toPack.meta,
        sections: diffSections,
        summary: summary,
      ));
    } catch (e) {
      return AeResult.fail(
        code: 'know_diff_failed',
        message: 'Failed to diff know packs: $e',
      );
    }
  }

  @override
  Future<AeResult<KnowMatrixInitOutput>> matrixInit(
    final KnowMatrixInitInput input,
  ) async {
    try {
      if (!KnowNamePattern.isValid(input.name)) {
        return AeResult.fail(
          code: 'invalid_name',
          message:
              'Name must match [a-z][a-z0-9_]* and be <= 64 chars: ${input.name}',
        );
      }
      if (input.columns.isEmpty) {
        return AeResult.fail(
          code: 'validation_error',
          message: 'At least one column is required (e.g. import,proof).',
        );
      }
      final root = await store.resolvePackContentRoot(input.name);
      if (root == null) {
        return AeResult.fail(
          code: 'not_found',
          message: 'Know pack "${input.name}" not found or has no content root.',
        );
      }
      final pack = await store.load(input.name);
      if (pack == null) {
        return AeResult.fail(
          code: 'not_found',
          message: 'Know pack "${input.name}" not found.',
        );
      }

      final cols = <KnowMatrixColumn>[];
      for (final id in input.columns) {
        final trimmed = id.trim();
        if (trimmed.isEmpty) continue;
        cols.add(KnowMatrixColumn(id: trimmed, label: _matrixColumnLabel(trimmed)));
      }
      if (cols.isEmpty) {
        return AeResult.fail(
          code: 'validation_error',
          message: 'No valid column ids after parsing.',
        );
      }

      final emptyCells = <String, String?>{
        for (final c in cols) c.id: '',
      };
      final matrix = KnowFeatureMatrix(
        version: 1,
        schema: KnowFeatureMatrix.defaultSchema,
        title: input.title ?? 'Feature coverage',
        statusDate: DateTime.now().toUtc().toIso8601String().split('T').first,
        columns: cols,
        columnLegend: {},
        features: [
          KnowMatrixFeature(
            id: 'example_feature',
            label: 'Example feature (replace or remove)',
            cells: emptyCells,
          ),
        ],
      );

      final yaml = matrix.toYamlString();
      final written = <String>[];
      final yPath = p.join(root, AeCoreConfig.knowMatrixFile);
      await File(yPath).writeAsString(yaml);
      written.add(yPath);
      final mdPath = p.join(root, AeCoreConfig.knowMatrixMarkdownFile);
      await File(mdPath).writeAsString(matrix.renderMarkdown());
      written.add(mdPath);

      KnowNormativeRef? norm;
      if (input.normativeKind != null &&
          input.normativeRef != null &&
          input.normativeKind!.isNotEmpty &&
          input.normativeRef!.isNotEmpty) {
        norm = KnowNormativeRef(
          kind: input.normativeKind!,
          ref: input.normativeRef!,
        );
      }

      final newMeta = KnowMeta(
        name: pack.meta.name,
        version: pack.meta.version,
        source: pack.meta.source,
        distillEngine: pack.meta.distillEngine,
        tokenEstimate: pack.meta.tokenEstimate,
        tags: pack.meta.tags,
        fetchedAt: pack.meta.fetchedAt,
        sha256: pack.meta.sha256,
        sourceId: pack.meta.sourceId,
        contentSha: pack.meta.contentSha,
        aliases: pack.meta.aliases,
        artifacts: KnowArtifacts(
          index: AeCoreConfig.knowIndexFile,
          matrix: AeCoreConfig.knowMatrixFile,
          normative: norm ?? pack.meta.artifacts?.normative,
        ),
      );
      await store.writePackMeta(input.name, newMeta);

      return AeResult.ok(
        KnowMatrixInitOutput(
          name: input.name,
          filesWritten: written,
          matrixYaml: yaml,
        ),
      );
    } catch (e) {
      return AeResult.fail(
        code: 'know_matrix_init_failed',
        message: 'Matrix init failed: $e',
      );
    }
  }

  static String _matrixColumnLabel(final String id) {
    if (id == 'n/a') return 'n/a';
    return id
        .split('_')
        .map(
          (final s) =>
              s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}',
        )
        .join(' ');
  }

  @override
  Future<AeResult<KnowMatrixScaffoldOutput>> matrixScaffold(
    final KnowMatrixScaffoldInput input,
  ) async {
    try {
      if (!KnowNamePattern.isValid(input.name)) {
        return AeResult.fail(
          code: 'invalid_name',
          message:
              'Name must match [a-z][a-z0-9_]* and be <= 64 chars: ${input.name}',
        );
      }
      final pack = await store.load(input.name);
      if (pack == null) {
        return AeResult.fail(
          code: 'not_found',
          message: 'Know pack "${input.name}" not found.',
        );
      }
      if (pack.matrixYamlContent == null) {
        return AeResult.fail(
          code: 'no_matrix',
          message:
              'Pack has no matrix.yaml. Run: ae know matrix init --name ${input.name} ...',
        );
      }
      final outPath = input.outFile != null && input.outFile!.isNotEmpty
          ? input.outFile!
          : p.join(input.repoPath, 'docs', 'feature_matrix.yaml');
      final file = File(outPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(pack.matrixYamlContent!);
      return AeResult.ok(
        KnowMatrixScaffoldOutput(
          writtenPath: outPath,
          matrixYaml: pack.matrixYamlContent!,
        ),
      );
    } catch (e) {
      return AeResult.fail(
        code: 'know_matrix_scaffold_failed',
        message: 'Matrix scaffold failed: $e',
      );
    }
  }

  @override
  Future<AeResult<KnowMatrixCompareOutput>> matrixCompare(
    final KnowMatrixCompareInput input,
  ) async {
    try {
      Future<String?> loadYamlSide({
        required final String? name,
        required final String? file,
      }) async {
        if (file != null && file.isNotEmpty) {
          final f = File(file);
          if (!await f.exists()) {
            throw StateError('File not found: $file');
          }
          return f.readAsString();
        }
        if (name != null && name.isNotEmpty) {
          final pack = await store.load(name);
          if (pack?.matrixYamlContent == null) {
            throw StateError('Know pack "$name" has no matrix.yaml');
          }
          return pack!.matrixYamlContent;
        }
        return null;
      }

      final fromYaml = await loadYamlSide(
        name: input.fromName,
        file: input.fromFile,
      );
      final toYaml = await loadYamlSide(
        name: input.toName,
        file: input.toFile,
      );
      if (fromYaml == null || toYaml == null) {
        return AeResult.fail(
          code: 'validation_error',
          message:
              'Provide --from-name or --from-file and --to-name or --to-file.',
        );
      }

      final fromLabel = input.fromFile ?? input.fromName ?? 'from';
      final toLabel = input.toFile ?? input.toName ?? 'to';
      final a = KnowFeatureMatrix.parseYamlString(fromYaml);
      final b = KnowFeatureMatrix.parseYamlString(toYaml);
      final diff = diffKnowMatrices(a, b);
      return AeResult.ok(
        KnowMatrixCompareOutput(
          fromLabel: fromLabel,
          toLabel: toLabel,
          result: diff,
        ),
      );
    } catch (e) {
      return AeResult.fail(
        code: 'know_matrix_compare_failed',
        message: 'Matrix compare failed: $e',
      );
    }
  }

  @override
  Future<AeResult<KnowPlanOutput>> plan(final KnowPlanInput input) async {
    try {
      final pack = await store.load(input.name);
      if (pack == null) {
        return AeResult.fail(
          code: 'not_found',
          message: 'Know pack "${input.name}" not found.',
        );
      }
      final buf = StringBuffer()
        ..writeln('# Implementation plan: ${input.name}')
        ..writeln()
        ..writeln('## Domain knowledge (index)')
        ..writeln()
        ..writeln(pack.indexContent);
      if (pack.matrixYamlContent != null) {
        buf
          ..writeln()
          ..writeln('## Feature matrix')
          ..writeln()
          ..writeln(
            KnowFeatureMatrix.parseYamlString(pack.matrixYamlContent!)
                .renderMarkdown(),
          );
      }
      if (pack.meta.artifacts?.normative != null) {
        final n = pack.meta.artifacts!.normative!;
        buf
          ..writeln()
          ..writeln('## Normative reference')
          ..writeln()
          ..writeln('- **${n.kind}**: ${n.ref}');
      }
      return AeResult.ok(
        KnowPlanOutput(name: input.name, planMarkdown: buf.toString()),
      );
    } catch (e) {
      return AeResult.fail(
        code: 'know_plan_failed',
        message: 'Plan export failed: $e',
      );
    }
  }

  static bool _urlLooksPdf(final String? url) {
    if (url == null || url.isEmpty) return false;
    final lower = url.toLowerCase();
    return lower.endsWith('.pdf') || lower.contains('/pdf/');
  }

  KnowSource? _resolveSource(final KnowBuildInput input) {
    if (input.localPath != null && input.localPath!.isNotEmpty) {
      return KnowSource(type: KnowSourceType.local, path: input.localPath);
    }
    if (input.url != null && input.url!.isNotEmpty) {
      KnowFormat? format = input.format;
      if (format == null && _urlLooksPdf(input.url)) {
        format = KnowFormat.pdf;
      }
      return KnowSource(
        type: KnowSourceType.url,
        url: input.url,
        format: format,
      );
    }
    if (input.repoUrl != null && input.repoUrl!.isNotEmpty) {
      return KnowSource(type: KnowSourceType.repo, url: input.repoUrl);
    }
    return null;
  }

  Map<String, String> _parseSections(final String content) {
    final sections = <String, String>{};
    final lines = content.split('\n');
    String currentHeading = '_preamble';
    final buffer = StringBuffer();

    for (final line in lines) {
      if (line.startsWith('## ')) {
        sections[currentHeading] = buffer.toString().trim();
        currentHeading = line.substring(3).trim();
        buffer.clear();
      } else {
        buffer.writeln(line);
      }
    }
    sections[currentHeading] = buffer.toString().trim();
    return sections;
  }
}

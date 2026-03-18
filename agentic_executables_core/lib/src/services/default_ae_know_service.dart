import '../models/ae_result.dart';
import '../models/know.dart';
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

      if (await store.exists(input.name)) {
        return AeResult.fail(
          code: 'already_exists',
          message:
              'Know pack "${input.name}" already exists. Use "update" to refresh.',
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

      final pack = await extractor.extract(input.name, source);
      final filesWritten = await store.save(input.name, pack);

      return AeResult.ok(KnowBuildOutput(
        name: input.name,
        meta: pack.meta,
        filesWritten: filesWritten,
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

      return AeResult.ok(KnowShowOutput(
        name: input.name,
        meta: pack.meta,
        content: pack.indexContent,
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

  static bool _urlLooksPdf(final String? url) {
    if (url == null || url.isEmpty) return false;
    final lower = url.toLowerCase();
    return lower.endsWith('.pdf') || lower.contains('/pdf/');
  }

  KnowSource? _resolveSource(final KnowBuildInput input) {
    if (input.url != null) {
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
    if (input.repoUrl != null) {
      return KnowSource(type: KnowSourceType.repo, url: input.repoUrl);
    }
    if (input.localPath != null) {
      return KnowSource(type: KnowSourceType.local, path: input.localPath);
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

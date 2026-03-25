import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'know_matrix.dart';

enum KnowOnConflict {
  reuse('reuse'),
  update('update'),
  fail('fail'),
  newVersion('new_version');

  const KnowOnConflict(this.value);
  final String value;

  static KnowOnConflict fromString(final String value) => switch (value) {
        'reuse' => KnowOnConflict.reuse,
        'update' => KnowOnConflict.update,
        'fail' => KnowOnConflict.fail,
        'new_version' => KnowOnConflict.newVersion,
        _ => throw ArgumentError('Invalid on_conflict: $value'),
      };
}

enum KnowSourceType {
  url('url'),
  repo('repo'),
  local('local');

  const KnowSourceType(this.value);

  final String value;

  static KnowSourceType fromString(final String value) => switch (value) {
        'url' => KnowSourceType.url,
        'repo' => KnowSourceType.repo,
        'local' => KnowSourceType.local,
        _ => throw ArgumentError('Invalid know source type: $value'),
      };

  @override
  String toString() => value;
}

enum KnowFormat {
  llmsTxt('llms_txt'),
  html('html'),
  markdown('markdown'),
  pdf('pdf'),
  repo('repo');

  const KnowFormat(this.value);

  final String value;

  static KnowFormat fromString(final String value) => switch (value) {
        'llms_txt' => KnowFormat.llmsTxt,
        'html' => KnowFormat.html,
        'markdown' => KnowFormat.markdown,
        'pdf' => KnowFormat.pdf,
        'repo' => KnowFormat.repo,
        _ => throw ArgumentError('Invalid know format: $value'),
      };

  @override
  String toString() => value;
}

enum KnowDistillEngine {
  passthrough('passthrough'),
  inference('inference');

  const KnowDistillEngine(this.value);

  final String value;

  static KnowDistillEngine fromString(final String value) => switch (value) {
        'passthrough' => KnowDistillEngine.passthrough,
        'inference' => KnowDistillEngine.inference,
        _ => throw ArgumentError('Invalid distill engine: $value'),
      };

  @override
  String toString() => value;
}

class KnowSource {
  const KnowSource({required this.type, this.url, this.path, this.format});

  final KnowSourceType type;
  final String? url;
  final String? path;
  final KnowFormat? format;

  Map<String, dynamic> toJson() => {
        'type': type.value,
        if (url != null) 'url': url,
        if (path != null) 'path': path,
        if (format != null) 'format': format!.value,
      };

  String toYamlString() {
    final buffer = StringBuffer()..writeln('  type: ${type.value}');
    if (url != null) buffer.writeln('  url: "$url"');
    if (path != null) buffer.writeln('  path: "$path"');
    if (format != null) buffer.writeln('  format: ${format!.value}');
    return buffer.toString();
  }

  factory KnowSource.fromMap(final Map<dynamic, dynamic> map) => KnowSource(
        type: KnowSourceType.fromString(map['type']?.toString() ?? 'url'),
        url: map['url']?.toString(),
        path: map['path']?.toString(),
        format: map['format'] != null
            ? KnowFormat.fromString(map['format'].toString())
            : null,
      );

  /// Stable string for hashing: type + normalized locator + format + distill.
  String normalizedIdentity(final KnowFormat? resolvedFormat) {
    final fmt = resolvedFormat ?? format;
    final loc = type == KnowSourceType.url
        ? (url ?? '')
        : type == KnowSourceType.repo
            ? (url ?? '')
            : (path ?? '');
    return '${type.value}\t$loc\t${fmt?.value ?? ''}';
  }
}

/// Computes canonical source and content hashes for deduplication.
class KnowCanonicalId {
  KnowCanonicalId._();

  static String sourceId(
    final KnowSource source,
    final KnowFormat? resolvedFormat,
    final KnowDistillEngine engine,
  ) {
    final raw = '${source.normalizedIdentity(resolvedFormat)}\t${engine.value}';
    final bytes = utf8.encode(raw);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  static String contentSha256(final String content) {
    final digest = sha256.convert(utf8.encode(content));
    return digest.toString();
  }
}

/// Optional pointer to normative spec (URL or local path).
class KnowNormativeRef {
  const KnowNormativeRef({required this.kind, required this.ref});

  final String kind;
  final String ref;

  Map<String, dynamic> toJson() => {'kind': kind, 'ref': ref};

  static KnowNormativeRef? fromMap(final Map<dynamic, dynamic>? map) {
    if (map == null) return null;
    final k = map['kind']?.toString();
    final r = map['ref']?.toString();
    if (k == null || r == null) return null;
    return KnowNormativeRef(kind: k, ref: r);
  }
}

/// Declares optional know pack artifacts (paths relative to pack content root).
class KnowArtifacts {
  const KnowArtifacts({this.index, this.matrix, this.normative});

  final String? index;
  final String? matrix;
  final KnowNormativeRef? normative;

  Map<String, dynamic> toJson() => {
        if (index != null) 'index': index,
        if (matrix != null) 'matrix': matrix,
        if (normative != null) 'normative': normative!.toJson(),
      };

  static KnowArtifacts? fromMap(final Map<dynamic, dynamic>? map) {
    if (map == null) return null;
    return KnowArtifacts(
      index: map['index']?.toString(),
      matrix: map['matrix']?.toString(),
      normative: KnowNormativeRef.fromMap(
        map['normative'] is Map ? map['normative'] as Map<dynamic, dynamic> : null,
      ),
    );
  }
}

class KnowMeta {
  const KnowMeta({
    required this.name,
    this.version,
    required this.source,
    required this.distillEngine,
    this.tokenEstimate,
    this.tags = const [],
    required this.fetchedAt,
    this.sha256,
    this.sourceId,
    this.contentSha,
    this.aliases = const [],
    this.artifacts,
  });

  final String name;
  final String? version;
  final KnowSource source;
  final KnowDistillEngine distillEngine;
  final int? tokenEstimate;
  final List<String> tags;
  final DateTime fetchedAt;
  final String? sha256;
  final String? sourceId;
  final String? contentSha;
  final List<String> aliases;
  final KnowArtifacts? artifacts;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (version != null) 'version': version,
        'source': source.toJson(),
        'distill_engine': distillEngine.value,
        if (tokenEstimate != null) 'token_estimate': tokenEstimate,
        'tags': tags,
        'fetched_at': fetchedAt.toUtc().toIso8601String(),
        if (sha256 != null) 'sha256': sha256,
        if (sourceId != null) 'source_id': sourceId,
        if (contentSha != null) 'content_sha': contentSha,
        if (aliases.isNotEmpty) 'aliases': aliases,
        if (artifacts != null) 'artifacts': artifacts!.toJson(),
      };

  String toYamlString() {
    final buffer = StringBuffer()
      ..writeln('name: $name')
      ..writeln('version: "${version ?? ""}"')
      ..writeln('source:')
      ..write(source.toYamlString())
      ..writeln('distill:')
      ..writeln('  engine: ${distillEngine.value}')
      ..writeln('  token_estimate: ${tokenEstimate ?? 0}')
      ..writeln('fetched_at: "${fetchedAt.toUtc().toIso8601String()}"');
    if (sha256 != null) buffer.writeln('sha256: "$sha256"');
    if (sourceId != null) buffer.writeln('source_id: $sourceId');
    if (contentSha != null) buffer.writeln('content_sha: $contentSha');
    if (tags.isNotEmpty) {
      buffer.writeln('tags: [${tags.join(", ")}]');
    } else {
      buffer.writeln('tags: []');
    }
    if (aliases.isNotEmpty) {
      buffer.writeln('aliases: [${aliases.join(", ")}]');
    } else {
      buffer.writeln('aliases: []');
    }
    if (artifacts != null) {
      buffer.writeln('artifacts:');
      if (artifacts!.index != null) {
        buffer.writeln('  index: "${artifacts!.index}"');
      }
      if (artifacts!.matrix != null) {
        buffer.writeln('  matrix: "${artifacts!.matrix}"');
      }
      if (artifacts!.normative != null) {
        buffer.writeln('  normative:');
        buffer.writeln('    kind: ${artifacts!.normative!.kind}');
        buffer.writeln('    ref: "${artifacts!.normative!.ref}"');
      }
    }
    return buffer.toString();
  }

  factory KnowMeta.fromMap(final Map<dynamic, dynamic> map) {
    final sourceRaw = map['source'];
    final source = sourceRaw is Map
        ? KnowSource.fromMap(sourceRaw)
        : const KnowSource(type: KnowSourceType.url);

    final distillRaw = map['distill'];
    final distillEngine = distillRaw is Map
        ? KnowDistillEngine.fromString(
            distillRaw['engine']?.toString() ?? 'passthrough',
          )
        : KnowDistillEngine.passthrough;
    final tokenEstimate =
        distillRaw is Map ? (distillRaw['token_estimate'] as int?) : null;

    final tagsRaw = map['tags'];
    final tags = tagsRaw is List
        ? tagsRaw.map((final e) => e.toString()).toList(growable: false)
        : const <String>[];

    final aliasesRaw = map['aliases'];
    final aliases = aliasesRaw is List
        ? aliasesRaw.map((final e) => e.toString()).toList(growable: false)
        : const <String>[];

    final fetchedAtRaw = map['fetched_at']?.toString();
    final fetchedAt = fetchedAtRaw != null
        ? DateTime.tryParse(fetchedAtRaw) ?? DateTime.now()
        : DateTime.now();

    final artifactsRaw = map['artifacts'];
    final artifacts = artifactsRaw is Map
        ? KnowArtifacts.fromMap(artifactsRaw)
        : null;

    return KnowMeta(
      name: map['name']?.toString() ?? '',
      version: map['version']?.toString(),
      source: source,
      distillEngine: distillEngine,
      tokenEstimate: tokenEstimate,
      tags: tags,
      fetchedAt: fetchedAt,
      sha256: map['sha256']?.toString(),
      sourceId: map['source_id']?.toString(),
      contentSha: map['content_sha']?.toString(),
      aliases: aliases,
      artifacts: artifacts,
    );
  }
}

/// Reference to a canonical pack by source identity.
class KnowCanonicalRef {
  const KnowCanonicalRef({
    required this.sourceId,
    required this.contentSha,
    required this.canonicalPath,
    required this.aliases,
  });

  final String sourceId;
  final String contentSha;
  final String canonicalPath;
  final List<String> aliases;
}

/// Alias resolution: name -> canonical location.
class KnowAliasRef {
  const KnowAliasRef({
    required this.sourceId,
    required this.canonicalPath,
    this.contentSha,
  });

  final String sourceId;
  final String canonicalPath;
  final String? contentSha;
}

class KnowPack {
  const KnowPack({
    required this.meta,
    required this.indexContent,
    this.patternsContent,
    this.matrixYamlContent,
  });

  final KnowMeta meta;
  final String indexContent;
  final String? patternsContent;
  /// Canonical [KnowFeatureMatrix] YAML (optional); see [KnowFeatureMatrix].
  final String? matrixYamlContent;
}

class KnowBuildInput {
  const KnowBuildInput({
    required this.name,
    this.url,
    this.repoUrl,
    this.localPath,
    this.hubPath,
    this.format,
    this.onConflict = KnowOnConflict.reuse,
    this.distillEngine = KnowDistillEngine.passthrough,
  });

  final String name;
  final String? url;
  final String? repoUrl;
  final String? localPath;
  final String? hubPath;
  final KnowFormat? format;
  final KnowOnConflict onConflict;
  final KnowDistillEngine distillEngine;
}

class KnowBuildOutput {
  const KnowBuildOutput({
    required this.name,
    required this.meta,
    required this.filesWritten,
    this.noOp = false,
    this.canonicalSourceId,
    this.canonicalPath,
    this.aliasAttached = false,
    this.conflictResolution,
  });

  final String name;
  final KnowMeta meta;
  final List<String> filesWritten;
  final bool noOp;
  final String? canonicalSourceId;
  final String? canonicalPath;
  final bool aliasAttached;
  final String? conflictResolution;

  Map<String, dynamic> toJson() => {
        'name': name,
        'meta': meta.toJson(),
        'files_written': filesWritten,
        'no_op': noOp,
        if (canonicalSourceId != null) 'canonical_source_id': canonicalSourceId,
        if (canonicalPath != null) 'canonical_path': canonicalPath,
        'alias_attached': aliasAttached,
        if (conflictResolution != null) 'conflict_resolution': conflictResolution,
      };
}

class KnowShowInput {
  const KnowShowInput({required this.name, this.hubPath});

  final String name;
  final String? hubPath;
}

class KnowShowOutput {
  const KnowShowOutput({
    required this.name,
    required this.meta,
    required this.content,
    this.matrixYaml,
    this.matrixMarkdown,
    this.normative,
  });

  final String name;
  final KnowMeta meta;
  final String content;
  final String? matrixYaml;
  final String? matrixMarkdown;
  final KnowNormativeRef? normative;

  Map<String, dynamic> toJson() => {
        'name': name,
        'meta': meta.toJson(),
        'content': content,
        if (matrixYaml != null) 'matrix_yaml': matrixYaml,
        if (matrixMarkdown != null) 'matrix_markdown': matrixMarkdown,
        if (normative != null) 'normative': normative!.toJson(),
      };
}

class KnowListInput {
  const KnowListInput({this.hubPath});

  final String? hubPath;
}

class KnowListOutput {
  const KnowListOutput({required this.packs});

  final List<KnowMeta> packs;

  Map<String, dynamic> toJson() => {
        'packs': packs.map((final e) => e.toJson()).toList(growable: false),
        'count': packs.length,
      };
}

class KnowRemoveInput {
  const KnowRemoveInput({required this.name, this.hubPath});

  final String name;
  final String? hubPath;
}

class KnowUpdateInput {
  const KnowUpdateInput({required this.name, this.hubPath});

  final String name;
  final String? hubPath;
}

class KnowDiffInput {
  const KnowDiffInput({
    required this.fromName,
    required this.toName,
    this.hubPath,
  });

  final String fromName;
  final String toName;
  final String? hubPath;
}

class KnowDiffOutput {
  const KnowDiffOutput({
    required this.fromName,
    required this.toName,
    required this.fromMeta,
    required this.toMeta,
    required this.sections,
    required this.summary,
  });

  final String fromName;
  final String toName;
  final KnowMeta fromMeta;
  final KnowMeta toMeta;
  final List<KnowDiffSection> sections;
  final String summary;

  Map<String, dynamic> toJson() => {
        'from_name': fromName,
        'to_name': toName,
        'from_meta': fromMeta.toJson(),
        'to_meta': toMeta.toJson(),
        'sections':
            sections.map((final s) => s.toJson()).toList(growable: false),
        'summary': summary,
      };
}

class KnowDiffSection {
  const KnowDiffSection({
    required this.heading,
    required this.status,
    this.fromContent,
    this.toContent,
  });

  final String heading;
  final String status;
  final String? fromContent;
  final String? toContent;

  Map<String, dynamic> toJson() => {
        'heading': heading,
        'status': status,
        if (fromContent != null) 'from_content': fromContent,
        if (toContent != null) 'to_content': toContent,
      };
}

/// Result of migrating legacy name-keyed packs to canonical layout.
class KnowMigrationReport {
  const KnowMigrationReport({
    this.merged = const [],
    this.aliasesCreated = const [],
    this.errors = const [],
    this.removedLegacy = const [],
  });

  final List<KnowMigrationMerge> merged;
  final List<KnowMigrationAlias> aliasesCreated;
  final List<KnowMigrationError> errors;
  final List<String> removedLegacy;

  Map<String, dynamic> toJson() => {
        'merged': merged.map((e) => e.toJson()).toList(growable: false),
        'aliases_created': aliasesCreated.map((e) => e.toJson()).toList(growable: false),
        'errors': errors.map((e) => e.toJson()).toList(growable: false),
        'removed_legacy': removedLegacy,
      };
}

class KnowMigrationMerge {
  const KnowMigrationMerge({
    required this.sourceId,
    required this.names,
  });
  final String sourceId;
  final List<String> names;
  Map<String, dynamic> toJson() => {'source_id': sourceId, 'names': names};
}

class KnowMigrationAlias {
  const KnowMigrationAlias({required this.name, required this.sourceId});
  final String name;
  final String sourceId;
  Map<String, dynamic> toJson() => {'name': name, 'source_id': sourceId};
}

class KnowMigrationError {
  const KnowMigrationError({required this.name, required this.message});
  final String name;
  final String message;
  Map<String, dynamic> toJson() => {'name': name, 'message': message};
}

/// Create or overwrite hub [matrix.yaml] template for a pack.
class KnowMatrixInitInput {
  const KnowMatrixInitInput({
    required this.name,
    required this.columns,
    this.title,
    this.hubPath,
    this.normativeKind,
    this.normativeRef,
  });

  final String name;
  final List<String> columns;
  final String? title;
  final String? hubPath;
  final String? normativeKind;
  final String? normativeRef;
}

class KnowMatrixInitOutput {
  const KnowMatrixInitOutput({
    required this.name,
    required this.filesWritten,
    required this.matrixYaml,
  });

  final String name;
  final List<String> filesWritten;
  final String matrixYaml;

  Map<String, dynamic> toJson() => {
        'name': name,
        'files_written': filesWritten,
        'matrix_yaml': matrixYaml,
      };
}

/// Copy hub matrix template into a repo path (repo artifact).
class KnowMatrixScaffoldInput {
  const KnowMatrixScaffoldInput({
    required this.name,
    required this.repoPath,
    this.outFile,
    this.hubPath,
  });

  final String name;
  final String repoPath;
  final String? outFile;
  final String? hubPath;
}

class KnowMatrixScaffoldOutput {
  const KnowMatrixScaffoldOutput({
    required this.writtenPath,
    required this.matrixYaml,
  });

  final String writtenPath;
  final String matrixYaml;

  Map<String, dynamic> toJson() => {
        'written_path': writtenPath,
        'matrix_yaml': matrixYaml,
      };
}

/// Structural diff of two [matrix.yaml] documents (files and/or hub pack names).
class KnowMatrixCompareInput {
  const KnowMatrixCompareInput({
    this.fromName,
    this.toName,
    this.fromFile,
    this.toFile,
    this.hubPath,
  });

  final String? fromName;
  final String? toName;
  final String? fromFile;
  final String? toFile;
  final String? hubPath;
}

class KnowMatrixCompareOutput {
  const KnowMatrixCompareOutput({
    required this.fromLabel,
    required this.toLabel,
    required this.result,
  });

  final String fromLabel;
  final String toLabel;
  final KnowMatrixDiffResult result;

  Map<String, dynamic> toJson() => {
        'from_label': fromLabel,
        'to_label': toLabel,
        'diff': result.toJson(),
      };
}

class KnowPlanInput {
  const KnowPlanInput({required this.name, this.hubPath});

  final String name;
  final String? hubPath;
}

class KnowPlanOutput {
  const KnowPlanOutput({
    required this.name,
    required this.planMarkdown,
  });

  final String name;
  final String planMarkdown;

  Map<String, dynamic> toJson() => {
        'name': name,
        'plan_markdown': planMarkdown,
      };
}

class KnowNamePattern {
  KnowNamePattern._();

  static final RegExp pattern = RegExp(r'^[a-z][a-z0-9_]*$');

  static bool isValid(final String name) =>
      name.isNotEmpty && name.length <= 64 && pattern.hasMatch(name);
}

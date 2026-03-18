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
  });

  final String name;
  final String? version;
  final KnowSource source;
  final KnowDistillEngine distillEngine;
  final int? tokenEstimate;
  final List<String> tags;
  final DateTime fetchedAt;
  final String? sha256;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (version != null) 'version': version,
        'source': source.toJson(),
        'distill_engine': distillEngine.value,
        if (tokenEstimate != null) 'token_estimate': tokenEstimate,
        'tags': tags,
        'fetched_at': fetchedAt.toUtc().toIso8601String(),
        if (sha256 != null) 'sha256': sha256,
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
    if (tags.isNotEmpty) {
      buffer.writeln('tags: [${tags.join(", ")}]');
    } else {
      buffer.writeln('tags: []');
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

    final fetchedAtRaw = map['fetched_at']?.toString();
    final fetchedAt = fetchedAtRaw != null
        ? DateTime.tryParse(fetchedAtRaw) ?? DateTime.now()
        : DateTime.now();

    return KnowMeta(
      name: map['name']?.toString() ?? '',
      version: map['version']?.toString(),
      source: source,
      distillEngine: distillEngine,
      tokenEstimate: tokenEstimate,
      tags: tags,
      fetchedAt: fetchedAt,
      sha256: map['sha256']?.toString(),
    );
  }
}

class KnowPack {
  const KnowPack({
    required this.meta,
    required this.indexContent,
    this.patternsContent,
  });

  final KnowMeta meta;
  final String indexContent;
  final String? patternsContent;
}

class KnowBuildInput {
  const KnowBuildInput({
    required this.name,
    this.url,
    this.repoUrl,
    this.localPath,
    this.hubPath,
    this.format,
  });

  final String name;
  final String? url;
  final String? repoUrl;
  final String? localPath;
  final String? hubPath;
  final KnowFormat? format;
}

class KnowBuildOutput {
  const KnowBuildOutput({
    required this.name,
    required this.meta,
    required this.filesWritten,
    this.noOp = false,
  });

  final String name;
  final KnowMeta meta;
  final List<String> filesWritten;
  final bool noOp;

  Map<String, dynamic> toJson() => {
        'name': name,
        'meta': meta.toJson(),
        'files_written': filesWritten,
        'no_op': noOp,
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
  });

  final String name;
  final KnowMeta meta;
  final String content;

  Map<String, dynamic> toJson() => {
        'name': name,
        'meta': meta.toJson(),
        'content': content,
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

class KnowNamePattern {
  KnowNamePattern._();

  static final RegExp pattern = RegExp(r'^[a-z][a-z0-9_]*$');

  static bool isValid(final String name) =>
      name.isNotEmpty && name.length <= 64 && pattern.hasMatch(name);
}

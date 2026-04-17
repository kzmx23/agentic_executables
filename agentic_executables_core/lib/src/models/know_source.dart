/// Lightweight source-descriptor types carried over from the 2.x `know`
/// subsystem (hard-cut in 3.0.1) so the surviving source adapters
/// (`passthrough_source`, `url_html_source`, `pdf_extractor`, `repo_extractor`)
/// remain usable as concrete classes.
///
/// The proper `KnowledgeSource` port (spec §5.1 — `KnowSourceSpec` /
/// `RawContent`) will be reintroduced in a later phase with distillation
/// wiring; at that point these types collapse into / are replaced by the
/// new port's payloads.
library;

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
}

/// Optional pointer to normative spec (URL or local path).
class KnowNormativeRef {
  const KnowNormativeRef({required this.kind, required this.ref});

  final String kind;
  final String ref;
}

/// Declares optional know pack artifacts (paths relative to pack content root).
class KnowArtifacts {
  const KnowArtifacts({this.index, this.matrix, this.normative});

  final String? index;
  final String? matrix;
  final KnowNormativeRef? normative;
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
  final String? matrixYamlContent;
}

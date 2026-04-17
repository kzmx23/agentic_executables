import 'canonical_matrix.dart';

class DistillationSourceArtifact {
  const DistillationSourceArtifact({
    required this.name,
    required this.language,
    required this.files,
    required this.structuralSummary,
  });

  final String name;
  final String language;
  final List<String> files;
  final String structuralSummary;

  Map<String, dynamic> toJson() => {
        'name': name,
        'language': language,
        'files': files,
        'structural_summary': structuralSummary,
      };

  factory DistillationSourceArtifact.fromMap(
    final Map<dynamic, dynamic> map,
  ) {
    final filesRaw = map['files'];
    final files = filesRaw is List
        ? filesRaw.map((final v) => v.toString()).toList(growable: false)
        : <String>[];
    return DistillationSourceArtifact(
      name: map['name']?.toString() ?? '',
      language: map['language']?.toString() ?? '',
      files: files,
      structuralSummary: map['structural_summary']?.toString() ?? '',
    );
  }
}

class DistillationTask {
  const DistillationTask({
    required this.conceptId,
    required this.conceptVersion,
    required this.sourceArtifact,
    this.matrixSeedRows = const [],
    this.examples = const [],
  });

  static const String schemaIn = 'ae.distillation.task.v1';
  static const String schemaOut = 'ae.canonical.draft.v1';

  final String conceptId;
  final int conceptVersion;
  final DistillationSourceArtifact sourceArtifact;
  final List<CanonicalFeature> matrixSeedRows;

  /// Few-shot examples from prior accepted distillations (free-form maps).
  final List<Map<String, dynamic>> examples;

  Map<String, dynamic> toJson() => {
        'task': 'distill_pack',
        'schema_in': schemaIn,
        'schema_out': schemaOut,
        'concept_id': conceptId,
        'concept_version': conceptVersion,
        'source_artifact': sourceArtifact.toJson(),
        'matrix_seed_rows':
            matrixSeedRows.map((final f) => f.toJson()).toList(growable: false),
        'examples': examples,
      };

  factory DistillationTask.fromMap(final Map<dynamic, dynamic> map) {
    final srcRaw = map['source_artifact'];
    final src = srcRaw is Map
        ? DistillationSourceArtifact.fromMap(srcRaw)
        : const DistillationSourceArtifact(
            name: '',
            language: '',
            files: [],
            structuralSummary: '',
          );
    final seedRaw = map['matrix_seed_rows'];
    final seed = seedRaw is List
        ? seedRaw
            .whereType<Map>()
            .map(CanonicalFeature.fromMap)
            .toList(growable: false)
        : <CanonicalFeature>[];
    final examplesRaw = map['examples'];
    final examples = examplesRaw is List
        ? examplesRaw
            .whereType<Map>()
            .map((final e) => Map<String, dynamic>.from(e))
            .toList(growable: false)
        : <Map<String, dynamic>>[];
    return DistillationTask(
      conceptId: map['concept_id']?.toString() ?? '',
      conceptVersion: (map['concept_version'] as int?) ?? 1,
      sourceArtifact: src,
      matrixSeedRows: seed,
      examples: examples,
    );
  }
}

class DistillationOutput {
  const DistillationOutput({
    required this.conceptId,
    required this.conceptVersion,
    required this.indexMd,
    required this.matrix,
    this.patternsMd,
  });

  final String conceptId;
  final int conceptVersion;
  final String indexMd;
  final CanonicalMatrix matrix;
  final String? patternsMd;

  Map<String, dynamic> toJson() => {
        'schema': DistillationTask.schemaOut,
        'concept_id': conceptId,
        'concept_version': conceptVersion,
        'index_md': indexMd,
        'matrix': matrix.toJson(),
        if (patternsMd != null) 'patterns_md': patternsMd,
      };

  factory DistillationOutput.fromMap(final Map<dynamic, dynamic> map) {
    final schema = map['schema']?.toString();
    if (schema != DistillationTask.schemaOut) {
      throw ArgumentError(
        'Expected schema ${DistillationTask.schemaOut}, got $schema',
      );
    }
    final matrixRaw = map['matrix'];
    final matrix = matrixRaw is Map
        ? CanonicalMatrix.fromMap(matrixRaw)
        : throw ArgumentError('DistillationOutput requires "matrix"');
    return DistillationOutput(
      conceptId: map['concept_id']?.toString() ?? '',
      conceptVersion: (map['concept_version'] as int?) ?? 1,
      indexMd: map['index_md']?.toString() ?? '',
      matrix: matrix,
      patternsMd: map['patterns_md']?.toString(),
    );
  }
}

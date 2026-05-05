import 'dart:convert';

import 'feature_id.dart';

const String canonicalMatrixSchema = 'ae.canonical_matrix.v1';

/// Provenance value written into a feature row's `cells['provenance']` by
/// `ae canonical accept-concept` to mark the row as a promoted proposal
/// (not a symbol-derived row from `scaffold`). `scaffoldUpdate` skips rows
/// with this provenance when computing tombstones — see Q5/Q9 in the
/// id-stability design FAQ.
const String acceptedConceptProvenance = 'accepted_concept';

class CanonicalColumn {
  const CanonicalColumn({required this.id, required this.type});

  final String id;
  final String type;

  Map<String, dynamic> toJson() => {'id': id, 'type': type};

  factory CanonicalColumn.fromMap(final Map<dynamic, dynamic> map) =>
      CanonicalColumn(
        id: map['id']?.toString() ?? '',
        type: map['type']?.toString() ?? 'text',
      );
}

class CanonicalFeature {
  const CanonicalFeature({
    required this.id,
    required this.cells,
    this.removed = false,
  });

  final FeatureId id;
  final Map<String, String> cells;

  /// Marks this row as removed from the source artifact while preserving its
  /// spec/invariant text. Set by `ae canonical scaffold --update` when a
  /// previously-scaffolded symbol is no longer in the source. Distill MUST
  /// continue to enrich removed rows (their id is in the pre-distill matrix).
  /// See specs/2026-04-27-canonical-id-stability-design.md Q3.
  final bool removed;

  Map<String, dynamic> toJson() => {
        'id': id.toString(),
        ...cells,
        if (removed) 'removed': true,
      };

  factory CanonicalFeature.fromMap(final Map<dynamic, dynamic> map) {
    final idStr = map['id']?.toString() ?? '';
    final id = FeatureId.parse(idStr);
    final cells = <String, String>{};
    // Accept BOTH shapes:
    //   * Flat (B1 on-disk format AND current distill_prompt.dart response
    //     shape): cells live as top-level keys alongside `id`/`removed`.
    //   * Nested (legacy/back-compat from commit 7f68969, when distill_prompt
    //     emitted `cells: {...}`): preserved so an older distill output round-
    //     trips. The current LLM-side schema is flat — see distill_prompt.dart
    //     and Track 1a of the Phase B follow-ups.
    final nested = map['cells'];
    if (nested is Map) {
      for (final entry in nested.entries) {
        cells[entry.key.toString()] = entry.value?.toString() ?? '';
      }
    }
    for (final entry in map.entries) {
      final k = entry.key.toString();
      if (k == 'id' || k == 'removed' || k == 'cells') continue;
      cells[k] = entry.value?.toString() ?? '';
    }
    return CanonicalFeature(
      id: id,
      cells: cells,
      removed: map['removed'] == true,
    );
  }
}

class CanonicalMatrix {
  const CanonicalMatrix({
    required this.concept,
    required this.version,
    required this.columnSchema,
    required this.features,
  });

  final String concept;
  final int version;
  final List<CanonicalColumn> columnSchema;
  final List<CanonicalFeature> features;

  Map<String, dynamic> toJson() => {
        'schema': canonicalMatrixSchema,
        'concept': concept,
        'version': version,
        'column_schema':
            columnSchema.map((final c) => c.toJson()).toList(growable: false),
        'features':
            features.map((final f) => f.toJson()).toList(growable: false),
      };

  String toYamlString() {
    final buffer = StringBuffer()
      ..writeln('schema: $canonicalMatrixSchema')
      ..writeln('concept: $concept')
      ..writeln('version: $version')
      ..writeln('column_schema:');
    for (final c in columnSchema) {
      buffer.writeln('  - { id: ${c.id}, type: ${c.type} }');
    }
    buffer.writeln('features:');
    for (final f in features) {
      buffer.writeln('  - id: ${f.id}');
      for (final entry in f.cells.entries) {
        buffer.writeln('    ${entry.key}: ${_yamlScalar(entry.value)}');
      }
      if (f.removed) buffer.writeln('    removed: true');
    }
    return buffer.toString();
  }

  factory CanonicalMatrix.fromMap(final Map<dynamic, dynamic> map) {
    final schema = map['schema']?.toString();
    if (schema != canonicalMatrixSchema) {
      throw ArgumentError(
          'Expected schema $canonicalMatrixSchema, got $schema');
    }
    final colsRaw = map['column_schema'];
    final cols = colsRaw is List
        ? colsRaw
            .whereType<Map>()
            .map(CanonicalColumn.fromMap)
            .toList(growable: false)
        : <CanonicalColumn>[];
    final featsRaw = map['features'];
    final feats = featsRaw is List
        ? featsRaw
            .whereType<Map>()
            .map(CanonicalFeature.fromMap)
            .toList(growable: false)
        : <CanonicalFeature>[];
    return CanonicalMatrix(
      concept: map['concept']?.toString() ?? '',
      version: (map['version'] as int?) ?? 1,
      columnSchema: cols,
      features: feats,
    );
  }
}

String _yamlScalar(final String s) {
  // Always quote empty strings.
  if (s.isEmpty) return '""';
  // Plain scalars: safe identifier-like strings the YAML loader will parse
  // back as a string (not a bool/null/number/timestamp keyword).
  final plainPattern = RegExp(r'^[A-Za-z_][A-Za-z0-9_./@:-]*$');
  const reservedWords = {
    'true',
    'false',
    'null',
    'yes',
    'no',
    'on',
    'off',
    '~',
    'True',
    'False',
    'Null',
    'Yes',
    'No',
    'On',
    'Off',
    'TRUE',
    'FALSE',
    'NULL',
    'YES',
    'NO',
    'ON',
    'OFF',
  };
  if (plainPattern.hasMatch(s) &&
      !reservedWords.contains(s) &&
      // Avoid plain scalars that look like numbers / timestamps.
      double.tryParse(s) == null &&
      DateTime.tryParse(s) == null &&
      // Avoid `:` inside the value, which could be parsed as a flow key.
      !s.contains(':')) {
    return s;
  }
  // Otherwise emit a JSON-encoded double-quoted YAML scalar.
  return jsonEncode(s);
}

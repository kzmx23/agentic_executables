import 'package:yaml/yaml.dart';

/// Canonical feature coverage matrix (YAML source of truth; render to Markdown).
class KnowFeatureMatrix {
  const KnowFeatureMatrix({
    required this.version,
    required this.schema,
    required this.title,
    this.statusDate,
    required this.columns,
    this.columnLegend = const {},
    required this.features,
  });

  static const String defaultSchema = 'ae.know.matrix.v1';

  final int version;
  final String schema;
  final String title;
  final String? statusDate;
  final List<KnowMatrixColumn> columns;
  final Map<String, String> columnLegend;
  final List<KnowMatrixFeature> features;

  String toYamlString() {
    final b = StringBuffer()
      ..writeln('version: $version')
      ..writeln('schema: $schema')
      ..writeln('title: ${_yamlQuote(title)}');
    if (statusDate != null) {
      b.writeln('status_date: ${_yamlQuote(statusDate!)}');
    }
    b.writeln('columns:');
    for (final c in columns) {
      b.writeln('  - id: ${c.id}');
      b.writeln('    label: ${_yamlQuote(c.label)}');
    }
    if (columnLegend.isNotEmpty) {
      b.writeln('column_legend:');
      for (final e in columnLegend.entries) {
        b.writeln('  ${e.key}: ${_yamlQuote(e.value)}');
      }
    }
    b.writeln('features:');
    for (final f in features) {
      b.writeln('  - id: ${f.id}');
      b.writeln('    label: ${_yamlQuote(f.label)}');
      if (f.section != null) {
        b.writeln('    section: ${_yamlQuote(f.section!)}');
      }
      b.writeln('    cells:');
      for (final e in f.cells.entries) {
        final v = e.value ?? '';
        b.writeln('      ${e.key}: ${_yamlQuote(v)}');
      }
      if (f.notes != null && f.notes!.isNotEmpty) {
        b.writeln('    notes: ${_yamlQuote(f.notes!)}');
      }
    }
    return b.toString();
  }

  static String _yamlQuote(final String s) {
    if (s.contains('\n') ||
        s.contains(':') ||
        s.contains("'") ||
        s.contains('"') ||
        s.startsWith(' ') ||
        s.isEmpty) {
      final escaped = s.replaceAll("'", "''");
      return "'$escaped'";
    }
    return s;
  }

  /// Renders an ecsly-style Markdown table + legend.
  String renderMarkdown() {
    final b = StringBuffer()
      ..writeln('# $title')
      ..writeln()
      ..writeln('**Schema:** `$schema`  ')
      ..writeln(
        '**Status date:** `${statusDate ?? 'not set'}`',
      )
      ..writeln();

    if (columnLegend.isNotEmpty) {
      b.writeln('## Legend');
      b.writeln();
      b.writeln('| Column | Meaning |');
      b.writeln('| --- | --- |');
      for (final c in columns) {
        final leg = columnLegend[c.id] ?? '';
        b.writeln('| `${c.id}` | $leg |');
      }
      b.writeln();
    }

    b.writeln('## Coverage');
    b.writeln();
    b.write('| Feature |');
    for (final c in columns) {
      b.write(' ${c.label} |');
    }
    b.writeln();
    b.write('| --- |');
    for (var i = 0; i < columns.length; i++) {
      b.write(' --- |');
    }
    b.writeln();

    for (final f in features) {
      b.write('| ${f.label} |');
      for (final c in columns) {
        if (c.id == 'notes') {
          b.write(' ${f.notes ?? f.cells['notes'] ?? ''} |');
        } else {
          b.write(' ${f.cells[c.id] ?? ''} |');
        }
      }
      b.writeln();
    }

    return b.toString();
  }

  static KnowFeatureMatrix parseYamlString(final String raw) {
    final dynamic y = loadYaml(raw);
    if (y is! Map) {
      throw FormatException('matrix.yaml root must be a map');
    }
    return parseYamlMap(y);
  }

  static KnowFeatureMatrix parseYamlMap(final Map<dynamic, dynamic> map) {
    final version = map['version'] is int
        ? map['version'] as int
        : int.tryParse(map['version']?.toString() ?? '1') ?? 1;
    final schema = map['schema']?.toString() ?? defaultSchema;
    final title = map['title']?.toString() ?? 'Feature matrix';

    final colsRaw = map['columns'];
    final columns = <KnowMatrixColumn>[];
    if (colsRaw is List) {
      for (final c in colsRaw) {
        if (c is Map) {
          columns.add(
            KnowMatrixColumn(
              id: c['id']?.toString() ?? '',
              label: c['label']?.toString() ?? c['id']?.toString() ?? '',
            ),
          );
        }
      }
    }

    final legendRaw = map['column_legend'];
    final legend = <String, String>{};
    if (legendRaw is Map) {
      for (final e in legendRaw.entries) {
        legend[e.key.toString()] = e.value?.toString() ?? '';
      }
    }

    final features = <KnowMatrixFeature>[];
    final featRaw = map['features'];
    if (featRaw is List) {
      for (final fr in featRaw) {
        if (fr is! Map) continue;
        final cellsRaw = fr['cells'];
        final cells = <String, String?>{};
        if (cellsRaw is Map) {
          for (final e in cellsRaw.entries) {
            cells[e.key.toString()] = e.value?.toString();
          }
        }
        features.add(
          KnowMatrixFeature(
            id: fr['id']?.toString() ?? '',
            label: fr['label']?.toString() ?? fr['id']?.toString() ?? '',
            section: fr['section']?.toString(),
            cells: cells,
            notes: fr['notes']?.toString(),
          ),
        );
      }
    }

    return KnowFeatureMatrix(
      version: version,
      schema: schema,
      title: title,
      statusDate: map['status_date']?.toString(),
      columns: columns,
      columnLegend: legend,
      features: features,
    );
  }
}

class KnowMatrixColumn {
  const KnowMatrixColumn({required this.id, required this.label});

  final String id;
  final String label;
}

class KnowMatrixFeature {
  const KnowMatrixFeature({
    required this.id,
    required this.label,
    this.section,
    required this.cells,
    this.notes,
  });

  final String id;
  final String label;
  final String? section;
  final Map<String, String?> cells;
  final String? notes;
}

/// Result of comparing two [KnowFeatureMatrix] values by stable feature id.
class KnowMatrixDiffResult {
  const KnowMatrixDiffResult({
    required this.addedFeatureIds,
    required this.removedFeatureIds,
    required this.changedCells,
    required this.summary,
  });

  final List<String> addedFeatureIds;
  final List<String> removedFeatureIds;
  final List<KnowMatrixCellChange> changedCells;
  final String summary;

  Map<String, dynamic> toJson() => {
        'added_feature_ids': addedFeatureIds,
        'removed_feature_ids': removedFeatureIds,
        'changed_cells':
            changedCells.map((final c) => c.toJson()).toList(growable: false),
        'summary': summary,
      };
}

class KnowMatrixCellChange {
  const KnowMatrixCellChange({
    required this.featureId,
    required this.columnId,
    this.fromValue,
    this.toValue,
  });

  final String featureId;
  final String columnId;
  final String? fromValue;
  final String? toValue;

  Map<String, dynamic> toJson() => {
        'feature_id': featureId,
        'column_id': columnId,
        'from_value': fromValue,
        'to_value': toValue,
      };
}

/// Deterministic structural diff (feature ids + column ids).
KnowMatrixDiffResult diffKnowMatrices(
  final KnowFeatureMatrix from,
  final KnowFeatureMatrix to,
) {
  final fromMap = {for (final f in from.features) f.id: f};
  final toMap = {for (final f in to.features) f.id: f};

  final added = toMap.keys.where((final id) => !fromMap.containsKey(id)).toList()
    ..sort();
  final removed = fromMap.keys.where((final id) => !toMap.containsKey(id)).toList()
    ..sort();

  final colIds = <String>{};
  for (final c in from.columns) {
    colIds.add(c.id);
  }
  for (final c in to.columns) {
    colIds.add(c.id);
  }

  final changes = <KnowMatrixCellChange>[];
  for (final id in fromMap.keys) {
    final a = fromMap[id];
    final b = toMap[id];
    if (a == null || b == null) continue;
    for (final col in colIds) {
      if (col == 'notes') continue;
      final va = a.cells[col] ?? '';
      final vb = b.cells[col] ?? '';
      if (va != vb) {
        changes.add(
          KnowMatrixCellChange(
            featureId: id,
            columnId: col,
            fromValue: va.isEmpty ? null : va,
            toValue: vb.isEmpty ? null : vb,
          ),
        );
      }
    }
    final na = a.notes ?? '';
    final nb = b.notes ?? '';
    if (na != nb) {
      changes.add(
        KnowMatrixCellChange(
          featureId: id,
          columnId: 'notes',
          fromValue: na.isEmpty ? null : na,
          toValue: nb.isEmpty ? null : nb,
        ),
      );
    }
  }

  final summary =
      '${added.length} added, ${removed.length} removed, ${changes.length} cell changes';

  return KnowMatrixDiffResult(
    addedFeatureIds: added,
    removedFeatureIds: removed,
    changedCells: changes,
    summary: summary,
  );
}

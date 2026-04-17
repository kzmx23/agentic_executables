import 'dart:convert';

import 'feature_id.dart';

const String driftReportSchema = 'ae.artifact.drift.v1';

enum CodeDriftChange {
  added('added'),
  modified('modified'),
  removed('removed');

  const CodeDriftChange(this.value);
  final String value;

  static CodeDriftChange fromString(final String value) => switch (value) {
        'added' => CodeDriftChange.added,
        'modified' => CodeDriftChange.modified,
        'removed' => CodeDriftChange.removed,
        _ => throw ArgumentError('Invalid code drift change: $value'),
      };
}

class CodeDriftEntry {
  const CodeDriftEntry({
    required this.path,
    required this.change,
    this.hashWas,
    this.hashIs,
  });

  final String path;
  final CodeDriftChange change;
  final String? hashWas;
  final String? hashIs;

  Map<String, dynamic> toJson() => {
        'path': path,
        'change': change.value,
        if (hashWas != null) 'hash_was': hashWas,
        if (hashIs != null) 'hash_is': hashIs,
      };

  factory CodeDriftEntry.fromMap(final Map<dynamic, dynamic> map) =>
      CodeDriftEntry(
        path: map['path']?.toString() ?? '',
        change: CodeDriftChange.fromString(
          map['change']?.toString() ?? 'modified',
        ),
        hashWas: map['hash_was']?.toString(),
        hashIs: map['hash_is']?.toString(),
      );
}

class IntentDriftEntry {
  const IntentDriftEntry({
    required this.featureId,
    required this.canonical,
    required this.invariant,
    required this.reason,
  });

  final FeatureId featureId;
  final String canonical;
  final String invariant;
  final String reason;

  Map<String, dynamic> toJson() => {
        'feature_id': featureId.toString(),
        'canonical': canonical,
        'invariant': invariant,
        'reason': reason,
      };

  factory IntentDriftEntry.fromMap(final Map<dynamic, dynamic> map) =>
      IntentDriftEntry(
        featureId: FeatureId.parse(map['feature_id']?.toString() ?? ''),
        canonical: map['canonical']?.toString() ?? '',
        invariant: map['invariant']?.toString() ?? '',
        reason: map['reason']?.toString() ?? '',
      );
}

class AcceptedDrift {
  const AcceptedDrift({required this.featureId, required this.note});

  final FeatureId featureId;
  final String note;

  Map<String, dynamic> toJson() => {
        'feature_id': featureId.toString(),
        'note': note,
      };

  factory AcceptedDrift.fromMap(final Map<dynamic, dynamic> map) =>
      AcceptedDrift(
        featureId: FeatureId.parse(map['feature_id']?.toString() ?? ''),
        note: map['note']?.toString() ?? '',
      );
}

class DriftReport {
  const DriftReport({
    required this.generatedBy,
    required this.generatedAt,
    this.codeDrift = const [],
    this.intentDrift = const [],
    this.accepted = const [],
  });

  final String generatedBy;
  final DateTime generatedAt;
  final List<CodeDriftEntry> codeDrift;
  final List<IntentDriftEntry> intentDrift;
  final List<AcceptedDrift> accepted;

  Map<String, dynamic> toJson() => {
        'schema': driftReportSchema,
        'generated_by': generatedBy,
        'generated_at': generatedAt.toUtc().toIso8601String(),
        'code_drift':
            codeDrift.map((final e) => e.toJson()).toList(growable: false),
        'intent_drift':
            intentDrift.map((final e) => e.toJson()).toList(growable: false),
        'accepted':
            accepted.map((final e) => e.toJson()).toList(growable: false),
      };

  String toYamlString() {
    final buffer = StringBuffer()
      ..writeln('schema: $driftReportSchema')
      ..writeln('generated_by: $generatedBy')
      ..writeln('generated_at: "${generatedAt.toUtc().toIso8601String()}"');
    if (codeDrift.isEmpty) {
      buffer.writeln('code_drift: []');
    } else {
      buffer.writeln('code_drift:');
      for (final e in codeDrift) {
        final parts = <String>[
          'path: ${_y(e.path)}',
          'change: ${e.change.value}',
        ];
        if (e.hashWas != null) parts.add('hash_was: ${_y(e.hashWas!)}');
        if (e.hashIs != null) parts.add('hash_is: ${_y(e.hashIs!)}');
        buffer.writeln('  - { ${parts.join(", ")} }');
      }
    }
    if (intentDrift.isEmpty) {
      buffer.writeln('intent_drift: []');
    } else {
      buffer.writeln('intent_drift:');
      for (final e in intentDrift) {
        buffer
          ..writeln('  - feature_id: ${e.featureId}')
          ..writeln('    canonical: ${e.canonical}')
          ..writeln('    invariant: ${_y(e.invariant)}')
          ..writeln('    reason: ${_y(e.reason)}');
      }
    }
    if (accepted.isEmpty) {
      buffer.writeln('accepted: []');
    } else {
      buffer.writeln('accepted:');
      for (final e in accepted) {
        buffer
          ..writeln('  - feature_id: ${e.featureId}')
          ..writeln('    note: ${_y(e.note)}');
      }
    }
    return buffer.toString();
  }

  factory DriftReport.fromMap(final Map<dynamic, dynamic> map) {
    final schema = map['schema']?.toString();
    if (schema != driftReportSchema) {
      throw ArgumentError('Expected schema $driftReportSchema, got $schema');
    }
    final atRaw = map['generated_at']?.toString();
    final at = atRaw != null
        ? DateTime.tryParse(atRaw)?.toUtc() ?? DateTime.now().toUtc()
        : DateTime.now().toUtc();
    List<T> readList<T>(
      final dynamic raw,
      final T Function(Map<dynamic, dynamic>) f,
    ) =>
        raw is List
            ? raw.whereType<Map>().map(f).toList(growable: false)
            : <T>[];
    return DriftReport(
      generatedBy: map['generated_by']?.toString() ?? '',
      generatedAt: at,
      codeDrift: readList(map['code_drift'], CodeDriftEntry.fromMap),
      intentDrift: readList(map['intent_drift'], IntentDriftEntry.fromMap),
      accepted: readList(map['accepted'], AcceptedDrift.fromMap),
    );
  }
}

String _y(final String s) {
  // Always quote empty strings.
  if (s.isEmpty) return '""';
  // Plain scalars: safe identifier-like strings the YAML loader will parse
  // back as a string (not a bool/null/number/timestamp keyword).
  final plainPattern = RegExp(r'^[A-Za-z_][A-Za-z0-9_./@:-]*$');
  const reservedWords = {
    'true', 'false', 'null', 'yes', 'no', 'on', 'off', '~',
    'True', 'False', 'Null', 'Yes', 'No', 'On', 'Off',
    'TRUE', 'FALSE', 'NULL', 'YES', 'NO', 'ON', 'OFF',
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

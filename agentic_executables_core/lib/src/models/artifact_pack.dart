import 'dart:convert';

import 'artifact_matrix.dart';
import 'requires_spec.dart';

const String artifactMetaSchema = 'ae.artifact.meta.v1';

enum ArtifactKind {
  local('local'),
  external('external'),
  use('use');

  const ArtifactKind(this.value);
  final String value;

  static ArtifactKind fromString(final String value) => switch (value) {
        'local' => ArtifactKind.local,
        'external' => ArtifactKind.external,
        'use' => ArtifactKind.use,
        _ => throw ArgumentError('Invalid artifact kind: $value'),
      };
}

enum ArtifactSourceType {
  path('path'),
  url('url'),
  git('git');

  const ArtifactSourceType(this.value);
  final String value;

  static ArtifactSourceType fromString(final String value) => switch (value) {
        'path' => ArtifactSourceType.path,
        'url' => ArtifactSourceType.url,
        'git' => ArtifactSourceType.git,
        _ => throw ArgumentError('Invalid artifact source type: $value'),
      };
}

class ArtifactSourceFile {
  const ArtifactSourceFile({required this.path, required this.sha256});

  final String path;
  final String sha256;

  Map<String, dynamic> toJson() => {'path': path, 'sha256': sha256};

  factory ArtifactSourceFile.fromMap(final Map<dynamic, dynamic> map) =>
      ArtifactSourceFile(
        path: map['path']?.toString() ?? '',
        sha256: map['sha256']?.toString() ?? '',
      );
}

class ArtifactSource {
  const ArtifactSource({
    required this.type,
    this.path,
    this.url,
    this.files = const [],
  });

  final ArtifactSourceType type;
  final String? path;
  final String? url;
  final List<ArtifactSourceFile> files;

  Map<String, dynamic> toJson() => {
        'type': type.value,
        if (path != null) 'path': path,
        if (url != null) 'url': url,
        if (files.isNotEmpty)
          'files': files.map((final f) => f.toJson()).toList(growable: false),
      };

  factory ArtifactSource.fromMap(final Map<dynamic, dynamic> map) {
    final filesRaw = map['files'];
    final files = filesRaw is List
        ? filesRaw
            .whereType<Map>()
            .map(ArtifactSourceFile.fromMap)
            .toList(growable: false)
        : <ArtifactSourceFile>[];
    return ArtifactSource(
      type: ArtifactSourceType.fromString(
        map['type']?.toString() ?? 'path',
      ),
      path: map['path']?.toString(),
      url: map['url']?.toString(),
      files: files,
    );
  }
}

class ArtifactLicense {
  const ArtifactLicense({
    required this.spdx,
    this.detectedFrom,
    this.notes,
  });

  final String spdx;
  final String? detectedFrom;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'spdx': spdx,
        if (detectedFrom != null) 'detected_from': detectedFrom,
        if (notes != null) 'notes': notes,
      };

  factory ArtifactLicense.fromMap(final Map<dynamic, dynamic> map) =>
      ArtifactLicense(
        spdx: map['spdx']?.toString() ?? 'unknown',
        detectedFrom: map['detected_from']?.toString(),
        notes: map['notes']?.toString(),
      );
}

class ArtifactAuthor {
  const ArtifactAuthor({required this.name, this.detectedFrom});

  final String name;
  final String? detectedFrom;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (detectedFrom != null) 'detected_from': detectedFrom,
      };

  factory ArtifactAuthor.fromMap(final Map<dynamic, dynamic> map) =>
      ArtifactAuthor(
        name: map['name']?.toString() ?? '',
        detectedFrom: map['detected_from']?.toString(),
      );
}

class ArtifactDistill {
  const ArtifactDistill({required this.engine, this.appliedAt});

  /// "heuristic" or "inference" (string for forward compat with new engines).
  final String engine;
  final DateTime? appliedAt;

  Map<String, dynamic> toJson() => {
        'engine': engine,
        if (appliedAt != null)
          'applied_at': appliedAt!.toUtc().toIso8601String(),
      };

  factory ArtifactDistill.fromMap(final Map<dynamic, dynamic> map) {
    final atRaw = map['applied_at']?.toString();
    final at = atRaw != null ? DateTime.tryParse(atRaw)?.toUtc() : null;
    return ArtifactDistill(
      engine: map['engine']?.toString() ?? 'heuristic',
      appliedAt: at,
    );
  }
}

class CanonicalReference {
  const CanonicalReference._(this.conceptId, this.lockedVersion);

  factory CanonicalReference.parse(final String value) {
    if (value.isEmpty) {
      throw ArgumentError('CanonicalReference cannot be empty');
    }
    final at = value.indexOf('@');
    if (at < 0) {
      return CanonicalReference._(value, null);
    }
    final concept = value.substring(0, at);
    final tail = value.substring(at + 1);
    if (!tail.startsWith('v') || tail.length < 2) {
      throw ArgumentError('CanonicalReference lock must be "@v<int>": "$value"');
    }
    final n = int.tryParse(tail.substring(1));
    if (n == null) {
      throw ArgumentError('CanonicalReference lock must be "@v<int>": "$value"');
    }
    return CanonicalReference._(concept, n);
  }

  /// e.g. "ecs", "gltf/core", "ecsly/render_pipeline"
  final String conceptId;

  /// null = live (tracks current); int = locked to snapshot v<int>.
  final int? lockedVersion;

  bool get isLive => lockedVersion == null;

  @override
  String toString() =>
      lockedVersion == null ? conceptId : '$conceptId@v$lockedVersion';
}

class ArtifactMeta {
  const ArtifactMeta({
    required this.kind,
    required this.title,
    required this.source,
    required this.scannedAt,
    required this.referencesCanonical,
    required this.extractor,
    required this.distill,
    this.license,
    this.authors = const [],
  });

  final ArtifactKind kind;
  final String title;
  final ArtifactSource source;
  final DateTime scannedAt;
  final ArtifactLicense? license;
  final List<ArtifactAuthor> authors;
  final List<CanonicalReference> referencesCanonical;
  final String extractor;
  final ArtifactDistill distill;

  Map<String, dynamic> toJson() => {
        'schema': artifactMetaSchema,
        'kind': kind.value,
        'title': title,
        'source': source.toJson(),
        'scanned_at': scannedAt.toUtc().toIso8601String(),
        if (license != null) 'license': license!.toJson(),
        if (authors.isNotEmpty)
          'authors':
              authors.map((final a) => a.toJson()).toList(growable: false),
        'references_canonical':
            referencesCanonical.map((final r) => r.toString()).toList(growable: false),
        'extractor': extractor,
        'distill': distill.toJson(),
      };

  String toYamlString() {
    final buffer = StringBuffer()
      ..writeln('schema: $artifactMetaSchema')
      ..writeln('kind: ${kind.value}')
      ..writeln('title: ${_y(title)}')
      ..writeln('source:')
      ..writeln('  type: ${source.type.value}');
    if (source.path != null) buffer.writeln('  path: ${_y(source.path!)}');
    if (source.url != null) buffer.writeln('  url: ${_y(source.url!)}');
    if (source.files.isNotEmpty) {
      buffer.writeln('  files:');
      for (final f in source.files) {
        buffer.writeln('    - { path: ${_y(f.path)}, sha256: ${_y(f.sha256)} }');
      }
    }
    buffer.writeln('scanned_at: ${_y(scannedAt.toUtc().toIso8601String())}');
    if (license != null) {
      buffer.writeln('license:');
      buffer.writeln('  spdx: ${_y(license!.spdx)}');
      if (license!.detectedFrom != null) {
        buffer.writeln('  detected_from: ${license!.detectedFrom}');
      }
      if (license!.notes != null) {
        buffer.writeln('  notes: ${_y(license!.notes!)}');
      }
    }
    if (authors.isEmpty) {
      buffer.writeln('authors: []');
    } else {
      buffer.writeln('authors:');
      for (final a in authors) {
        buffer.writeln('  - name: ${_y(a.name)}');
        if (a.detectedFrom != null) {
          buffer.writeln('    detected_from: ${a.detectedFrom}');
        }
      }
    }
    if (referencesCanonical.isEmpty) {
      buffer.writeln('references_canonical: []');
    } else {
      buffer.writeln('references_canonical:');
      for (final r in referencesCanonical) {
        buffer.writeln('  - ${r.toString()}');
      }
    }
    buffer
      ..writeln('extractor: ${extractor}')
      ..writeln('distill:')
      ..writeln('  engine: ${distill.engine}');
    if (distill.appliedAt != null) {
      buffer.writeln(
        '  applied_at: ${_y(distill.appliedAt!.toUtc().toIso8601String())}',
      );
    }
    return buffer.toString();
  }

  factory ArtifactMeta.fromMap(final Map<dynamic, dynamic> map) {
    final schema = map['schema']?.toString();
    if (schema != artifactMetaSchema) {
      throw ArgumentError('Expected schema $artifactMetaSchema, got $schema');
    }
    final scannedAtRaw = map['scanned_at']?.toString();
    final scannedAt = scannedAtRaw != null
        ? DateTime.tryParse(scannedAtRaw)?.toUtc() ?? DateTime.now().toUtc()
        : DateTime.now().toUtc();
    final sourceRaw = map['source'];
    final source = sourceRaw is Map
        ? ArtifactSource.fromMap(sourceRaw)
        : const ArtifactSource(type: ArtifactSourceType.path);
    final licRaw = map['license'];
    final license = licRaw is Map ? ArtifactLicense.fromMap(licRaw) : null;
    final authorsRaw = map['authors'];
    final authors = authorsRaw is List
        ? authorsRaw
            .whereType<Map>()
            .map(ArtifactAuthor.fromMap)
            .toList(growable: false)
        : <ArtifactAuthor>[];
    final refsRaw = map['references_canonical'];
    final refs = refsRaw is List
        ? refsRaw
            .map((final v) => CanonicalReference.parse(v.toString()))
            .toList(growable: false)
        : <CanonicalReference>[];
    final distillRaw = map['distill'];
    final distill = distillRaw is Map
        ? ArtifactDistill.fromMap(distillRaw)
        : const ArtifactDistill(engine: 'heuristic');
    return ArtifactMeta(
      kind: ArtifactKind.fromString(map['kind']?.toString() ?? 'local'),
      title: map['title']?.toString() ?? '',
      source: source,
      scannedAt: scannedAt,
      license: license,
      authors: authors,
      referencesCanonical: refs,
      extractor: map['extractor']?.toString() ?? '',
      distill: distill,
    );
  }
}

class ArtifactPack {
  const ArtifactPack({
    required this.name,
    required this.meta,
    required this.indexContent,
    required this.matrix,
    this.patternsContent,
    this.requires,
  });

  /// The pack directory name under `artifacts/<kind>/<name>/`.
  final String name;
  final ArtifactMeta meta;
  final String indexContent;
  final ArtifactMatrix matrix;
  final String? patternsContent;
  final RequiresSpec? requires;
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

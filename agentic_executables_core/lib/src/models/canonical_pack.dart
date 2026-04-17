import 'canonical_matrix.dart';

const String canonicalMetaSchema = 'ae.canonical.meta.v1';

enum CanonicalAuthorRole {
  originalAuthor('original_author'),
  contributor('contributor'),
  maintainer('maintainer');

  const CanonicalAuthorRole(this.value);
  final String value;

  static CanonicalAuthorRole fromString(final String value) => switch (value) {
        'original_author' => CanonicalAuthorRole.originalAuthor,
        'contributor' => CanonicalAuthorRole.contributor,
        'maintainer' => CanonicalAuthorRole.maintainer,
        _ => throw ArgumentError('Invalid canonical author role: $value'),
      };
}

enum CanonicalSourceKind {
  paper('paper'),
  website('website'),
  code('code'),
  book('book'),
  spec('spec');

  const CanonicalSourceKind(this.value);
  final String value;

  static CanonicalSourceKind fromString(final String value) => switch (value) {
        'paper' => CanonicalSourceKind.paper,
        'website' => CanonicalSourceKind.website,
        'code' => CanonicalSourceKind.code,
        'book' => CanonicalSourceKind.book,
        'spec' => CanonicalSourceKind.spec,
        _ => throw ArgumentError('Invalid canonical source kind: $value'),
      };
}

enum CanonicalAuthored {
  hand('hand'),
  distilledFromArtifact('distilled_from_artifact'),
  importedFromPublicHub('imported_from_public_hub');

  const CanonicalAuthored(this.value);
  final String value;

  static CanonicalAuthored fromString(final String value) => switch (value) {
        'hand' => CanonicalAuthored.hand,
        'distilled_from_artifact' => CanonicalAuthored.distilledFromArtifact,
        'imported_from_public_hub' => CanonicalAuthored.importedFromPublicHub,
        _ => throw ArgumentError('Invalid canonical authored: $value'),
      };
}

class CanonicalLicense {
  const CanonicalLicense({required this.spdx, required this.url});

  final String spdx;
  final String url;

  Map<String, dynamic> toJson() => {'spdx': spdx, 'url': url};

  factory CanonicalLicense.fromMap(final Map<dynamic, dynamic> map) =>
      CanonicalLicense(
        spdx: map['spdx']?.toString() ?? '',
        url: map['url']?.toString() ?? '',
      );
}

class CanonicalAuthor {
  const CanonicalAuthor({required this.name, required this.role, this.email});

  final String name;
  final CanonicalAuthorRole role;
  final String? email;

  Map<String, dynamic> toJson() => {
        'name': name,
        'role': role.value,
        if (email != null) 'email': email,
      };

  factory CanonicalAuthor.fromMap(final Map<dynamic, dynamic> map) =>
      CanonicalAuthor(
        name: map['name']?.toString() ?? '',
        role: CanonicalAuthorRole.fromString(
          map['role']?.toString() ?? 'contributor',
        ),
        email: map['email']?.toString(),
      );
}

class CanonicalSource {
  const CanonicalSource({
    required this.kind,
    required this.title,
    required this.url,
  });

  final CanonicalSourceKind kind;
  final String title;
  final String url;

  Map<String, dynamic> toJson() =>
      {'kind': kind.value, 'title': title, 'url': url};

  factory CanonicalSource.fromMap(final Map<dynamic, dynamic> map) =>
      CanonicalSource(
        kind: CanonicalSourceKind.fromString(
          map['kind']?.toString() ?? 'website',
        ),
        title: map['title']?.toString() ?? '',
        url: map['url']?.toString() ?? '',
      );
}

class CanonicalProvenance {
  const CanonicalProvenance({
    required this.authored,
    required this.authoredAt,
    this.distilledFrom,
  });

  final CanonicalAuthored authored;
  final DateTime authoredAt;
  final String? distilledFrom;

  Map<String, dynamic> toJson() => {
        'authored': authored.value,
        'authored_at': authoredAt.toUtc().toIso8601String(),
        if (distilledFrom != null) 'distilled_from': distilledFrom,
      };

  factory CanonicalProvenance.fromMap(final Map<dynamic, dynamic> map) {
    final atRaw = map['authored_at']?.toString();
    final at = atRaw != null
        ? DateTime.tryParse(atRaw)?.toUtc() ?? DateTime.now().toUtc()
        : DateTime.now().toUtc();
    return CanonicalProvenance(
      authored: CanonicalAuthored.fromString(
        map['authored']?.toString() ?? 'hand',
      ),
      authoredAt: at,
      distilledFrom: map['distilled_from']?.toString(),
    );
  }
}

class CanonicalMeta {
  const CanonicalMeta({
    required this.concept,
    required this.version,
    required this.title,
    required this.license,
    required this.authors,
    required this.sources,
    required this.provenance,
  });

  final String concept;
  final int version;
  final String title;
  final CanonicalLicense license;
  final List<CanonicalAuthor> authors;
  final List<CanonicalSource> sources;
  final CanonicalProvenance provenance;

  Map<String, dynamic> toJson() => {
        'schema': canonicalMetaSchema,
        'concept': concept,
        'version': version,
        'title': title,
        'license': license.toJson(),
        'authors':
            authors.map((final a) => a.toJson()).toList(growable: false),
        'sources':
            sources.map((final s) => s.toJson()).toList(growable: false),
        'provenance': provenance.toJson(),
      };

  String toYamlString() {
    final buffer = StringBuffer()
      ..writeln('schema: $canonicalMetaSchema')
      ..writeln('concept: $concept')
      ..writeln('version: $version')
      ..writeln('title: ${_y(title)}')
      ..writeln('license:')
      ..writeln('  spdx: ${_y(license.spdx)}')
      ..writeln('  url: ${_y(license.url)}');
    if (authors.isEmpty) {
      buffer.writeln('authors: []');
    } else {
      buffer.writeln('authors:');
      for (final a in authors) {
        buffer.writeln('  - name: ${_y(a.name)}');
        buffer.writeln('    role: ${a.role.value}');
        if (a.email != null) buffer.writeln('    email: ${_y(a.email!)}');
      }
    }
    if (sources.isEmpty) {
      buffer.writeln('sources: []');
    } else {
      buffer.writeln('sources:');
      for (final s in sources) {
        buffer
          ..writeln('  - kind: ${s.kind.value}')
          ..writeln('    title: ${_y(s.title)}')
          ..writeln('    url: ${_y(s.url)}');
      }
    }
    buffer
      ..writeln('provenance:')
      ..writeln('  authored: ${provenance.authored.value}')
      ..writeln('  authored_at: ${_y(provenance.authoredAt.toUtc().toIso8601String())}');
    if (provenance.distilledFrom != null) {
      buffer.writeln('  distilled_from: ${_y(provenance.distilledFrom!)}');
    }
    return buffer.toString();
  }

  factory CanonicalMeta.fromMap(final Map<dynamic, dynamic> map) {
    final schema = map['schema']?.toString();
    if (schema != canonicalMetaSchema) {
      throw ArgumentError(
        'Expected schema $canonicalMetaSchema, got $schema',
      );
    }
    final licRaw = map['license'];
    if (licRaw is! Map) {
      throw ArgumentError('CanonicalMeta requires "license" map');
    }
    final license = CanonicalLicense.fromMap(licRaw);

    final authorsRaw = map['authors'];
    final authors = authorsRaw is List
        ? authorsRaw
            .whereType<Map>()
            .map(CanonicalAuthor.fromMap)
            .toList(growable: false)
        : <CanonicalAuthor>[];

    final sourcesRaw = map['sources'];
    final sources = sourcesRaw is List
        ? sourcesRaw
            .whereType<Map>()
            .map(CanonicalSource.fromMap)
            .toList(growable: false)
        : <CanonicalSource>[];

    final provenanceRaw = map['provenance'];
    final provenance = provenanceRaw is Map
        ? CanonicalProvenance.fromMap(provenanceRaw)
        : CanonicalProvenance(
            authored: CanonicalAuthored.hand,
            authoredAt: DateTime.now().toUtc(),
          );

    return CanonicalMeta(
      concept: map['concept']?.toString() ?? '',
      version: (map['version'] as int?) ?? 1,
      title: map['title']?.toString() ?? '',
      license: license,
      authors: authors,
      sources: sources,
      provenance: provenance,
    );
  }
}

class CanonicalPack {
  const CanonicalPack({
    required this.meta,
    required this.indexContent,
    required this.matrix,
    this.changelogContent,
  });

  final CanonicalMeta meta;
  final String indexContent;
  final CanonicalMatrix matrix;
  final String? changelogContent;
}

String _y(final String s) {
  if (s.contains('\n') || s.contains(':')) {
    return '"${s.replaceAll('\\', r'\\').replaceAll('"', r'\"')}"';
  }
  return '"$s"';
}

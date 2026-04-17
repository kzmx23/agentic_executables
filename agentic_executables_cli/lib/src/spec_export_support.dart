import 'dart:convert';
import 'dart:io';

import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:path/path.dart' as p;

/// Output of [exportSpec].
class SpecExportResult {
  const SpecExportResult({
    required this.outDir,
    required this.hubPath,
    required this.locale,
    required this.canonicalCount,
    required this.artifactCount,
    required this.files,
  });

  final String outDir;
  final String hubPath;
  final String locale;
  final int canonicalCount;
  final int artifactCount;
  final List<String> files;

  Map<String, dynamic> toJson() => {
        'out_dir': outDir,
        'hub_path': hubPath,
        'locale': locale,
        'canonical_count': canonicalCount,
        'artifact_count': artifactCount,
        'files': files,
      };
}

/// Export the v3 spec shape from the hub at [hubPath] into [outDir].
///
/// Writes:
///   `<out>/spec_index.json`               — schema: spec_export.v3
///   `<out>/definition.yaml`               — schema: ae.definition.v1
///   `<out>/definition.md`                 — human-readable framework def
///   `<out>/definition.json`               — schema: ae.spec_definition_ptr.v1
///   `<out>/canonical_<slug>.json`         — schema: ae.canonical.v3
///   `<out>/artifact_<name>.json`          — schema: ae.artifact.v3
Future<SpecExportResult> exportSpec({
  required final String outDir,
  required final String hubPath,
  final String locale = 'en',
}) async {
  final out = Directory(outDir);
  await out.create(recursive: true);

  final written = <String>[];

  // definition trio — reuses DefaultAeDefinitionService (unchanged shape).
  final defResult = const DefaultAeDefinitionService().getDefinition();
  final def = defResult.data!;
  await File(p.join(outDir, _definitionYamlFile))
      .writeAsString(_definitionYaml(def));
  written.add(_definitionYamlFile);
  await File(p.join(outDir, _definitionMdFile))
      .writeAsString(_definitionMarkdown(def));
  written.add(_definitionMdFile);
  await File(p.join(outDir, _definitionJsonPtrFile)).writeAsString(
    _jsonPretty(_definitionJsonPointer()),
  );
  written.add(_definitionJsonPtrFile);

  // Canonical packs.
  final canStore = FileCanonicalStore(hubPath);
  final canSvc = DefaultCanonicalService(store: canStore);
  final canonicalIds = await canSvc.list();
  final canonicalEntries = <Map<String, dynamic>>[];
  for (final concept in canonicalIds) {
    final pack = await canSvc.load(concept);
    if (pack == null) continue;
    final slug = _conceptSlug(concept);
    final fileName = 'canonical_$slug.json';
    final body = <String, dynamic>{
      'schema': 'ae.canonical.v3',
      'meta': pack.meta.toJson(),
      'matrix': pack.matrix.toJson(),
      'index_md': pack.indexContent,
    };
    await File(p.join(outDir, fileName)).writeAsString(_jsonPretty(body));
    written.add(fileName);
    canonicalEntries.add({
      'concept': pack.meta.concept,
      'version': pack.meta.version,
      'feature_count': pack.matrix.features.length,
      'file': fileName,
    });
  }

  // Artifact packs.
  final artStore = FileArtifactStore(hubPath);
  final artSvc = DefaultArtifactService(
    artifactStore: artStore,
    canonicalStore: canStore,
    extractorRegistry: HeuristicExtractorRegistry(const []),
  );
  final artifactNames = await artSvc.list();
  final artifactEntries = <Map<String, dynamic>>[];
  for (final name in artifactNames) {
    final pack = await artSvc.load(name);
    if (pack == null) continue;
    final fileName = 'artifact_$name.json';
    final body = <String, dynamic>{
      'schema': 'ae.artifact.v3',
      'meta': pack.meta.toJson(),
      'matrix': pack.matrix.toJson(),
    };
    await File(p.join(outDir, fileName)).writeAsString(_jsonPretty(body));
    written.add(fileName);
    artifactEntries.add({
      'name': pack.name,
      'kind': pack.meta.kind.value,
      'references_canonical': pack.meta.referencesCanonical
          .map((final r) => r.toString())
          .toList(growable: false),
      'feature_count': pack.matrix.features.length,
      'file': fileName,
    });
  }

  // spec_index.json — written last so readers can rely on its pointers.
  final index = <String, dynamic>{
    'schema': 'spec_export.v3',
    'version': 3,
    'export_base': '.',
    'locale': locale,
    'canonicals': canonicalEntries,
    'artifacts': artifactEntries,
  };
  await File(p.join(outDir, _specIndexFile))
      .writeAsString(_jsonPretty(index));
  written.add(_specIndexFile);

  return SpecExportResult(
    outDir: outDir,
    hubPath: hubPath,
    locale: locale,
    canonicalCount: canonicalEntries.length,
    artifactCount: artifactEntries.length,
    files: written,
  );
}

const String _specIndexFile = 'spec_index.json';
const String _definitionYamlFile = 'definition.yaml';
const String _definitionMdFile = 'definition.md';
const String _definitionJsonPtrFile = 'definition.json';

/// Translate `gltf/core` → `gltf__core` for filesystem-safe slugs.
String _conceptSlug(final String concept) =>
    concept.replaceAll('/', '__');

String _jsonPretty(final Object value) {
  const encoder = JsonEncoder.withIndent('  ');
  return '${encoder.convert(value)}\n';
}

Map<String, dynamic> _definitionJsonPointer() => {
      'schema': 'ae.spec_definition_ptr.v1',
      'version': 1,
      'definition_yaml': _definitionYamlFile,
      'definition_md': _definitionMdFile,
    };

String _definitionYaml(final GetDefinitionOutput o) {
  final w = StringBuffer()
    ..writeln('schema: ae.definition.v1')
    ..writeln('version: 1')
    ..writeln('name: ${_yamlScalar(o.name)}')
    ..writeln('description: ${_yamlScalar(o.description)}')
    ..writeln('contexts:');
  for (final e in o.contexts.entries) {
    w
      ..writeln('  ${e.key.value}:')
      ..writeln('    description: ${_yamlScalar(e.value.description)}')
      ..writeln('    use_case: ${_yamlScalar(e.value.useCase)}');
  }
  w.writeln('actions:');
  for (final a in o.actions) {
    w
      ..writeln('  - name: ${a.name.value}')
      ..writeln('    description: ${_yamlScalar(a.description)}')
      ..writeln('    applicable_contexts:');
    for (final c in a.applicableContexts) {
      w.writeln('      - ${c.value}');
    }
  }
  w.writeln('tools:');
  for (final t in o.tools) {
    w
      ..writeln('  - name: ${_yamlScalar(t.name)}')
      ..writeln('    description: ${_yamlScalar(t.description)}')
      ..writeln('    use_case: ${_yamlScalar(t.useCase)}');
  }
  w.writeln('core_principles:');
  for (final pr in o.corePrinciples) {
    w
      ..writeln('  - name: ${_yamlScalar(pr.name)}')
      ..writeln('    description: ${_yamlScalar(pr.description)}');
  }
  return w.toString();
}

String _definitionMarkdown(final GetDefinitionOutput o) {
  final w = StringBuffer()
    ..writeln('# AE definition')
    ..writeln()
    ..writeln(o.message)
    ..writeln()
    ..writeln('## Usage guide')
    ..writeln();
  for (final e in o.usageGuide.entries) {
    w
      ..writeln('### ${e.key}')
      ..writeln()
      ..writeln(e.value)
      ..writeln();
  }
  return w.toString();
}

String _yamlScalar(final String s) {
  if (s.isEmpty) return '""';
  if (s.contains('\n')) {
    final escaped = s.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    return '"$escaped"';
  }
  if (RegExp(r'^[\w\-./() ,]+$').hasMatch(s) &&
      !s.contains(':') &&
      s != 'true' &&
      s != 'false' &&
      s != 'null') {
    return s;
  }
  final escaped = s.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  return '"$escaped"';
}

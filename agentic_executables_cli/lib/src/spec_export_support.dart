import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:path/path.dart' as p;

/// Portable spec export helpers (definition split, path relativization).
class SpecExportSupport {
  SpecExportSupport._();

  static const definitionYamlFile = 'definition.yaml';
  static const definitionMdFile = 'definition.md';
  static const definitionJsonPtrFile = 'definition.json';
  static const matrixDiffFile = 'matrix_diff.json';

  /// Machine-oriented definition (YAML). Human narrative lives in [definitionMd].
  static String definitionYaml(final GetDefinitionOutput o) {
    final w = StringBuffer()
      ..writeln('schema: ae.definition.v1')
      ..writeln('version: 1')
      ..writeln('name: ${_yamlScalar(o.name)}')
      ..writeln('description: ${_yamlScalar(o.description)}')
      ..writeln('contexts:');
    for (final e in o.contexts.entries) {
      w
        ..writeln('  ${e.key.value}:')
        ..writeln(
            '    description: ${_yamlScalar(e.value.description)}')
        ..writeln('    use_case: ${_yamlScalar(e.value.useCase)}');
    }
    w.writeln('actions:');
    for (final a in o.actions) {
      w.writeln('  - name: ${a.name.value}');
      w.writeln('    description: ${_yamlScalar(a.description)}');
      w.writeln('    applicable_contexts:');
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

  /// Human-oriented definition (usage guide, message). Not required for strict parsers.
  static String definitionMarkdown(final GetDefinitionOutput o) {
    final w = StringBuffer()
      ..writeln('# AE definition')
      ..writeln()
      ..writeln(o.message)
      ..writeln()
      ..writeln('## Usage guide')
      ..writeln();
    for (final e in o.usageGuide.entries) {
      w.writeln('### ${e.key}');
      w.writeln();
      w.writeln(e.value);
      w.writeln();
    }
    return w.toString();
  }

  /// Small JSON pointer so legacy consumers can find YAML/MD.
  static Map<String, dynamic> definitionJsonPointer() => {
        'schema': 'ae.spec_definition_ptr.v1',
        'version': 1,
        'definition_yaml': definitionYamlFile,
        'definition_md': definitionMdFile,
      };

  static String _yamlScalar(final String s) {
    if (s.isEmpty) {
      return '""';
    }
    if (s.contains('\n')) {
      final escaped = s.replaceAll('"', r'\"');
      return '"$escaped"';
    }
    if (RegExp(r'^[\w\-./:()\[\] ,]+$').hasMatch(s) &&
        !s.contains(':') &&
        !s.startsWith('0') &&
        s != 'true' &&
        s != 'false' &&
        s != 'null') {
      return s;
    }
    return '"${_escapeYamlDoubleQuoted(s)}"';
  }

  static String _escapeYamlDoubleQuoted(final String s) =>
      s.replaceAll(r'\', r'\\').replaceAll('"', r'\"');

  /// Rewrites `meta.source.path` on [KnowShowOutput.toJson()]-shaped maps.
  static Map<String, dynamic> relativizeKnowShowData(
    final Map<String, dynamic> knowShowData,
    final String exportBaseNorm,
  ) {
    final out = Map<String, dynamic>.from(knowShowData);
    final meta = out['meta'];
    if (meta is! Map) {
      return out;
    }
    final metaMap = Map<String, dynamic>.from(meta);
    final source = metaMap['source'];
    if (source is! Map) {
      return out;
    }
    final sourceMap = Map<String, dynamic>.from(source);
    final type = sourceMap['type']?.toString();
    final pathRaw = sourceMap['path']?.toString();
    if (pathRaw != null && pathRaw.isNotEmpty && type == 'local') {
      final abs = p.isAbsolute(pathRaw)
          ? pathRaw
          : p.normalize(p.join(exportBaseNorm, pathRaw));
      final normAbs = p.normalize(abs);
      final baseNorm = p.normalize(exportBaseNorm);
      final rel = p.relative(normAbs, from: baseNorm);
      if (!rel.startsWith('..') && !p.isAbsolute(rel)) {
        sourceMap['path'] = rel;
      }
    }
    metaMap['source'] = sourceMap;
    out['meta'] = metaMap;
    return out;
  }
}

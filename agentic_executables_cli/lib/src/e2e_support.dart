import 'dart:io';

import 'package:yaml/yaml.dart';

/// Stable filename slug for spec exports (matches spec_export command).
String packSpecSlug(final String name) {
  final s = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return s.isEmpty ? 'pack' : s;
}

dynamic yamlToJson(final dynamic node) {
  if (node is YamlMap) {
    return Map<String, dynamic>.fromEntries(
      node.entries.map(
        (final e) => MapEntry(e.key.toString(), yamlToJson(e.value)),
      ),
    );
  }
  if (node is YamlList) {
    return node.map(yamlToJson).toList(growable: false);
  }
  return node;
}

const _defaultLocaleTag = 'en';

/// E2E manifest: [spec_export.know_sources.v1].
class E2eKnowManifest {
  E2eKnowManifest({
    required this.version,
    required this.schema,
    required this.defaultLocale,
    required this.packs,
  });

  final int version;
  final String schema;
  final String defaultLocale;
  final List<E2eKnowPack> packs;

  static E2eKnowManifest parse(final Map<String, dynamic> map) {
    final schema = map['schema']?.toString() ?? '';
    if (schema != 'spec_export.know_sources.v1') {
      throw FormatException(
        'Unsupported manifest schema: $schema (expected spec_export.know_sources.v1)',
      );
    }
    final v = map['version'];
    final version = v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
    if (version != 1) {
      throw FormatException('Unsupported manifest version: $version');
    }
    final packsRaw = map['packs'];
    if (packsRaw is! List) {
      throw FormatException('manifest.packs must be a list');
    }
    final packs = <E2eKnowPack>[];
    for (final p in packsRaw) {
      if (p is! Map) {
        throw FormatException('Each pack must be a map');
      }
      packs.add(E2eKnowPack.fromMap(Map<String, dynamic>.from(p)));
    }
    return E2eKnowManifest(
      version: version,
      schema: schema,
      defaultLocale: map['default_locale']?.toString() ?? _defaultLocaleTag,
      packs: packs,
    );
  }

  static E2eKnowManifest loadFile(final String manifestPath) {
    final text = File(manifestPath).readAsStringSync();
    final root = yamlToJson(loadYaml(text));
    if (root is! Map<String, dynamic>) {
      throw FormatException('Manifest root must be a map');
    }
    return E2eKnowManifest.parse(root);
  }
}

class E2eKnowPack {
  E2eKnowPack({
    required this.name,
    this.path,
    this.url,
    this.format,
    this.network = false,
  });

  final String name;
  final String? path;
  final String? url;
  final String? format;
  final bool network;

  static E2eKnowPack fromMap(final Map<String, dynamic> m) {
    final name = m['name']?.toString() ?? '';
    if (name.isEmpty) {
      throw FormatException('pack.name is required');
    }
    final path = m['path']?.toString();
    final url = m['url']?.toString();
    final hasPath = path != null && path.isNotEmpty;
    final hasUrl = url != null && url.isNotEmpty;
    if (hasPath == hasUrl) {
      throw FormatException(
        'pack "$name": provide exactly one of path or url',
      );
    }
    return E2eKnowPack(
      name: name,
      path: hasPath ? path : null,
      url: hasUrl ? url : null,
      format: m['format']?.toString(),
      network: m['network'] == true,
    );
  }
}

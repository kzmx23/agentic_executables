import 'dart:io';

import 'package:agentic_executables_mcp/src/adapter.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('AeMcpAdapter.canonical', () {
    late Directory tempProject;
    late AeMcpAdapter adapter;

    setUp(() async {
      tempProject = await Directory.systemTemp.createTemp('mcp_can_');
      final hub = Directory(p.join(tempProject.path, '.ae_hub'));
      await hub.create();
      await File(p.join(hub.path, 'hub.yaml')).writeAsString('version: 1\n');
      adapter = AeMcpAdapter(resourcesPath: '/tmp/nonexistent');
    });

    tearDown(() async {
      await tempProject.delete(recursive: true);
    });

    test('init creates a new canonical pack', () async {
      final result = await adapter.canonical({
        'operation': 'init',
        'concept': 'ecs',
        'title': 'ECS',
        'root': tempProject.path,
      });
      expect(result['success'], isTrue);
      final metaFile = File(p.join(
        tempProject.path,
        '.ae_hub',
        'canonical',
        'ecs',
        'meta.yaml',
      ));
      expect(await metaFile.exists(), isTrue);
    });

    test('list returns saved concept ids', () async {
      await adapter.canonical({
        'operation': 'init',
        'concept': 'ecs',
        'title': 'ECS',
        'root': tempProject.path,
      });
      final result = await adapter.canonical({
        'operation': 'list',
        'root': tempProject.path,
      });
      expect(result['success'], isTrue);
      expect((result['data'] as Map)['concepts'], contains('ecs'));
    });

    test('snapshot freezes live + creates v1 dir', () async {
      await adapter.canonical({
        'operation': 'init',
        'concept': 'ecs',
        'title': 'ECS',
        'root': tempProject.path,
      });
      final result = await adapter.canonical({
        'operation': 'snapshot',
        'concept': 'ecs',
        'root': tempProject.path,
      });
      expect(result['success'], isTrue);
      final v1 = Directory(p.join(
        tempProject.path,
        '.ae_hub',
        'canonical',
        'ecs',
        'v1',
      ));
      expect(await v1.exists(), isTrue);
    });

    test('returns validation_error when operation missing', () async {
      final result = await adapter.canonical({});
      expect(result['success'], isFalse);
      expect((result['error'] as Map)['code'], 'validation_error');
    });

    test('returns validation_error for unknown operation', () async {
      final result = await adapter.canonical({
        'operation': 'frobnicate',
        'root': tempProject.path,
      });
      expect(result['success'], isFalse);
      expect((result['error'] as Map)['code'], 'validation_error');
    });
  });
}

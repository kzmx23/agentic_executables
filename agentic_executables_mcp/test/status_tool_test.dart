import 'dart:io';

import 'package:agentic_executables_mcp/src/adapter.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('AeMcpAdapter.status', () {
    late Directory tempProject;
    late AeMcpAdapter adapter;

    setUp(() async {
      tempProject = await Directory.systemTemp.createTemp('mcp_status_');
      final hub = Directory(p.join(tempProject.path, '.ae_hub'));
      await hub.create();
      await File(p.join(hub.path, 'hub.yaml')).writeAsString('version: 1\n');
      adapter = AeMcpAdapter(resourcesPath: '/tmp/nonexistent');
    });

    tearDown(() async {
      await tempProject.delete(recursive: true);
    });

    test('returns empty entries for an empty hub', () async {
      final result = await adapter.status({'root': tempProject.path});
      expect(result['success'], isTrue);
      final data = result['data'] as Map<String, dynamic>;
      expect(data['entries'], isEmpty);
      expect(data['tier_counts'], isA<Map>());
    });

    test('returns no_hub when missing', () async {
      final naked = await Directory.systemTemp.createTemp('mcp_status_naked_');
      try {
        final result = await adapter.status({'root': naked.path});
        expect(result['success'], isFalse);
        expect((result['error'] as Map)['code'], 'no_hub');
      } finally {
        await naked.delete(recursive: true);
      }
    });
  });
}

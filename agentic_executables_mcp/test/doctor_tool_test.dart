import 'dart:io';

import 'package:agentic_executables_mcp/src/adapter.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('AeMcpAdapter.doctor', () {
    late AeMcpAdapter adapter;

    setUp(() {
      adapter = AeMcpAdapter(resourcesPath: '/tmp/nonexistent');
    });

    test('returns ok envelope with checks list when target is writable',
        () async {
      final temp = await Directory.systemTemp.createTemp('mcp_doctor_ok_');
      addTearDown(() => temp.delete(recursive: true));

      final result = await adapter.doctor({
        'target': p.join(temp.path, 'skills'),
      });

      expect(result['success'], isTrue);
      final data = result['data'] as Map<String, dynamic>;
      expect(data['checks'], isA<List<dynamic>>());
      final checks = (data['checks'] as List).cast<Map<String, dynamic>>();
      final skillTarget = checks.firstWhere(
        (final entry) => entry['id'] == 'skill_target_writable',
      );
      expect(skillTarget['status'], 'ok');
      expect(skillTarget['critical'], isTrue);
    });

    test('skill_target_writable fails when target points at a file', () async {
      final temp = await Directory.systemTemp.createTemp('mcp_doctor_fail_');
      addTearDown(() => temp.delete(recursive: true));

      final blocked = File(p.join(temp.path, 'skills_file'));
      await blocked.writeAsString('not a directory');

      final result = await adapter.doctor({'target': blocked.path});

      expect(result['success'], isTrue);
      final data = result['data'] as Map<String, dynamic>;
      expect(data['overall_status'], 'fail');
      final checks = (data['checks'] as List).cast<Map<String, dynamic>>();
      final skillTarget = checks.firstWhere(
        (final entry) => entry['id'] == 'skill_target_writable',
      );
      expect(skillTarget['status'], 'fail');
      expect(skillTarget['critical'], isTrue);
    });

    test('returns validation_error when target is missing', () async {
      final result = await adapter.doctor(<String, dynamic>{});
      expect(result['success'], isFalse);
      expect(
        (result['error'] as Map<String, dynamic>)['code'],
        'validation_error',
      );
    });
  });
}

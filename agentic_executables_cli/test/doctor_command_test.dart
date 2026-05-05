import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  test('doctor succeeds when critical checks pass', () async {
    final temp = await Directory.systemTemp.createTemp('ae_doctor_ok_');
    addTearDown(() => temp.delete(recursive: true));

    final result = await runCli(
      ['doctor', '--target', p.join(temp.path, 'skills')],
      registryProbeUrl: 'mock://ok',
    );

    expect(result.exitCode, 0);
    expect(result.json['success'], isTrue);
    expect(result.json['data']['overall_status'], 'pass');

    final checks =
        (result.json['data']['checks'] as List).cast<Map<String, dynamic>>();
    final skillTarget = checks.firstWhere(
      (final entry) => entry['id'] == 'skill_target_writable',
    );
    final registry = checks.firstWhere(
      (final entry) => entry['id'] == 'registry_reachable',
    );

    expect(skillTarget['status'], 'ok');
    expect(registry['status'], 'ok');
  });

  test('doctor fails only when a critical check fails', () async {
    final temp = await Directory.systemTemp.createTemp('ae_doctor_fail_');
    addTearDown(() => temp.delete(recursive: true));

    final blockedTarget = File(p.join(temp.path, 'skills_file'));
    await blockedTarget.writeAsString('not a directory');

    final result = await runCli(
      ['doctor', '--target', blockedTarget.path],
      registryProbeUrl: 'mock://ok',
    );

    expect(result.exitCode, 1);
    expect(result.json['success'], isTrue);
    expect(result.json['data']['overall_status'], 'fail');

    final checks =
        (result.json['data']['checks'] as List).cast<Map<String, dynamic>>();
    final skillTarget = checks.firstWhere(
      (final entry) => entry['id'] == 'skill_target_writable',
    );
    expect(skillTarget['status'], 'fail');
    expect(skillTarget['critical'], isTrue);
  });
}

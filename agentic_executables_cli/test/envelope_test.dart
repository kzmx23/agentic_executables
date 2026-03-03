import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  test('definition returns standard JSON envelope', () async {
    final result = await runCli(['definition'], repoRoot: _repoRoot());

    expect(result.exitCode, 0);
    final json = result.json;
    expect(json['success'], isTrue);
    expect(json['command'], 'definition');
    expect(json['data'], isA<Map>());
    expect(json['warnings'], isA<List>());
    expect(json['meta'], isA<Map>());
  });

  test('validation failures return structured error envelope', () async {
    final result = await runCli([
      'registry',
      'get',
      '--library-id',
      'dart_provider',
    ], repoRoot: _repoRoot());

    expect(result.exitCode, 1);
    final json = result.json;
    expect(json['success'], isFalse);
    expect(json['error'], isA<Map>());
    expect((json['error'] as Map)['code'], 'validation_error');
  });
}

String _repoRoot() => '..';

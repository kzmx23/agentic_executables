import 'dart:io';

import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

import 'test_utils.dart';

class _FakeInferenceClient implements InferenceClient {
  @override
  String get id => 'fake-provider';

  @override
  bool get isAvailable => true;

  @override
  Future<AeResult<InferenceResponse>> infer(
    final InferenceRequest request,
  ) async =>
      AeResult.ok(
        const InferenceResponse(
          output: {
            'ae_install.md': '# install',
            'ae_uninstall.md': '# uninstall',
            'ae_update.md': '# update',
            'ae_use.md': '# use',
            'notes': 'from fake provider',
          },
        ),
      );
}

void main() {
  test('generate supports injected inference client implementation', () async {
    final temp = await Directory.systemTemp.createTemp('ae_cli_inference_');
    addTearDown(() => temp.delete(recursive: true));

    final result = await runCli(
      [
        'generate',
        '--library-id',
        'dart_provider',
        '--library-root',
        temp.path,
        '--output-dir',
        path.join(temp.path, 'ae_use'),
        '--engine',
        'codex',
        '--dry-run',
      ],
      repoRoot: '..',
      codexBinary: '/missing/codex',
      inferenceClient: _FakeInferenceClient(),
    );

    expect(result.exitCode, 0);
    expect(result.json['success'], isTrue);
    expect(result.json['data']['engine_used'], 'fake-provider');
  });
}

import 'dart:convert';

import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:test/test.dart';

class _FakeRunner implements ProcessRunner {
  _FakeRunner(this.responses);
  final List<ProcessRunResult> responses;
  final calls = <Map<String, dynamic>>[];
  int _i = 0;

  @override
  Future<ProcessRunResult> run({
    required final String executable,
    required final List<String> arguments,
    final String? stdinInput,
    final Map<String, String>? environment,
    final String? workingDirectory,
    final Duration? timeout,
  }) async {
    calls.add({
      'executable': executable,
      'arguments': arguments,
      'stdinInput': stdinInput,
    });
    final r = responses[_i.clamp(0, responses.length - 1)];
    _i++;
    return r;
  }
}

DistillationTask _sampleTask() => const DistillationTask(
      conceptId: 'ecs',
      conceptVersion: 1,
      sourceArtifact: DistillationSourceArtifact(
        name: 'rust_ecs',
        language: 'rust',
        files: ['src/lib.rs'],
        structuralSummary: '',
      ),
    );

String _validOutputJson() => jsonEncode({
      'schema': 'ae.canonical.draft.v1',
      'concept_id': 'ecs',
      'concept_version': 1,
      'index_md': '# ecs',
      'matrix': {
        'schema': 'ae.canonical_matrix.v1',
        'concept': 'ecs',
        'version': 1,
        'column_schema': [
          {'id': 'spec', 'type': 'text'},
        ],
        'features': [
          {'id': 'entity.create', 'spec': 'Make one.'},
        ],
      },
    });

void main() {
  group('CodexExecExecutor', () {
    test('executorId is codex', () {
      final ex = CodexExecExecutor(
        processRunner: _FakeRunner(const []),
        environment: const {},
      );
      expect(ex.executorId, 'codex');
    });

    test('canRun true when CODEX_HOME set', () async {
      final ex = CodexExecExecutor(
        processRunner: _FakeRunner(const []),
        environment: const {'CODEX_HOME': '/some/path'},
      );
      expect(await ex.canRun(), isTrue);
    });

    test('canRun true when OPENAI_CODEX_VERSION set', () async {
      final ex = CodexExecExecutor(
        processRunner: _FakeRunner(const []),
        environment: const {'OPENAI_CODEX_VERSION': '0.1.0'},
      );
      expect(await ex.canRun(), isTrue);
    });

    test('canRun false when no codex env', () async {
      final ex = CodexExecExecutor(
        processRunner: _FakeRunner(const []),
        environment: const {},
      );
      expect(await ex.canRun(), isFalse);
    });

    test('execute returns parsed output on success', () async {
      final runner = _FakeRunner([
        ProcessRunResult(exitCode: 0, stdout: _validOutputJson(), stderr: ''),
      ]);
      final ex = CodexExecExecutor(
        processRunner: runner,
        environment: const {'CODEX_HOME': '/x'},
      );
      final out = await ex.execute(_sampleTask());
      expect(out.conceptId, 'ecs');
      expect(runner.calls.first['executable'], 'codex');
      expect(runner.calls.first['arguments'], contains('exec'));
      // Task JSON delivered via stdin
      expect(runner.calls.first['stdinInput'], contains('"task"'));
    });

    test('execute throws on non-zero exit', () async {
      final runner = _FakeRunner([
        const ProcessRunResult(exitCode: 2, stdout: '', stderr: 'err'),
      ]);
      final ex = CodexExecExecutor(
        processRunner: runner,
        environment: const {'CODEX_HOME': '/x'},
      );
      expect(
        () => ex.execute(_sampleTask()),
        throwsA(isA<DistillationFailure>()),
      );
    });

    test('execute throws on invalid JSON', () async {
      final runner = _FakeRunner([
        const ProcessRunResult(exitCode: 0, stdout: 'nope', stderr: ''),
      ]);
      final ex = CodexExecExecutor(
        processRunner: runner,
        environment: const {'CODEX_HOME': '/x'},
      );
      expect(
        () => ex.execute(_sampleTask()),
        throwsA(isA<DistillationFailure>()),
      );
    });
  });
}

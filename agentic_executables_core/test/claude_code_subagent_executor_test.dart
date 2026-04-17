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
      'environment': environment,
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
        name: 'dart_ecs',
        language: 'dart',
        files: ['lib/src/world.dart'],
        structuralSummary: '# ecs\n\nExports: World',
      ),
    );

String _validOutputJson() => jsonEncode({
      'schema': 'ae.canonical.draft.v1',
      'concept_id': 'ecs',
      'concept_version': 1,
      'index_md': '# ecs\n\nDistilled.',
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
  group('ClaudeCodeSubagentExecutor', () {
    test('executorId is claude_code', () {
      final ex = ClaudeCodeSubagentExecutor(
        processRunner: _FakeRunner(const []),
        environment: const {},
      );
      expect(ex.executorId, 'claude_code');
    });

    test('canRun true when CLAUDECODE env is set', () async {
      final ex = ClaudeCodeSubagentExecutor(
        processRunner: _FakeRunner(const []),
        environment: const {'CLAUDECODE': '1'},
      );
      expect(await ex.canRun(), isTrue);
    });

    test('canRun true when CLAUDE_CODE_VERSION env is set', () async {
      final ex = ClaudeCodeSubagentExecutor(
        processRunner: _FakeRunner(const []),
        environment: const {'CLAUDE_CODE_VERSION': '2.0.0'},
      );
      expect(await ex.canRun(), isTrue);
    });

    test('canRun false when no claude env present', () async {
      final ex = ClaudeCodeSubagentExecutor(
        processRunner: _FakeRunner(const []),
        environment: const {},
      );
      expect(await ex.canRun(), isFalse);
    });

    test('execute returns parsed output on success', () async {
      final runner = _FakeRunner([
        ProcessRunResult(exitCode: 0, stdout: _validOutputJson(), stderr: ''),
      ]);
      final ex = ClaudeCodeSubagentExecutor(
        processRunner: runner,
        environment: const {'CLAUDECODE': '1'},
      );
      final out = await ex.execute(_sampleTask());
      expect(out.conceptId, 'ecs');
      expect(out.matrix.features.first.id.toString(), 'entity.create');
      // Verify it shells to `claude` with -p flag
      expect(runner.calls.first['executable'], 'claude');
      expect(runner.calls.first['arguments'], contains('-p'));
    });

    test('execute throws DistillationFailure on non-zero exit', () async {
      final runner = _FakeRunner([
        const ProcessRunResult(exitCode: 1, stdout: '', stderr: 'host error'),
      ]);
      final ex = ClaudeCodeSubagentExecutor(
        processRunner: runner,
        environment: const {'CLAUDECODE': '1'},
      );
      expect(
        () => ex.execute(_sampleTask()),
        throwsA(isA<DistillationFailure>()),
      );
    });

    test('execute throws DistillationFailure on invalid JSON', () async {
      final runner = _FakeRunner([
        const ProcessRunResult(exitCode: 0, stdout: 'not json', stderr: ''),
      ]);
      final ex = ClaudeCodeSubagentExecutor(
        processRunner: runner,
        environment: const {'CLAUDECODE': '1'},
      );
      expect(
        () => ex.execute(_sampleTask()),
        throwsA(isA<DistillationFailure>()),
      );
    });

    test('execute extracts JSON when wrapped in fences or prose', () async {
      final stdout = 'Sure, here you go:\n```json\n${_validOutputJson()}\n```\nDone.';
      final runner = _FakeRunner([
        ProcessRunResult(exitCode: 0, stdout: stdout, stderr: ''),
      ]);
      final ex = ClaudeCodeSubagentExecutor(
        processRunner: runner,
        environment: const {'CLAUDECODE': '1'},
      );
      final out = await ex.execute(_sampleTask());
      expect(out.conceptId, 'ecs');
    });
  });
}

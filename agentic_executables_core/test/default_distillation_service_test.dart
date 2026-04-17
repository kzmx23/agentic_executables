import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:test/test.dart';

class _FakeExecutor implements DistillationExecutor {
  _FakeExecutor({
    required this.id,
    required this.runnable,
    required this.responses,
  });

  @override
  final String id;
  final bool runnable;
  final List<dynamic> responses; // DistillationOutput | DistillationFailure
  int callCount = 0;

  @override
  String get executorId => id;

  @override
  Future<bool> canRun() async => runnable;

  @override
  Future<DistillationOutput> execute(final DistillationTask task) async {
    final r = responses[callCount.clamp(0, responses.length - 1)];
    callCount++;
    if (r is DistillationFailure) throw r;
    return r as DistillationOutput;
  }
}

DistillationTask _task() => const DistillationTask(
      conceptId: 'ecs',
      conceptVersion: 1,
      sourceArtifact: DistillationSourceArtifact(
        name: 'dart_ecs',
        language: 'dart',
        files: [],
        structuralSummary: '',
      ),
    );

DistillationOutput _output() => DistillationOutput(
      conceptId: 'ecs',
      conceptVersion: 1,
      indexMd: '# ecs',
      matrix: CanonicalMatrix(
        concept: 'ecs',
        version: 1,
        columnSchema: const [CanonicalColumn(id: 'spec', type: 'text')],
        features: [
          CanonicalFeature(
            id: FeatureId.parse('entity.create'),
            cells: const {'spec': 'Make one.'},
          ),
        ],
      ),
    );

void main() {
  group('DefaultDistillationService', () {
    test('dispatches to the first runnable executor in priority order',
        () async {
      final claude = _FakeExecutor(
        id: 'claude_code',
        runnable: true,
        responses: [_output()],
      );
      final codex = _FakeExecutor(
        id: 'codex',
        runnable: true,
        responses: [_output()],
      );
      final byok = _FakeExecutor(
        id: 'byok',
        runnable: true,
        responses: [_output()],
      );
      final svc = DefaultDistillationService(executors: [claude, codex, byok]);
      final out = await svc.distill(_task());
      expect(out.conceptId, 'ecs');
      expect(claude.callCount, 1);
      expect(codex.callCount, 0);
      expect(byok.callCount, 0);
    });

    test('falls through to next executor when first cannot run', () async {
      final claude = _FakeExecutor(
        id: 'claude_code',
        runnable: false,
        responses: [],
      );
      final codex = _FakeExecutor(
        id: 'codex',
        runnable: true,
        responses: [_output()],
      );
      final svc = DefaultDistillationService(executors: [claude, codex]);
      final out = await svc.distill(_task());
      expect(out.conceptId, 'ecs');
      expect(codex.callCount, 1);
    });

    test('retries once on schema validation failure', () async {
      final exec = _FakeExecutor(
        id: 'claude_code',
        runnable: true,
        responses: [
          const DistillationFailure('schema validation failed'),
          _output(),
        ],
      );
      final svc = DefaultDistillationService(executors: [exec]);
      final out = await svc.distill(_task());
      expect(out.conceptId, 'ecs');
      expect(exec.callCount, 2);
    });

    test('fails after second retry failure', () async {
      final exec = _FakeExecutor(
        id: 'claude_code',
        runnable: true,
        responses: [
          const DistillationFailure('first'),
          const DistillationFailure('second'),
        ],
      );
      final svc = DefaultDistillationService(executors: [exec]);
      expect(
        () => svc.distill(_task()),
        throwsA(isA<DistillationServiceFailure>()),
      );
      // Note: cannot read callCount across throw without try/catch — tested implicitly.
    });

    test('throws when no executor can run', () async {
      final exec = _FakeExecutor(
        id: 'claude_code',
        runnable: false,
        responses: [],
      );
      final svc = DefaultDistillationService(executors: [exec]);
      expect(
        () => svc.distill(_task()),
        throwsA(isA<DistillationServiceFailure>()),
      );
    });

    test('throws when executor list empty', () async {
      final svc = DefaultDistillationService(executors: const []);
      expect(
        () => svc.distill(_task()),
        throwsA(isA<DistillationServiceFailure>()),
      );
    });
  });
}

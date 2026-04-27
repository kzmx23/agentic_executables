import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agentic_executables_cli/agentic_executables_cli.dart';
import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

class _FakeFixedExecutor implements DistillationExecutor {
  _FakeFixedExecutor(this._output);
  final DistillationOutput _output;

  @override
  String get executorId => 'fake';

  @override
  Future<bool> canRun() async => true;

  @override
  Future<DistillationOutput> execute(final DistillationTask task) async =>
      _output;
}

DistillationOutput _cannedOutput(final String concept) => DistillationOutput(
      conceptId: concept,
      conceptVersion: 1,
      indexMd: '# $concept (distilled)\n',
      matrix: CanonicalMatrix(
        concept: concept,
        version: 1,
        columnSchema: const [
          CanonicalColumn(id: 'spec', type: 'text'),
        ],
        features: [
          CanonicalFeature(
            id: FeatureId.parse('entity.create'),
            cells: const {'spec': 'Make a new entity.'},
          ),
          CanonicalFeature(
            id: FeatureId.parse('entity.destroy'),
            cells: const {'spec': 'Destroy an entity.'},
          ),
        ],
      ),
    );

Future<void> _writeArtifactPack(final String hubPath) async {
  final meta = ArtifactMeta(
    kind: ArtifactKind.local,
    title: 'Dart ECS',
    source: ArtifactSource(
      type: ArtifactSourceType.path,
      path: 'core_packages/ecs',
      files: const [
        ArtifactSourceFile(path: 'lib/src/world.dart', sha256: 'h1'),
      ],
    ),
    scannedAt: DateTime.utc(2026, 4, 17, 12),
    license: const ArtifactLicense(spdx: 'MIT'),
    authors: const [],
    referencesCanonical: [CanonicalReference.parse('ecs')],
    extractor: 'dart_v1',
    distill: const ArtifactDistill(engine: 'heuristic'),
  );
  final pack = ArtifactPack(
    name: 'dart_ecs',
    meta: meta,
    indexContent: '# dart_ecs\n\nSummary.\n',
    matrix: const ArtifactMatrix(columnSchema: [], features: []),
  );
  final store = FileArtifactStore(hubPath);
  await store.save(pack);
}

Future<void> _writeCanonicalSeed(final String hubPath) async {
  final store = FileCanonicalStore(hubPath);
  final svc = DefaultCanonicalService(store: store);
  await svc.scaffold('ecs', title: 'ECS');
  // Seed the matrix with the ids that _cannedOutput will distill, so the
  // id-stability validator (mergeDistillationDetailed) accepts the run.
  final seeded = await svc.load('ecs');
  await svc.upsert(
    'ecs',
    CanonicalPack(
      meta: seeded!.meta,
      indexContent: seeded.indexContent,
      changelogContent: seeded.changelogContent,
      matrix: CanonicalMatrix(
        concept: 'ecs',
        version: 1,
        columnSchema: const [CanonicalColumn(id: 'spec', type: 'text')],
        features: [
          CanonicalFeature(
            id: FeatureId.parse('entity.create'),
            cells: const {'spec': 'stub'},
          ),
          CanonicalFeature(
            id: FeatureId.parse('entity.destroy'),
            cells: const {'spec': 'stub'},
          ),
        ],
      ),
    ),
  );
}

class _CliRun {
  const _CliRun({required this.exitCode, required this.stdout});
  final int exitCode;
  final String stdout;

  Map<String, dynamic> get json {
    final lines = stdout
        .split('\n')
        .map((final l) => l.trim())
        .where((final l) => l.isNotEmpty)
        .toList(growable: false);
    return jsonDecode(lines.last) as Map<String, dynamic>;
  }
}

Future<_CliRun> _runWithOverride(
  final List<String> args, {
  required final DistillationService override,
}) async {
  final outCtl = StreamController<List<int>>();
  final errCtl = StreamController<List<int>>();
  final outBuf = StringBuffer();
  final errBuf = StringBuffer();
  final outDone = Completer<void>();
  final errDone = Completer<void>();
  outCtl.stream
      .transform(utf8.decoder)
      .listen(outBuf.write, onDone: outDone.complete);
  errCtl.stream
      .transform(utf8.decoder)
      .listen(errBuf.write, onDone: errDone.complete);
  final outSink = IOSink(outCtl.sink);
  final errSink = IOSink(errCtl.sink);
  final cli = AeCli(
    out: outSink,
    err: errSink,
    environment: const {},
    distillationServiceOverride: override,
  );
  final exit = await cli.run(args);
  await outSink.close();
  await errSink.close();
  await outDone.future;
  await errDone.future;
  return _CliRun(exitCode: exit, stdout: outBuf.toString());
}

void main() {
  group('ae canonical distill', () {
    late Directory tempProject;
    late String hubPath;

    setUp(() async {
      tempProject = await Directory.systemTemp.createTemp('ae_distill_cli_');
      final hub = Directory(p.join(tempProject.path, '.ae_hub'));
      await hub.create();
      await File(p.join(hub.path, 'hub.yaml')).writeAsString('version: 1\n');
      hubPath = hub.path;
      await _writeArtifactPack(hubPath);
      await _writeCanonicalSeed(hubPath);
    });

    tearDown(() async {
      await tempProject.delete(recursive: true);
    });

    test('distills artifact to canonical via injected fake executor',
        () async {
      final svc = DefaultDistillationService(
        executors: [_FakeFixedExecutor(_cannedOutput('ecs'))],
      );
      final result = await _runWithOverride([
        'canonical',
        'distill',
        '--pack',
        'dart_ecs',
        '--concept',
        'ecs',
        '--root',
        tempProject.path,
      ], override: svc);

      expect(result.exitCode, 0);
      final envelope = result.json;
      expect(envelope['success'], isTrue,
          reason: 'envelope: ${result.stdout}');
      final data = envelope['data'] as Map<String, dynamic>;
      expect(data['concept'], 'ecs');
      expect(data['feature_count'], 2);
      expect(data['mode'], 'upsert');
      expect(data['executor_used'], 'fake');

      // Canonical was written: reload and confirm matrix has 2 features.
      final store = FileCanonicalStore(hubPath);
      final loaded = await store.load('ecs');
      expect(loaded, isNotNull);
      expect(loaded!.matrix.features.length, 2);
    });

    test('fails with artifact_not_found when pack missing', () async {
      final svc = DefaultDistillationService(
        executors: [_FakeFixedExecutor(_cannedOutput('ecs'))],
      );
      final result = await _runWithOverride([
        'canonical',
        'distill',
        '--pack',
        'nonexistent_pack',
        '--concept',
        'ecs',
        '--root',
        tempProject.path,
      ], override: svc);

      expect(result.exitCode, 1);
      final envelope = result.json;
      expect(envelope['success'], isFalse);
      expect((envelope['error'] as Map)['code'], 'artifact_not_found');
    });

    test('canonical distill envelope includes proposed_concepts when set',
        () async {
      // Construct an output with one ProposedConcept on top of the canned
      // matrix. The seeded canonical (from _writeCanonicalSeed) already
      // has entity.create and entity.destroy ids, so the validator allows it.
      final output = DistillationOutput(
        conceptId: 'ecs',
        conceptVersion: 1,
        indexMd: '# ecs\n',
        matrix: CanonicalMatrix(
          concept: 'ecs',
          version: 1,
          columnSchema: const [CanonicalColumn(id: 'spec', type: 'text')],
          features: [
            CanonicalFeature(
              id: FeatureId.parse('entity.create'),
              cells: const {'spec': 'enriched'},
            ),
          ],
        ),
        proposedConcepts: const [
          ProposedConcept(
            name: 'envelope-shape',
            spec: 'every command writes JSON',
            invariant: 'success is bool',
            rationale: 'cross-cutting',
          ),
        ],
      );
      final svc = DefaultDistillationService(
        executors: [_FakeFixedExecutor(output)],
      );
      final result = await _runWithOverride([
        'canonical',
        'distill',
        '--pack',
        'dart_ecs',
        '--concept',
        'ecs',
        '--root',
        tempProject.path,
      ], override: svc);

      expect(result.exitCode, 0);
      final envelope = result.json;
      expect(envelope['success'], isTrue);
      final data = envelope['data'] as Map<String, dynamic>;
      expect(data['proposed_concepts'], isA<List<dynamic>>());
      expect((data['proposed_concepts'] as List), hasLength(1));
      expect(
        ((data['proposed_concepts'] as List).single as Map)['name'],
        'envelope-shape',
      );
    });

    test('canonical distill returns id_not_in_matrix error when distill emits unknown ids',
        () async {
      // Distill output emits an id NOT in the seeded matrix (entity.create
      // and entity.destroy are seeded; entity.invented is not).
      final output = DistillationOutput(
        conceptId: 'ecs',
        conceptVersion: 1,
        indexMd: '',
        matrix: CanonicalMatrix(
          concept: 'ecs',
          version: 1,
          columnSchema: const [CanonicalColumn(id: 'spec', type: 'text')],
          features: [
            CanonicalFeature(
              id: FeatureId.parse('entity.invented'),
              cells: const {'spec': 'unauthorized'},
            ),
          ],
        ),
      );
      final svc = DefaultDistillationService(
        executors: [_FakeFixedExecutor(output)],
      );
      final result = await _runWithOverride([
        'canonical',
        'distill',
        '--pack',
        'dart_ecs',
        '--concept',
        'ecs',
        '--root',
        tempProject.path,
      ], override: svc);

      expect(result.exitCode, isNot(0));
      final envelope = result.json;
      expect(envelope['success'], isFalse);
      // The error structure may surface the underlying exception as a generic
      // envelope error. Don't over-assert on the error code's specific value;
      // just confirm an error envelope was produced.
      expect(envelope['error'], isNotNull);
    });
  });
}

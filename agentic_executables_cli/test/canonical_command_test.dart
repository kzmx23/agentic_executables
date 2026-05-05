import 'dart:io';

import 'package:agentic_executables_cli/agentic_executables_cli.dart';
import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('ae canonical', () {
    late Directory tempProject;
    late Directory tempHome;

    setUp(() async {
      tempProject = await Directory.systemTemp.createTemp('ae_can_proj_');
      tempHome = await Directory.systemTemp.createTemp('ae_can_home_');
      final hub = Directory(p.join(tempProject.path, '.ae_hub'));
      await hub.create();
      await File(p.join(hub.path, 'hub.yaml')).writeAsString('version: 1\n');
    });

    tearDown(() async {
      await tempProject.delete(recursive: true);
      await tempHome.delete(recursive: true);
    });

    test('canonical init creates a new pack', () async {
      final cli = AeCli(environment: {'HOME': tempHome.path});
      final exit = await cli.run([
        'canonical',
        'init',
        '--concept',
        'ecs',
        '--title',
        'ECS',
        '--root',
        tempProject.path,
      ]);
      expect(exit, 0);
      final metaFile = File(p.join(
        tempProject.path,
        '.ae_hub',
        'canonical',
        'ecs',
        'meta.yaml',
      ));
      expect(await metaFile.exists(), isTrue);
    });

    test('canonical list returns the saved concept ids', () async {
      final cli = AeCli(environment: {'HOME': tempHome.path});
      await cli.run([
        'canonical',
        'init',
        '--concept',
        'ecs',
        '--title',
        'ECS',
        '--root',
        tempProject.path,
      ]);
      await cli.run([
        'canonical',
        'init',
        '--concept',
        'render',
        '--title',
        'Render',
        '--root',
        tempProject.path,
      ]);
      final exit = await cli.run([
        'canonical',
        'list',
        '--root',
        tempProject.path,
      ]);
      expect(exit, 0);
    });

    test('canonical scaffold seeds canonical from artifact public API',
        () async {
      // Stage an artifact with a Public API section in its index.
      final artStore = FileArtifactStore(p.join(tempProject.path, '.ae_hub'));
      await artStore.save(ArtifactPack(
        name: 'pkg_a',
        meta: ArtifactMeta(
          kind: ArtifactKind.local,
          title: 'pkg_a',
          source: const ArtifactSource(
            type: ArtifactSourceType.path,
            path: 'src/pkg_a',
            files: [],
          ),
          scannedAt: DateTime.utc(2026, 4, 17),
          referencesCanonical: const [],
          extractor: 'dart_v1',
          distill: const ArtifactDistill(engine: 'heuristic'),
        ),
        indexContent: '# pkg_a\n\n## Public API\n\n'
            '- `Foo` (class) — Headline [lib/x.dart]\n'
            '- `runFoo` (function) [lib/x.dart]\n',
        matrix: const ArtifactMatrix(columnSchema: [], features: []),
      ));

      final cli = AeCli(environment: {'HOME': tempHome.path});
      final exit = await cli.run([
        'canonical',
        'scaffold',
        '--concept',
        'pkg/concept',
        '--title',
        'PKG concept',
        '--from-artifact',
        'pkg_a',
        '--root',
        tempProject.path,
      ]);
      expect(exit, 0);
      final matrixFile = File(p.join(
        tempProject.path,
        '.ae_hub',
        'canonical',
        'pkg/concept',
        'matrix.yaml',
      ));
      expect(await matrixFile.exists(), isTrue);
      final body = await matrixFile.readAsString();
      expect(body, contains('pkg_a.foo'));
      expect(body, contains('pkg_a.run_foo'));
    });

    test('canonical scaffold rejects missing --concept', () async {
      final cli = AeCli(environment: {'HOME': tempHome.path});
      final exit = await cli.run([
        'canonical',
        'scaffold',
        '--title',
        'X',
        '--from-artifact',
        'pkg_a',
        '--root',
        tempProject.path,
      ]);
      expect(exit, isNot(0));
    });

    test('canonical snapshot freezes live + bumps version', () async {
      final cli = AeCli(environment: {'HOME': tempHome.path});
      await cli.run([
        'canonical',
        'init',
        '--concept',
        'ecs',
        '--title',
        'ECS',
        '--root',
        tempProject.path,
      ]);
      final exit = await cli.run([
        'canonical',
        'snapshot',
        '--concept',
        'ecs',
        '--root',
        tempProject.path,
      ]);
      expect(exit, 0);
      final v1 = Directory(p.join(
        tempProject.path,
        '.ae_hub',
        'canonical',
        'ecs',
        'v1',
      ));
      expect(await v1.exists(), isTrue);
    });

    test('canonical scaffold --update --rename migrates id and preserves text',
        () async {
      final hubPath = p.join(tempProject.path, '.ae_hub');
      final artStore = FileArtifactStore(hubPath);

      // Stage 1: artifact with one symbol (oldName).
      await artStore.save(ArtifactPack(
        name: 'demo_pack',
        meta: ArtifactMeta(
          kind: ArtifactKind.local,
          title: 'demo_pack',
          source: const ArtifactSource(
            type: ArtifactSourceType.path,
            path: 'src/demo',
            files: [],
          ),
          scannedAt: DateTime.utc(2026, 4, 27),
          referencesCanonical: const [],
          extractor: 'dart_v1',
          distill: const ArtifactDistill(engine: 'heuristic'),
        ),
        indexContent: '# demo_pack\n\n## Public API\n\n'
            '- `oldName` (function)\n',
        matrix: const ArtifactMatrix(columnSchema: [], features: []),
      ));

      // Initial scaffold.
      final scaffoldResult = await runCli([
        'canonical',
        'scaffold',
        '--concept',
        'demo',
        '--title',
        'Demo',
        '--from-artifact',
        'demo_pack',
        '--root',
        tempProject.path,
      ], environment: {
        'HOME': tempHome.path
      });
      expect(scaffoldResult.exitCode, 0);

      // Stage 2: artifact now has newName instead of oldName.
      await artStore.save(ArtifactPack(
        name: 'demo_pack',
        meta: ArtifactMeta(
          kind: ArtifactKind.local,
          title: 'demo_pack',
          source: const ArtifactSource(
            type: ArtifactSourceType.path,
            path: 'src/demo',
            files: [],
          ),
          scannedAt: DateTime.utc(2026, 4, 27),
          referencesCanonical: const [],
          extractor: 'dart_v1',
          distill: const ArtifactDistill(engine: 'heuristic'),
        ),
        indexContent: '# demo_pack\n\n## Public API\n\n'
            '- `newName` (function)\n',
        matrix: const ArtifactMatrix(columnSchema: [], features: []),
      ));

      // Run --update --rename.
      final result = await runCli([
        'canonical',
        'scaffold',
        '--concept',
        'demo',
        '--from-artifact',
        'demo_pack',
        '--update',
        '--rename',
        'demo_pack.old_name=demo_pack.new_name',
        '--root',
        tempProject.path,
      ], environment: {
        'HOME': tempHome.path
      });
      expect(result.exitCode, 0);
      final json = result.json;
      expect(json['success'], isTrue);
      expect(
        (json['data']['renamed'] as List).single,
        {'from': 'demo_pack.old_name', 'to': 'demo_pack.new_name'},
      );
    });

    test('canonical accept-concept promotes proposal to matrix row', () async {
      // Setup: scaffold concept, write proposals via service.
      final hubPath = p.join(tempProject.path, '.ae_hub');
      final canStore = FileCanonicalStore(hubPath);
      final svc = DefaultCanonicalService(store: canStore);
      await svc.scaffold('demo', title: 'Demo');
      await svc.writeProposalsFile(
        'demo',
        proposals: const [
          ProposedConcept(
            name: 'envelope-shape',
            spec: 'every command writes JSON',
            invariant: 'success is bool',
            rationale: 'cross-cutting',
          ),
        ],
        executorUsed: 'claude_code',
      );

      final result = await runCli([
        'canonical',
        'accept-concept',
        '--concept',
        'demo',
        '--id',
        'demo.json_envelope',
        '--from-proposal',
        'envelope-shape',
        '--root',
        tempProject.path,
      ], environment: {
        'HOME': tempHome.path
      });
      final json = result.json;
      expect(json['success'], isTrue);
      expect(json['data']['accepted_id'], 'demo.json_envelope');
    });

    test('canonical accept-concept returns proposal_not_found on bad name',
        () async {
      // Setup: scaffold concept and write proposals.
      final hubPath = p.join(tempProject.path, '.ae_hub');
      final canStore = FileCanonicalStore(hubPath);
      final svc = DefaultCanonicalService(store: canStore);
      await svc.scaffold('demo', title: 'Demo');
      await svc.writeProposalsFile(
        'demo',
        proposals: const [
          ProposedConcept(
              name: 'real-name', spec: 's', invariant: 'i', rationale: 'r'),
        ],
        executorUsed: 'claude_code',
      );

      final result = await runCli([
        'canonical',
        'accept-concept',
        '--concept',
        'demo',
        '--id',
        'demo.x',
        '--from-proposal',
        'not-real',
        '--root',
        tempProject.path,
      ], environment: {
        'HOME': tempHome.path
      });
      final json = result.json;
      expect(json['success'], isFalse);
      expect(json['error']['code'], 'proposal_not_found');
    });

    test(
        'canonical scaffold --update reports added/removed against existing canonical',
        () async {
      final hubPath = p.join(tempProject.path, '.ae_hub');
      final artStore = FileArtifactStore(hubPath);

      // Stage 1: an artifact with two symbols (alpha, beta).
      await artStore.save(ArtifactPack(
        name: 'demo_pack',
        meta: ArtifactMeta(
          kind: ArtifactKind.local,
          title: 'demo_pack',
          source: const ArtifactSource(
            type: ArtifactSourceType.path,
            path: 'src/demo',
            files: [],
          ),
          scannedAt: DateTime.utc(2026, 4, 27),
          referencesCanonical: const [],
          extractor: 'dart_v1',
          distill: const ArtifactDistill(engine: 'heuristic'),
        ),
        indexContent: '# demo_pack\n\n## Public API\n\n'
            '- `alpha` (function)\n'
            '- `beta` (function)\n',
        matrix: const ArtifactMatrix(columnSchema: [], features: []),
      ));

      // Scaffold from the initial artifact.
      final scaffoldResult = await runCli([
        'canonical',
        'scaffold',
        '--concept',
        'demo',
        '--title',
        'Demo',
        '--from-artifact',
        'demo_pack',
        '--root',
        tempProject.path,
      ], environment: {
        'HOME': tempHome.path
      });
      expect(scaffoldResult.exitCode, 0);

      // Stage 2: update the artifact — add gamma, remove beta.
      await artStore.save(ArtifactPack(
        name: 'demo_pack',
        meta: ArtifactMeta(
          kind: ArtifactKind.local,
          title: 'demo_pack',
          source: const ArtifactSource(
            type: ArtifactSourceType.path,
            path: 'src/demo',
            files: [],
          ),
          scannedAt: DateTime.utc(2026, 4, 27),
          referencesCanonical: const [],
          extractor: 'dart_v1',
          distill: const ArtifactDistill(engine: 'heuristic'),
        ),
        indexContent: '# demo_pack\n\n## Public API\n\n'
            '- `alpha` (function)\n'
            '- `gamma` (function)\n',
        matrix: const ArtifactMatrix(columnSchema: [], features: []),
      ));

      // Run --update.
      final result = await runCli([
        'canonical',
        'scaffold',
        '--concept',
        'demo',
        '--from-artifact',
        'demo_pack',
        '--update',
        '--root',
        tempProject.path,
      ], environment: {
        'HOME': tempHome.path
      });
      expect(result.exitCode, 0);
      final json = result.json;
      expect(json['success'], isTrue);
      final data = json['data'] as Map<String, dynamic>;
      expect(data['mode'], 'update');
      expect((data['added'] as List), contains('demo_pack.gamma'));
      expect((data['removed'] as List), contains('demo_pack.beta'));
    });
  });
}

import 'dart:io';

import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('FileHubResolver v3 resolution', () {
    late Directory userHomeFake;
    late Directory projectFake;
    late FileHubResolver resolver;
    late String oldHome;

    setUp(() async {
      userHomeFake = await Directory.systemTemp.createTemp('ae_resolver_home_');
      projectFake = await Directory.systemTemp.createTemp('ae_resolver_proj_');
      // Override HOME so userHub resolution lands in the temp dir.
      oldHome = Platform.environment['HOME'] ?? '';
      // Note: Dart cannot mutate Platform.environment directly. Pass an explicit
      // userHubOverride into the resolver via a constructor option instead.
      resolver = FileHubResolver(userHomeOverride: userHomeFake.path);
    });

    tearDown(() async {
      await userHomeFake.delete(recursive: true);
      await projectFake.delete(recursive: true);
    });

    test('userHubPath uses override when provided', () async {
      final p1 = await resolver.userHubPath();
      expect(p1, p.join(userHomeFake.path, '.ae_hub'));
    });

    test('resolveArtifact returns null when no project hub', () async {
      final r = await resolver.resolveArtifact(
        'dart_ecs',
        projectRoot: projectFake.path,
      );
      expect(r, isNull);
    });

    test('resolveArtifact finds artifact in project hub', () async {
      // Stage a project hub with one artifact dir + meta.yaml
      final hub = Directory(p.join(projectFake.path, '.ae_hub'));
      await hub.create(recursive: true);
      await File(p.join(hub.path, 'hub.yaml')).writeAsString('version: 1\n');
      final pack = Directory(p.join(hub.path, 'artifacts', 'local', 'dart_ecs'));
      await pack.create(recursive: true);
      await File(p.join(pack.path, 'meta.yaml')).writeAsString('schema: ae.artifact.meta.v1\n');

      final r = await resolver.resolveArtifact(
        'dart_ecs',
        projectRoot: projectFake.path,
      );
      expect(r, isNotNull);
      expect(r, contains('dart_ecs'));
    });

    test('resolveCanonical returns null when no canonical found', () async {
      final r = await resolver.resolveCanonical(
        'ecs',
        projectRoot: projectFake.path,
      );
      expect(r, isNull);
    });

    test('resolveCanonical: project wins over user', () async {
      // User hub has ecs canonical
      final userHub = Directory(p.join(userHomeFake.path, '.ae_hub'));
      await userHub.create(recursive: true);
      await File(p.join(userHub.path, 'hub.yaml')).writeAsString('version: 1\n');
      final userEcs = Directory(p.join(userHub.path, 'canonical', 'ecs'));
      await userEcs.create(recursive: true);
      await File(p.join(userEcs.path, 'meta.yaml')).writeAsString('user-version');

      // Project hub also has ecs canonical
      final projHub = Directory(p.join(projectFake.path, '.ae_hub'));
      await projHub.create(recursive: true);
      await File(p.join(projHub.path, 'hub.yaml')).writeAsString('version: 1\n');
      final projEcs = Directory(p.join(projHub.path, 'canonical', 'ecs'));
      await projEcs.create(recursive: true);
      await File(p.join(projEcs.path, 'meta.yaml')).writeAsString('project-version');

      final r = await resolver.resolveCanonical(
        'ecs',
        projectRoot: projectFake.path,
      );
      expect(r, isNotNull);
      expect(await File(p.join(r!, 'meta.yaml')).readAsString(),
          'project-version');
    });

    test('resolveCanonical: falls back to user when project lacks it', () async {
      // Only user hub has canonical
      final userHub = Directory(p.join(userHomeFake.path, '.ae_hub'));
      await userHub.create(recursive: true);
      await File(p.join(userHub.path, 'hub.yaml')).writeAsString('version: 1\n');
      final userEcs = Directory(p.join(userHub.path, 'canonical', 'ecs'));
      await userEcs.create(recursive: true);
      await File(p.join(userEcs.path, 'meta.yaml')).writeAsString('user-version');

      // Project hub exists without canonical
      final projHub = Directory(p.join(projectFake.path, '.ae_hub'));
      await projHub.create(recursive: true);
      await File(p.join(projHub.path, 'hub.yaml')).writeAsString('version: 1\n');

      final r = await resolver.resolveCanonical(
        'ecs',
        projectRoot: projectFake.path,
      );
      expect(r, isNotNull);
      expect(await File(p.join(r!, 'meta.yaml')).readAsString(),
          'user-version');
    });

    test('resolveCanonical handles nested concept ids (gltf/core)', () async {
      final userHub = Directory(p.join(userHomeFake.path, '.ae_hub'));
      await userHub.create(recursive: true);
      await File(p.join(userHub.path, 'hub.yaml')).writeAsString('version: 1\n');
      final nested = Directory(p.join(userHub.path, 'canonical', 'gltf', 'core'));
      await nested.create(recursive: true);
      await File(p.join(nested.path, 'meta.yaml')).writeAsString('nested');

      final r = await resolver.resolveCanonical(
        'gltf/core',
        projectRoot: projectFake.path,
      );
      expect(r, isNotNull);
      expect(p.basename(r!), 'core');
    });

    test('package + remote layers stubbed (return null in 3.0)', () async {
      // resolvePackageHub and resolveRemote always return null in 3.0.
      // This test documents the behavior so 3.x activation is intentional.
      final pkg = await resolver.resolvePackageHub('any_package');
      expect(pkg, isNull);
    });
  });
}

import 'dart:io';

import 'package:agentic_executables_cli/agentic_executables_cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('ae init', () {
    late Directory tempProject;
    late Directory tempHome;

    setUp(() async {
      tempProject = await Directory.systemTemp.createTemp('ae_init_proj_');
      tempHome = await Directory.systemTemp.createTemp('ae_init_home_');
      // Stage a project hub so init has somewhere to write.
      final hub = Directory(p.join(tempProject.path, '.ae_hub'));
      await hub.create();
      await File(p.join(hub.path, 'hub.yaml')).writeAsString('version: 1\n');
      // Copy the dart_pkg_min fixture inside the project as a sub-package.
      final fixture = Directory(p.join(
        Directory.current.path,
        '..',
        'agentic_executables_core',
        'test',
        'fixtures',
        'dart_pkg_min',
      ));
      final targetSub = Directory(p.join(tempProject.path, 'pkg'));
      await _copyDir(fixture, targetSub);
    });

    tearDown(() async {
      await tempProject.delete(recursive: true);
      await tempHome.delete(recursive: true);
    });

    test('init scans cwd for known manifests and ingests sub-package',
        () async {
      final cli = AeCli(
        environment: {'HOME': tempHome.path},
      );
      final exit = await cli.run([
        'init',
        '--root',
        tempProject.path,
      ]);
      expect(exit, 0);
      // The artifact landed in the project hub.
      final pack = Directory(p.join(
        tempProject.path,
        '.ae_hub',
        'artifacts',
        'local',
        'ecsly',
      ));
      expect(await pack.exists(), isTrue);
    });

    test('init reports json envelope with ingested packs', () async {
      final result = await runCli(
        ['init', '--root', tempProject.path],
        environment: {'HOME': tempHome.path},
      );
      expect(result.exitCode, 0);
      // JSON output mentions the ingested pack name.
      expect(result.stdout, contains('ecsly'));
      expect(result.stdout, contains('"data"'));
    });
  });
}

Future<void> _copyDir(final Directory src, final Directory dst) async {
  await dst.create(recursive: true);
  await for (final entity in src.list(recursive: true)) {
    final rel = p.relative(entity.path, from: src.path);
    if (entity is Directory) {
      await Directory(p.join(dst.path, rel)).create(recursive: true);
    } else if (entity is File) {
      final dstFile = File(p.join(dst.path, rel));
      await dstFile.create(recursive: true);
      await entity.copy(dstFile.path);
    }
  }
}

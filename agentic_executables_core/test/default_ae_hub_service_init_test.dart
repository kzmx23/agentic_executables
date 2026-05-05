import 'dart:io';

import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('DefaultAeHubService.init (v3 layout)', () {
    late Directory tempParent;
    late DefaultAeHubService service;

    setUp(() async {
      tempParent = await Directory.systemTemp.createTemp('ae_hub_init_');
      service = DefaultAeHubService(FileHubResolver());
    });

    tearDown(() async {
      if (await tempParent.exists()) {
        await tempParent.delete(recursive: true);
      }
    });

    test('--path X nests hub under X/.ae_hub/ with v3 subdirs', () async {
      final result = await service.init(HubInitInput(path: tempParent.path));
      expect(result.success, isTrue, reason: result.error?.message);

      final expectedHub = p.join(tempParent.path, '.ae_hub');
      expect(result.data!.path, expectedHub);
      expect(await Directory(expectedHub).exists(), isTrue);
      expect(
        await File(p.join(expectedHub, 'hub.yaml')).exists(),
        isTrue,
      );

      // v3 subdirs created
      expect(
        await Directory(p.join(expectedHub, 'canonical')).exists(),
        isTrue,
      );
      expect(
        await Directory(p.join(expectedHub, 'artifacts', 'local')).exists(),
        isTrue,
      );
      expect(
        await Directory(p.join(expectedHub, 'artifacts', 'external')).exists(),
        isTrue,
      );
      expect(
        await Directory(p.join(expectedHub, 'artifacts', 'use')).exists(),
        isTrue,
      );

      // v2 dirs NOT created
      expect(
        await Directory(p.join(expectedHub, 'know')).exists(),
        isFalse,
        reason: 'know/ is v2 layout and should not be scaffolded',
      );
      expect(
        await Directory(p.join(expectedHub, 'packages')).exists(),
        isFalse,
        reason: 'packages/ is v2 layout and should not be scaffolded',
      );
      // Note: top-level use/ should not exist (v2). The v3 layout puts use
      // under artifacts/use/. We check the LITERAL top-level path here.
      final topLevelUse = Directory(p.join(expectedHub, 'use'));
      expect(
        await topLevelUse.exists(),
        isFalse,
        reason: 'top-level use/ is v2; v3 nests it under artifacts/use/',
      );

      // Naked hub at --path is NOT created
      expect(
        await File(p.join(tempParent.path, 'hub.yaml')).exists(),
        isFalse,
        reason: 'hub.yaml must nest under .ae_hub/, not the parent dir',
      );
    });

    test('--project nests hub under <cwd>/.ae_hub/', () async {
      final originalCwd = Directory.current;
      try {
        Directory.current = tempParent;
        final result = await service.init(const HubInitInput(project: true));
        expect(result.success, isTrue, reason: result.error?.message);

        final expectedHub = p.join(tempParent.path, '.ae_hub');
        // Realpath comparison (on macOS /tmp may resolve to /private/tmp).
        expect(
          File(result.data!.path).resolveSymbolicLinksSync(),
          File(expectedHub).resolveSymbolicLinksSync(),
        );
        expect(
          await Directory(p.join(result.data!.path, 'canonical')).exists(),
          isTrue,
        );
      } finally {
        Directory.current = originalCwd;
      }
    });

    test('default resolution always nests under .ae_hub leaf', () async {
      // We don't have an injectable $HOME in DefaultAeHubService, but we can
      // assert the resolution invariant by feeding --path and observing the
      // returned path always ends with `/.ae_hub`. The HOME branch shares
      // the same join logic.
      final result = await service.init(HubInitInput(path: tempParent.path));
      expect(result.success, isTrue);
      expect(p.basename(result.data!.path), '.ae_hub');
    });

    test('idempotent: second init returns created=false', () async {
      final r1 = await service.init(HubInitInput(path: tempParent.path));
      expect(r1.success, isTrue);
      expect(r1.data!.created, isTrue);

      final r2 = await service.init(HubInitInput(path: tempParent.path));
      expect(r2.success, isTrue);
      expect(r2.data!.created, isFalse);
    });
  });
}

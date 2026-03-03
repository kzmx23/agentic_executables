import 'dart:io';

import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('DefaultAeInstructionService', () {
    late Directory tempDir;
    late DefaultAeInstructionService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ae_core_docs_');
      await File(
        p.join(tempDir.path, 'ae_context.md'),
      ).writeAsString('context');
      await File(
        p.join(tempDir.path, 'ae_bootstrap.md'),
      ).writeAsString('bootstrap');
      await File(p.join(tempDir.path, 'ae_use.md')).writeAsString('use');

      service = DefaultAeInstructionService(FileDocumentStore(tempDir.path));
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('loads bootstrap docs for library context', () async {
      final result = await service.getInstructions(
        const GetInstructionsInput(
          context: AeContext.library,
          action: AeAction.bootstrap,
        ),
      );

      expect(result.success, isTrue);
      final data = result.data!;
      expect(
        data.documents.keys,
        containsAll(['ae_context.md', 'ae_bootstrap.md']),
      );
      expect(data.documents.keys, isNot(contains('ae_use.md')));
    });

    test('loads context and use docs for project install', () async {
      final result = await service.getInstructions(
        const GetInstructionsInput(
          context: AeContext.project,
          action: AeAction.install,
        ),
      );

      expect(result.success, isTrue);
      final data = result.data!;
      expect(data.documents.keys, containsAll(['ae_context.md', 'ae_use.md']));
    });

    test('rejects invalid bootstrap on project context', () async {
      final result = await service.getInstructions(
        const GetInstructionsInput(
          context: AeContext.project,
          action: AeAction.bootstrap,
        ),
      );

      expect(result.success, isFalse);
      expect(result.error?.code, 'instructions_failed');
    });
  });
}

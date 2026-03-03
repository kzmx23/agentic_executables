import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:test/test.dart';

class _FakeEngine implements GenerationEngine {
  _FakeEngine({
    required this.id,
    required this.isAvailable,
    required this.result,
  });

  @override
  final String id;

  @override
  final bool isAvailable;

  final AeResult<GenerateOutput> result;

  @override
  Future<AeResult<GenerateOutput>> generate(final GenerateInput input) async =>
      result;
}

GenerateOutput _validOutput(final String engine) => GenerateOutput(
      libraryId: 'dart_provider',
      engineUsed: engine,
      files: const [
        GeneratedFile(path: 'ae_install.md', content: 'a'),
        GeneratedFile(path: 'ae_uninstall.md', content: 'b'),
        GeneratedFile(path: 'ae_update.md', content: 'c'),
        GeneratedFile(path: 'ae_use.md', content: 'd'),
      ],
    );

void main() {
  test('auto mode prefers available codex engine', () async {
    final service = DefaultAeGenerationService(
      templateEngine: _FakeEngine(
        id: 'template',
        isAvailable: true,
        result: AeResult.ok(_validOutput('template')),
      ),
      codexEngine: _FakeEngine(
        id: 'codex',
        isAvailable: true,
        result: AeResult.ok(_validOutput('codex')),
      ),
    );

    final result = await service.generate(
      const GenerateInput(
        libraryId: 'dart_provider',
        libraryRoot: '/tmp/repo',
        outputDir: '/tmp/repo/ae_use',
      ),
    );

    expect(result.success, isTrue);
    expect(result.data?.engineUsed, 'codex');
  });

  test('auto mode falls back to template when codex unavailable', () async {
    final service = DefaultAeGenerationService(
      templateEngine: _FakeEngine(
        id: 'template',
        isAvailable: true,
        result: AeResult.ok(_validOutput('template')),
      ),
      codexEngine: _FakeEngine(
        id: 'codex',
        isAvailable: false,
        result: AeResult.ok(_validOutput('codex')),
      ),
    );

    final result = await service.generate(
      const GenerateInput(
        libraryId: 'dart_provider',
        libraryRoot: '/tmp/repo',
        outputDir: '/tmp/repo/ae_use',
      ),
    );

    expect(result.success, isTrue);
    expect(result.data?.engineUsed, 'template');
    expect(result.warnings.join(' '), contains('Codex binary not detected'));
  });

  test('codex mode fails when codex unavailable', () async {
    final service = DefaultAeGenerationService(
      templateEngine: _FakeEngine(
        id: 'template',
        isAvailable: true,
        result: AeResult.ok(_validOutput('template')),
      ),
      codexEngine: _FakeEngine(
        id: 'codex',
        isAvailable: false,
        result: AeResult.ok(_validOutput('codex')),
      ),
    );

    final result = await service.generate(
      const GenerateInput(
        libraryId: 'dart_provider',
        libraryRoot: '/tmp/repo',
        outputDir: '/tmp/repo/ae_use',
        engineMode: AeGenerationEngineMode.codex,
      ),
    );

    expect(result.success, isFalse);
    expect(result.error?.code, 'engine_unavailable');
  });
}

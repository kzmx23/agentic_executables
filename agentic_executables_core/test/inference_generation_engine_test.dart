import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:test/test.dart';

class _FakeInferenceClient implements InferenceClient {
  _FakeInferenceClient({required this.result, this.available = true});

  final AeResult<InferenceResponse> result;
  final bool available;

  @override
  String get id => 'fake-inference';

  @override
  bool get isAvailable => available;

  @override
  Future<AeResult<InferenceResponse>> infer(final InferenceRequest request) =>
      Future.value(result);
}

void main() {
  test('maps inference output into generated files', () async {
    final engine = InferenceGenerationEngine(
      client: _FakeInferenceClient(
        result: AeResult.ok(
          const InferenceResponse(
            output: {
              'ae_install.md': '# install',
              'ae_uninstall.md': '# uninstall',
              'ae_update.md': '# update',
              'ae_use.md': '# use',
              'notes': 'generated',
            },
          ),
        ),
      ),
    );

    final result = await engine.generate(
      const GenerateInput(
        libraryId: 'dart_provider',
        libraryRoot: '/tmp/repo',
        outputDir: '/tmp/repo/ae_use',
      ),
    );

    expect(result.success, isTrue);
    expect(result.data?.engineUsed, 'fake-inference');
    expect(result.data?.files.length, 4);
    expect(result.data?.notes, 'generated');
  });

  test('fails when required output file is missing', () async {
    final engine = InferenceGenerationEngine(
      client: _FakeInferenceClient(
        result: AeResult.ok(
          const InferenceResponse(
            output: {
              'ae_install.md': '# install',
              'ae_uninstall.md': '# uninstall',
              'ae_update.md': '# update',
            },
          ),
        ),
      ),
    );

    final result = await engine.generate(
      const GenerateInput(
        libraryId: 'dart_provider',
        libraryRoot: '/tmp/repo',
        outputDir: '/tmp/repo/ae_use',
      ),
    );

    expect(result.success, isFalse);
    expect(result.error?.code, 'inference_output_invalid');
  });
}

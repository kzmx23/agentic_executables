import '../config/ae_core_config.dart';
import '../models/ae_result.dart';
import '../models/generate.dart';
import '../models/inference.dart';
import '../ports/generation_engine.dart';
import '../ports/inference_client.dart';

typedef GenerationPromptBuilder = String Function(GenerateInput input);

class InferenceGenerationEngine implements GenerationEngine {
  InferenceGenerationEngine({
    required InferenceClient client,
    GenerationPromptBuilder? promptBuilder,
  })  : _client = client,
        _promptBuilder = promptBuilder ?? _defaultPromptBuilder;

  final InferenceClient _client;
  final GenerationPromptBuilder _promptBuilder;

  @override
  String get id => _client.id;

  @override
  bool get isAvailable => _client.isAvailable;

  @override
  Future<AeResult<GenerateOutput>> generate(final GenerateInput input) async {
    final inference = await _client.infer(
      InferenceRequest(
        prompt: _promptBuilder(input),
        outputSchema: _outputSchema(),
        workingDirectory: input.libraryRoot,
        metadata: {'library_id': input.libraryId},
      ),
    );

    if (!inference.success || inference.data == null) {
      return AeResult.fail(
        code: inference.error?.code ?? 'inference_failed',
        message: inference.error?.message ?? 'Inference generation failed',
        details: inference.error?.details,
        warnings: inference.warnings,
        meta: {...inference.meta, 'engine': id},
      );
    }

    final payload = inference.data!.output;
    final files = <GeneratedFile>[];
    for (final fileName in AeCoreConfig.requiredRegistryFiles) {
      final content = payload[fileName];
      if (content is! String || content.trim().isEmpty) {
        return AeResult.fail(
          code: 'inference_output_invalid',
          message: 'Inference output missing required file: $fileName',
          warnings: inference.warnings,
          meta: {...inference.meta, 'engine': id},
        );
      }
      files.add(GeneratedFile(path: fileName, content: content));
    }

    final notesRaw = payload['notes'];
    final notes =
        notesRaw is String && notesRaw.trim().isNotEmpty ? notesRaw : null;

    return AeResult.ok(
      GenerateOutput(
        libraryId: input.libraryId,
        engineUsed: id,
        files: files,
        notes: notes,
      ),
      warnings: [...inference.warnings, ...inference.data!.warnings],
      meta: {...inference.meta, ...inference.data!.meta, 'engine': id},
    );
  }

  Map<String, dynamic> _outputSchema() {
    final properties = <String, dynamic>{
      for (final file in AeCoreConfig.requiredRegistryFiles)
        file: const {'type': 'string'},
      'notes': const {'type': 'string'},
    };

    return {
      'type': 'object',
      'required': [...AeCoreConfig.requiredRegistryFiles, 'notes'],
      'properties': properties,
      'additionalProperties': false,
    };
  }

  static String _defaultPromptBuilder(final GenerateInput input) => '''
Generate Agentic Executable markdown files for library id "${input.libraryId}".
Return JSON only, matching the provided schema.
Requirements:
- Include exactly ae_install.md, ae_uninstall.md, ae_update.md, ae_use.md.
- Keep content concise and agent-executable.
- Use actionable sections and concrete placeholders.
''';
}

import 'package:path/path.dart' as path;

import '../config/ae_core_config.dart';
import '../models/ae_result.dart';
import '../models/generate.dart';
import '../models/types.dart';
import '../ports/generation_engine.dart';
import 'ae_generation_service.dart';

class DefaultAeGenerationService implements AeGenerationService {
  const DefaultAeGenerationService({
    required GenerationEngine templateEngine,
    final GenerationEngine? codexEngine,
  })  : _templateEngine = templateEngine,
        _codexEngine = codexEngine;

  final GenerationEngine _templateEngine;
  final GenerationEngine? _codexEngine;

  @override
  Future<AeResult<GenerateOutput>> generate(final GenerateInput input) async {
    switch (input.engineMode) {
      case AeGenerationEngineMode.template:
        return _generateWithEngine(_templateEngine, input);
      case AeGenerationEngineMode.codex:
        final codex = _codexEngine;
        if (codex == null || !codex.isAvailable) {
          return AeResult.fail(
            code: 'engine_unavailable',
            message:
                'Codex engine requested but codex binary is not available. Use --engine template or --engine auto.',
            meta: const {'engine': 'codex'},
          );
        }
        return _generateWithEngine(codex, input);
      case AeGenerationEngineMode.auto:
        final codex = _codexEngine;
        if (codex != null && codex.isAvailable) {
          final codexResult = await _generateWithEngine(codex, input);
          if (codexResult.success) {
            return codexResult;
          }

          final fallback = await _generateWithEngine(_templateEngine, input);
          return AeResult<GenerateOutput>(
            success: fallback.success,
            data: fallback.data,
            error: fallback.error,
            warnings: [
              ...codexResult.warnings,
              'Codex generation failed in auto mode; used template fallback.',
              ...fallback.warnings,
            ],
            meta: {...fallback.meta, 'fallback_from': 'codex'},
          );
        }

        final fallback = await _generateWithEngine(_templateEngine, input);
        return AeResult<GenerateOutput>(
          success: fallback.success,
          data: fallback.data,
          error: fallback.error,
          warnings: [
            'Codex binary not detected; used template fallback.',
            ...fallback.warnings,
          ],
          meta: {...fallback.meta, 'fallback_from': 'codex_unavailable'},
        );
    }
  }

  Future<AeResult<GenerateOutput>> _generateWithEngine(
    final GenerationEngine engine,
    final GenerateInput input,
  ) async {
    final result = await engine.generate(input);
    if (!result.success || result.data == null) {
      return AeResult.fail(
        code: result.error?.code ?? 'generation_failed',
        message: result.error?.message ?? 'Generation failed',
        details: result.error?.details,
        warnings: result.warnings,
        meta: {...result.meta, 'engine': engine.id},
      );
    }

    final validation = _validateGeneratedFiles(result.data!);
    if (validation != null) {
      return AeResult.fail(
        code: 'invalid_generation_output',
        message: validation,
        warnings: result.warnings,
        meta: {...result.meta, 'engine': engine.id},
      );
    }

    return AeResult.ok(
      result.data!,
      warnings: result.warnings,
      meta: {...result.meta, 'engine': engine.id},
    );
  }

  String? _validateGeneratedFiles(final GenerateOutput output) {
    final expected = {...AeCoreConfig.requiredRegistryFiles};
    final produced =
        output.files.map((final file) => path.basename(file.path)).toSet();

    if (produced.length != expected.length) {
      return 'Generation output must include exactly ${expected.length} files: ${expected.join(', ')}';
    }

    if (!produced.containsAll(expected)) {
      return 'Generation output missing required files. Expected ${expected.join(', ')}';
    }

    return null;
  }
}

import '../models/ae_result.dart';
import '../models/generate.dart';
import '../ports/generation_engine.dart';

class TemplateGenerationEngine implements GenerationEngine {
  const TemplateGenerationEngine();

  @override
  String get id => 'template';

  @override
  bool get isAvailable => true;

  @override
  Future<AeResult<GenerateOutput>> generate(final GenerateInput input) async {
    final files = <GeneratedFile>[
      GeneratedFile(
        path: 'ae_install.md',
        content: _installTemplate(input.libraryId),
      ),
      GeneratedFile(
        path: 'ae_uninstall.md',
        content: _uninstallTemplate(input.libraryId),
      ),
      GeneratedFile(
        path: 'ae_update.md',
        content: _updateTemplate(input.libraryId),
      ),
      GeneratedFile(path: 'ae_use.md', content: _useTemplate(input.libraryId)),
    ];

    return AeResult.ok(
      GenerateOutput(
        libraryId: input.libraryId,
        engineUsed: id,
        files: files,
        notes: 'Deterministic template fallback generation',
      ),
      warnings: const [
        'Template engine used placeholder markers. Replace all TODO markers before publishing.',
      ],
      meta: const {'engine': 'template', 'fallback': false},
    );
  }

  String _installTemplate(final String libraryId) =>
      '''# AE Install - $libraryId

## Setup
- TODO: Describe prerequisites and environment requirements.
- TODO: Add dependency installation command(s).

## Config
- TODO: Document required configuration keys.
- TODO: Document optional configuration keys with defaults.

## Integration
- TODO: Add integration steps into existing project structure.
- TODO: Document entry points and lifecycle hooks.

## Validation
- TODO: Add verification command(s) and expected output.
- TODO: Add rollback procedure for failed installation.
''';

  String _uninstallTemplate(final String libraryId) =>
      '''# AE Uninstall - $libraryId

## Cleanup
- TODO: Remove dependencies and generated artifacts.
- TODO: Revert project configuration changes.

## Verification
- TODO: Validate removal was successful.
- TODO: Ensure project returns to pre-install behavior.
''';

  String _updateTemplate(final String libraryId) => '''# AE Update - $libraryId

## Migration
- TODO: Document breaking changes and migration sequence.
- TODO: Add backup/rollback checkpoints.

## Validation
- TODO: Validate updated integration path.
- TODO: Add post-update smoke checks.
''';

  String _useTemplate(final String libraryId) => '''# AE Use - $libraryId

## Workflow
- TODO: Describe standard usage workflow.

## Actions
- TODO: List supported operations and examples.

## Guidelines
- TODO: Document best practices.
- TODO: Document anti-patterns and failure handling.
''';
}

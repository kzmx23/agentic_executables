# agentic_executables_core

Shared AE v2 domain package.

## Included

- Typed enums and DTOs (`AeContext`, `AeAction`, `AeResult<T>`, input/output models)
- Service interfaces and default implementations:
  - instructions
  - definition
  - validation (verify + evaluate)
  - registry
  - generation
- Ports/adapters:
  - `DocumentStore`
  - `RegistryClient`
  - `GenerationEngine`
  - `InferenceClient`
  - `SkillTemplateProvider`
  - file-backed document store
  - GitHub raw registry client
  - reusable inference-backed generation adapter (`InferenceGenerationEngine`)
  - deterministic template generation engine

Core generation contract:

- required files: `ae_install.md`, `ae_uninstall.md`, `ae_update.md`, `ae_use.md`
- `DefaultAeGenerationService` validates this contract for all engines
- `auto` mode fallback behavior is implemented in service layer (Codex -> template)
- inference providers can be swapped without changing generation business logic

Inference extension point:

```dart
final engine = InferenceGenerationEngine(client: MyInferenceClient());
```

See root guide: `../docs/inference_provider_guide.md`

## Usage

```dart
final instructions = DefaultAeInstructionService(
  FileDocumentStore('/path/to/prompts_framework'),
);

final result = await instructions.getInstructions(
  const GetInstructionsInput(
    context: AeContext.library,
    action: AeAction.bootstrap,
  ),
);
```

## Testing

```bash
dart test
```

Notable behavior covered in tests:

- context/action document mapping and validation
- registry id/path resolution and submit/get behavior
- verify/evaluate parity checks and scoring
- template generation required-file guarantees
- generation engine selection and fallback logic

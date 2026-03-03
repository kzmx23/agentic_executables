# Inference Provider Guide

AE v2 now has a provider-agnostic inference contract so generation does not require Codex CLI.

## Core Contract

Use these core types:

- `InferenceClient` (`agentic_executables_core/lib/src/ports/inference_client.dart`)
- `InferenceRequest` / `InferenceResponse` (`agentic_executables_core/lib/src/models/inference.dart`)
- `InferenceGenerationEngine` (`agentic_executables_core/lib/src/adapters/inference_generation_engine.dart`)

`InferenceGenerationEngine` converts structured inference output into AE files and enforces the required file contract:

- `ae_install.md`
- `ae_uninstall.md`
- `ae_update.md`
- `ae_use.md`

## Implement Your Own Provider

Any implementation only needs to return JSON matching the schema requested in `InferenceRequest.outputSchema`.

```dart
class MyInferenceClient implements InferenceClient {
  @override
  String get id => 'my-provider';

  @override
  bool get isAvailable => true;

  @override
  Future<AeResult<InferenceResponse>> infer(InferenceRequest request) async {
    // Call your provider here (OpenAI API, local model, hosted gateway, etc.)
    final payload = <String, dynamic>{
      'ae_install.md': '# install',
      'ae_uninstall.md': '# uninstall',
      'ae_update.md': '# update',
      'ae_use.md': '# use',
    };

    return AeResult.ok(InferenceResponse(output: payload));
  }
}
```

Then plug it into generation:

```dart
final engine = InferenceGenerationEngine(client: MyInferenceClient());
final service = DefaultAeGenerationService(
  templateEngine: const TemplateGenerationEngine(),
  codexEngine: engine,
);
```

For CLI embedding, inject your client directly:

```dart
final cli = AeCli(inferenceClient: MyInferenceClient());
```

## Official References

- OpenAI API Overview: <https://platform.openai.com/docs/overview>
- Responses API Reference (create response): <https://platform.openai.com/docs/api-reference/responses/create>
- Structured Outputs Guide: <https://platform.openai.com/docs/guides/structured-outputs>
- Function Calling Guide: <https://platform.openai.com/docs/guides/function-calling>
- Codex CLI docs: <https://developers.openai.com/codex/cli>
- Codex SDK docs: <https://developers.openai.com/codex/sdk/>
- OpenAI Services Agreement: <https://openai.com/policies/services-agreement/>
- OpenAI Usage Policies: <https://openai.com/policies/usage-policies/>

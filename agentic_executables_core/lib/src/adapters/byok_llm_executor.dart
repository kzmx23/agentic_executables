import 'dart:convert';

import '../models/distillation_task.dart';
import '../ports/distillation_executor.dart';
import '../ports/http_invoker.dart';

enum ByokProvider {
  anthropic('anthropic'),
  openai('openai');

  const ByokProvider(this.value);
  final String value;
}

/// Distillation executor that calls a hosted LLM directly with the user's
/// own API key (BYOK = Bring Your Own Key). For headless / CI use or when
/// the user prefers direct dispatch over an in-host subagent.
class ByokLlmExecutor implements DistillationExecutor {
  ByokLlmExecutor({
    required this.httpInvoker,
    required this.provider,
    required this.apiKey,
    this.model = 'claude-sonnet-4-6',
    this.maxTokens = 8000,
    this.runTimeout = const Duration(minutes: 5),
  });

  final HttpInvoker httpInvoker;
  final ByokProvider provider;
  final String apiKey;
  final String model;
  final int maxTokens;
  final Duration runTimeout;

  @override
  String get executorId => 'byok';

  @override
  Future<bool> canRun() async => apiKey.isNotEmpty;

  @override
  Future<DistillationOutput> execute(final DistillationTask task) async {
    final HttpResponseRaw response;
    try {
      response = switch (provider) {
        ByokProvider.anthropic => await _callAnthropic(task),
        ByokProvider.openai => await _callOpenAi(task),
      };
    } on Exception catch (e) {
      throw DistillationFailure('http transport failed', cause: e);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DistillationFailure(
        'BYOK ${provider.value} returned ${response.statusCode}: ${response.body}',
      );
    }
    final assistantText = _extractAssistantText(provider, response.body);
    if (assistantText == null) {
      throw const DistillationFailure(
        'could not extract assistant text from response',
      );
    }
    final json = _extractJsonObject(assistantText);
    if (json == null) {
      throw const DistillationFailure('no JSON object in assistant text');
    }
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map) {
        throw const DistillationFailure('expected JSON object at top level');
      }
      return DistillationOutput.fromMap(decoded);
    } on FormatException catch (e) {
      throw DistillationFailure('invalid JSON from BYOK assistant', cause: e);
    } on ArgumentError catch (e) {
      throw DistillationFailure('schema validation failed', cause: e);
    }
  }

  String _buildPrompt(final DistillationTask task) {
    final taskJson = const JsonEncoder.withIndent('  ').convert(task.toJson());
    return '''
You are running an AE distillation task. Return ONLY a JSON object that matches schema_out (`ae.canonical.draft.v1`). Do not wrap in prose; if you must, place the JSON in a single ```json fenced code block. No commentary outside the JSON.

ID STABILITY RULES (mandatory):
1. Every feature row you emit MUST have an `id` that already appears in the input task's `matrix_seed_rows`. You are enriching existing rows, not inventing new ones.
2. If you encounter a cross-cutting invariant that does not correspond to any seeded id (e.g. "all commands write a JSON envelope"), DO NOT create a feature row for it. Instead, append it to a top-level `proposed_concepts` array on your response, with shape:
   `{ "name": "<short-kebab-name>", "spec": "...", "invariant": "...", "rationale": "why this is cross-cutting, not a symbol" }`
3. If a seeded row is missing in the input but you believe a new symbol exists in the source artifact, DO NOT invent its id. Surface it as `proposed_concepts` with rationale "missing-from-scaffold; rerun ae canonical scaffold --update".

Schema reminder: the response object has top-level keys `schema`, `concept_id`, `concept_version`, `index_md`, `matrix`, optional `patterns_md`, optional `proposed_concepts`.

```json
$taskJson
```
''';
  }

  Future<HttpResponseRaw> _callAnthropic(final DistillationTask task) async {
    final body = jsonEncode({
      'model': model,
      'max_tokens': maxTokens,
      'messages': [
        {
          'role': 'user',
          'content': _buildPrompt(task),
        },
      ],
    });
    return httpInvoker.post(
      uri: Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'content-type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: body,
      timeout: runTimeout,
    );
  }

  Future<HttpResponseRaw> _callOpenAi(final DistillationTask task) async {
    final body = jsonEncode({
      'model': model,
      'messages': [
        {
          'role': 'user',
          'content': _buildPrompt(task),
        },
      ],
    });
    return httpInvoker.post(
      uri: Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'content-type': 'application/json',
        'authorization': 'Bearer $apiKey',
      },
      body: body,
      timeout: runTimeout,
    );
  }

  String? _extractAssistantText(
    final ByokProvider provider,
    final String body,
  ) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      switch (provider) {
        case ByokProvider.anthropic:
          final content = decoded['content'];
          if (content is! List) return null;
          final buffer = StringBuffer();
          for (final block in content) {
            if (block is Map && block['type'] == 'text') {
              buffer.write(block['text']?.toString() ?? '');
            }
          }
          return buffer.isEmpty ? null : buffer.toString();
        case ByokProvider.openai:
          final choices = decoded['choices'];
          if (choices is! List || choices.isEmpty) return null;
          final first = choices.first;
          if (first is! Map) return null;
          final message = first['message'];
          if (message is! Map) return null;
          return message['content']?.toString();
      }
    } on FormatException {
      return null;
    }
  }

  String? _extractJsonObject(final String text) {
    final fenced =
        RegExp(r'```(?:json)?\s*(\{[\s\S]*?\})\s*```').firstMatch(text);
    if (fenced != null) return fenced.group(1);
    var depth = 0;
    var start = -1;
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == '{') {
        if (depth == 0) start = i;
        depth++;
      } else if (ch == '}') {
        depth--;
        if (depth == 0 && start >= 0) return text.substring(start, i + 1);
      }
    }
    return null;
  }
}

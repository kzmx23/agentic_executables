import 'dart:convert';

import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:test/test.dart';

class _FakeInvoker implements HttpInvoker {
  _FakeInvoker(this.response);
  final HttpResponseRaw response;
  final calls = <Map<String, dynamic>>[];

  @override
  Future<HttpResponseRaw> post({
    required final Uri uri,
    required final Map<String, String> headers,
    required final String body,
    final Duration? timeout,
  }) async {
    calls.add({
      'uri': uri.toString(),
      'headers': headers,
      'body': body,
    });
    return response;
  }
}

DistillationTask _sampleTask() => const DistillationTask(
      conceptId: 'ecs',
      conceptVersion: 1,
      sourceArtifact: DistillationSourceArtifact(
        name: 'dart_ecs',
        language: 'dart',
        files: ['lib/src/world.dart'],
        structuralSummary: '',
      ),
    );

String _validOutputJson() => jsonEncode({
      'schema': 'ae.canonical.draft.v1',
      'concept_id': 'ecs',
      'concept_version': 1,
      'index_md': '# ecs',
      'matrix': {
        'schema': 'ae.canonical_matrix.v1',
        'concept': 'ecs',
        'version': 1,
        'column_schema': [
          {'id': 'spec', 'type': 'text'},
        ],
        'features': [
          {'id': 'entity.create', 'spec': 'Make one.'},
        ],
      },
    });

/// Anthropic-shaped success response wrapping the JSON output.
String _anthropicResponse(final String content) => jsonEncode({
      'id': 'msg_01',
      'type': 'message',
      'role': 'assistant',
      'content': [
        {'type': 'text', 'text': content},
      ],
      'model': 'claude-sonnet-4-6',
      'stop_reason': 'end_turn',
    });

void main() {
  group('ByokLlmExecutor', () {
    test('executorId is byok', () {
      final ex = ByokLlmExecutor(
        httpInvoker: _FakeInvoker(
            const HttpResponseRaw(statusCode: 200, body: '')),
        provider: ByokProvider.anthropic,
        apiKey: 'sk-test',
      );
      expect(ex.executorId, 'byok');
    });

    test('canRun true when api key non-empty', () async {
      final ex = ByokLlmExecutor(
        httpInvoker: _FakeInvoker(
            const HttpResponseRaw(statusCode: 200, body: '')),
        provider: ByokProvider.anthropic,
        apiKey: 'sk-test',
      );
      expect(await ex.canRun(), isTrue);
    });

    test('canRun false when api key empty', () async {
      final ex = ByokLlmExecutor(
        httpInvoker: _FakeInvoker(
            const HttpResponseRaw(statusCode: 200, body: '')),
        provider: ByokProvider.anthropic,
        apiKey: '',
      );
      expect(await ex.canRun(), isFalse);
    });

    test('execute (anthropic) posts to messages endpoint with auth header',
        () async {
      final invoker = _FakeInvoker(HttpResponseRaw(
        statusCode: 200,
        body: _anthropicResponse(_validOutputJson()),
      ));
      final ex = ByokLlmExecutor(
        httpInvoker: invoker,
        provider: ByokProvider.anthropic,
        apiKey: 'sk-test',
        model: 'claude-sonnet-4-6',
      );
      final out = await ex.execute(_sampleTask());
      expect(out.conceptId, 'ecs');
      expect(invoker.calls.first['uri'],
          'https://api.anthropic.com/v1/messages');
      final headers = invoker.calls.first['headers'] as Map<String, String>;
      expect(headers['x-api-key'], 'sk-test');
      expect(headers['anthropic-version'], '2023-06-01');
      expect(headers['content-type'], 'application/json');
      // Body is JSON with model + messages
      final body = jsonDecode(invoker.calls.first['body'] as String) as Map;
      expect(body['model'], 'claude-sonnet-4-6');
      expect(body['messages'], isA<List>());
    });

    test('execute throws DistillationFailure on non-2xx', () async {
      final invoker = _FakeInvoker(const HttpResponseRaw(
        statusCode: 401,
        body: '{"error":"invalid api key"}',
      ));
      final ex = ByokLlmExecutor(
        httpInvoker: invoker,
        provider: ByokProvider.anthropic,
        apiKey: 'sk-test',
      );
      expect(
        () => ex.execute(_sampleTask()),
        throwsA(isA<DistillationFailure>()),
      );
    });

    test('execute throws on schema validation failure', () async {
      final invoker = _FakeInvoker(HttpResponseRaw(
        statusCode: 200,
        body: _anthropicResponse(jsonEncode({
          'schema': 'wrong.schema',
          'concept_id': 'ecs',
        })),
      ));
      final ex = ByokLlmExecutor(
        httpInvoker: invoker,
        provider: ByokProvider.anthropic,
        apiKey: 'sk-test',
      );
      expect(
        () => ex.execute(_sampleTask()),
        throwsA(isA<DistillationFailure>()),
      );
    });

    test('execute extracts JSON from fenced output', () async {
      final wrapped = 'Sure:\n```json\n${_validOutputJson()}\n```';
      final invoker = _FakeInvoker(HttpResponseRaw(
        statusCode: 200,
        body: _anthropicResponse(wrapped),
      ));
      final ex = ByokLlmExecutor(
        httpInvoker: invoker,
        provider: ByokProvider.anthropic,
        apiKey: 'sk-test',
      );
      final out = await ex.execute(_sampleTask());
      expect(out.conceptId, 'ecs');
    });
  });
}

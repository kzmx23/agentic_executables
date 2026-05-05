import 'dart:convert';

import '../models/distillation_task.dart';
import '../ports/distillation_executor.dart';
import '../ports/process_runner.dart';
import 'distill_prompt.dart';

/// Distillation executor that dispatches to OpenAI Codex via `codex exec`.
/// Sends the shared distill prompt + task JSON on stdin; expects JSON on
/// stdout. Detects host via `CODEX_HOME` / `OPENAI_CODEX_VERSION`.
class CodexExecExecutor implements DistillationExecutor {
  CodexExecExecutor({
    required this.processRunner,
    required final Map<String, String> environment,
    this.codexExecutable = 'codex',
    this.runTimeout = const Duration(minutes: 5),
  }) : _environment = environment;

  final ProcessRunner processRunner;
  final Map<String, String> _environment;
  final String codexExecutable;
  final Duration runTimeout;

  @override
  String get executorId => 'codex';

  @override
  Future<bool> canRun() async {
    return _environment.containsKey('CODEX_HOME') ||
        _environment.containsKey('OPENAI_CODEX_VERSION');
  }

  @override
  Future<DistillationOutput> execute(final DistillationTask task) async {
    final taskJson = const JsonEncoder.withIndent('  ').convert(task.toJson());
    final stdin = '$distillPromptHeader\n```json\n$taskJson\n```\n';
    final ProcessRunResult result;
    try {
      result = await processRunner.run(
        executable: codexExecutable,
        arguments: const ['exec'],
        stdinInput: stdin,
        environment: _environment,
        timeout: runTimeout,
      );
    } on Exception catch (e) {
      throw DistillationFailure('failed to invoke $codexExecutable', cause: e);
    }
    if (result.exitCode != 0) {
      throw DistillationFailure(
        '$codexExecutable exited ${result.exitCode}: ${result.stderr.trim()}',
      );
    }
    final json = _extractJsonObject(result.stdout);
    if (json == null) {
      throw const DistillationFailure(
        'no JSON object found in codex stdout',
      );
    }
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map) {
        throw const DistillationFailure('expected JSON object at top level');
      }
      return DistillationOutput.fromMap(decoded);
    } on FormatException catch (e) {
      throw DistillationFailure('invalid JSON from codex', cause: e);
    } on ArgumentError catch (e) {
      throw DistillationFailure('schema validation failed', cause: e);
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

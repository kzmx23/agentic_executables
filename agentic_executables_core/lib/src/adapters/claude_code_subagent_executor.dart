import 'dart:convert';

import '../models/distillation_task.dart';
import '../ports/distillation_executor.dart';
import '../ports/process_runner.dart';

/// Distillation executor that dispatches to a Claude Code subagent via
/// `claude -p`. Detects host via `CLAUDECODE` / `CLAUDE_CODE_VERSION`
/// env vars.
class ClaudeCodeSubagentExecutor implements DistillationExecutor {
  ClaudeCodeSubagentExecutor({
    required this.processRunner,
    required final Map<String, String> environment,
    this.claudeExecutable = 'claude',
    this.runTimeout = const Duration(minutes: 5),
  }) : _environment = environment;

  final ProcessRunner processRunner;
  final Map<String, String> _environment;
  final String claudeExecutable;
  final Duration runTimeout;

  @override
  String get executorId => 'claude_code';

  @override
  Future<bool> canRun() async {
    return _environment.containsKey('CLAUDECODE') ||
        _environment.containsKey('CLAUDE_CODE_VERSION');
  }

  @override
  Future<DistillationOutput> execute(final DistillationTask task) async {
    final prompt = _buildPrompt(task);
    final ProcessRunResult result;
    try {
      result = await processRunner.run(
        executable: claudeExecutable,
        arguments: ['-p', prompt],
        environment: _environment,
        timeout: runTimeout,
      );
    } on Exception catch (e) {
      throw DistillationFailure('failed to invoke $claudeExecutable', cause: e);
    }
    if (result.exitCode != 0) {
      throw DistillationFailure(
        '$claudeExecutable exited ${result.exitCode}: ${result.stderr.trim()}',
      );
    }
    final json = _extractJsonObject(result.stdout);
    if (json == null) {
      throw DistillationFailure(
        'no JSON object found in $claudeExecutable stdout',
      );
    }
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map) {
        throw const DistillationFailure('expected JSON object at top level');
      }
      return DistillationOutput.fromMap(decoded);
    } on FormatException catch (e) {
      throw DistillationFailure('invalid JSON from $claudeExecutable',
          cause: e);
    } on ArgumentError catch (e) {
      throw DistillationFailure('schema validation failed', cause: e);
    }
  }

  String _buildPrompt(final DistillationTask task) {
    final taskJson = const JsonEncoder.withIndent('  ').convert(task.toJson());
    return '''
You are running an AE distillation task. The task object follows. Return ONLY a JSON object that matches schema_out (`ae.canonical.draft.v1`). Do not wrap in prose; if you must, place the JSON in a single ```json fenced code block. No commentary outside the JSON.

```json
$taskJson
```
''';
  }

  /// Extract the first balanced top-level JSON object from [text].
  /// Tolerates surrounding prose and fenced code blocks.
  String? _extractJsonObject(final String text) {
    // Try fenced ```json ... ``` first.
    final fenced =
        RegExp(r'```(?:json)?\s*(\{[\s\S]*?\})\s*```').firstMatch(text);
    if (fenced != null) return fenced.group(1);
    // Otherwise scan for the first balanced { ... }.
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

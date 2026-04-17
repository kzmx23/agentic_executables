import '../models/distillation_task.dart';

/// Hands a distillation task to a host (Claude Code subagent, Codex exec,
/// direct LLM) and returns validated output. Implementations must validate
/// against the [DistillationTask.schemaOut] before returning.
abstract interface class DistillationExecutor {
  /// Stable id, e.g. "claude_code" | "codex" | "byok".
  String get executorId;

  /// Whether this executor can run right now (host present + configured).
  /// Cheap; reads env vars / config files only.
  Future<bool> canRun();

  /// Execute [task]. Returns a validated [DistillationOutput] or throws
  /// [DistillationFailure] on transport failure, schema-validation failure,
  /// or non-zero host exit. Callers (DistillationService) handle retry.
  Future<DistillationOutput> execute(final DistillationTask task);
}

/// Thrown by [DistillationExecutor.execute] for any failure.
class DistillationFailure implements Exception {
  const DistillationFailure(this.message, {this.cause});
  final String message;
  final Object? cause;

  @override
  String toString() =>
      cause == null ? 'DistillationFailure: $message'
                    : 'DistillationFailure: $message (cause: $cause)';
}

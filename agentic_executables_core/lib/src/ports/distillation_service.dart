import '../models/distillation_task.dart';

/// Result of a distillation run — bundles the validated output with the
/// id of the executor that produced it. Surfaced in CLI/MCP envelopes so
/// callers can tell which dispatch path ran without re-querying executors.
class DistillationResult {
  const DistillationResult({required this.output, required this.executorId});

  final DistillationOutput output;
  final String executorId;
}

/// Orchestrates distillation: picks an executor by host detection, dispatches
/// the task, validates the wire format, retries once on schema failure.
abstract interface class DistillationService {
  /// Distill the task. Returns a [DistillationResult] (validated output +
  /// id of the executor that produced it), or throws
  /// [DistillationServiceFailure] if no executor can run or all attempts
  /// failed.
  Future<DistillationResult> distill(final DistillationTask task);
}

class DistillationServiceFailure implements Exception {
  const DistillationServiceFailure(this.message);
  final String message;

  @override
  String toString() => 'DistillationServiceFailure: $message';
}

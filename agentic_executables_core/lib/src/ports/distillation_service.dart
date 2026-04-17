import '../models/distillation_task.dart';

/// Orchestrates distillation: picks an executor by host detection, dispatches
/// the task, validates the wire format, retries once on schema failure.
abstract interface class DistillationService {
  /// Distill the task. Returns a validated [DistillationOutput], or throws
  /// [DistillationServiceFailure] if no executor can run or all attempts
  /// failed.
  Future<DistillationOutput> distill(final DistillationTask task);
}

class DistillationServiceFailure implements Exception {
  const DistillationServiceFailure(this.message);
  final String message;

  @override
  String toString() => 'DistillationServiceFailure: $message';
}

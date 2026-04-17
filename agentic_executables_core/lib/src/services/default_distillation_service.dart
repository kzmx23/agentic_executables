import '../models/distillation_task.dart';
import '../ports/distillation_executor.dart';
import '../ports/distillation_service.dart';

/// Default orchestrator. Picks the first runnable executor in [executors]
/// order, dispatches, retries once on failure with extra context, fails
/// clean on second failure.
class DefaultDistillationService implements DistillationService {
  const DefaultDistillationService({required this.executors});

  /// Executors in priority order (first runnable wins).
  final List<DistillationExecutor> executors;

  @override
  Future<DistillationOutput> distill(final DistillationTask task) async {
    DistillationExecutor? chosen;
    for (final ex in executors) {
      if (await ex.canRun()) {
        chosen = ex;
        break;
      }
    }
    if (chosen == null) {
      throw const DistillationServiceFailure(
        'no runnable distillation executor (claude_code / codex / byok)',
      );
    }

    try {
      return await chosen.execute(task);
    } on DistillationFailure catch (firstError) {
      // Retry once with additional context appended to the task examples.
      final retryTask = _withRetryContext(task, firstError);
      try {
        return await chosen.execute(retryTask);
      } on DistillationFailure catch (secondError) {
        throw DistillationServiceFailure(
          'executor ${chosen!.executorId} failed twice: '
          '${firstError.message}; ${secondError.message}',
        );
      }
    }
  }

  DistillationTask _withRetryContext(
    final DistillationTask original,
    final DistillationFailure firstError,
  ) {
    final retryNote = <String, dynamic>{
      'role': 'system',
      'content':
          'The previous attempt failed validation: ${firstError.message}. '
              'Please return JSON that strictly matches schema_out.',
    };
    final examples = List<Map<String, dynamic>>.from(original.examples)
      ..add(retryNote);
    return DistillationTask(
      conceptId: original.conceptId,
      conceptVersion: original.conceptVersion,
      sourceArtifact: original.sourceArtifact,
      matrixSeedRows: original.matrixSeedRows,
      examples: examples,
    );
  }
}

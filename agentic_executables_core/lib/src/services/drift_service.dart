import '../models/drift_report.dart';

abstract interface class DriftService {
  /// Compute code drift entries for [packName] (file SHAs vs meta).
  /// Returns the entries; does NOT persist.
  Future<List<CodeDriftEntry>> computeCodeDrift(final String packName);

  /// Compute intent drift entries for [packName]: canonical invariants whose
  /// artifact rows lack `tests: yes`.
  Future<List<IntentDriftEntry>> computeIntentDrift(final String packName);

  /// Build a full [DriftReport] for [packName], preserving any existing
  /// `accepted:` entries from the artifact's drift.yaml (unmodified in 3.0).
  Future<DriftReport> buildReport(
    final String packName, {
    required final String generatedBy,
  });
}

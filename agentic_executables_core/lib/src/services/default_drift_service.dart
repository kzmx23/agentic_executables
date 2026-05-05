import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../models/artifact_matrix.dart';
import '../models/drift_report.dart';
import '../ports/artifact_store.dart';
import '../ports/canonical_store.dart';
import 'drift_service.dart';

class DefaultDriftService implements DriftService {
  const DefaultDriftService({
    required this.artifactStore,
    required this.canonicalStore,
  });

  final ArtifactStore artifactStore;
  final CanonicalStore canonicalStore;

  @override
  Future<List<CodeDriftEntry>> computeCodeDrift(final String packName) async {
    final pack = await artifactStore.load(packName);
    if (pack == null) {
      throw ArgumentError('Unknown artifact: $packName');
    }
    final basePath = pack.meta.source.path;
    if (basePath == null) return const [];
    final entries = <CodeDriftEntry>[];
    for (final f in pack.meta.source.files) {
      final file = File(p.join(basePath, f.path));
      if (!await file.exists()) {
        entries.add(CodeDriftEntry(
          path: f.path,
          change: CodeDriftChange.removed,
          hashWas: f.sha256,
        ));
        continue;
      }
      final bytes = await file.readAsBytes();
      final hash = sha256.convert(bytes).toString();
      if (hash != f.sha256) {
        entries.add(CodeDriftEntry(
          path: f.path,
          change: CodeDriftChange.modified,
          hashWas: f.sha256,
          hashIs: hash,
        ));
      }
    }
    return entries;
  }

  @override
  Future<List<IntentDriftEntry>> computeIntentDrift(
    final String packName,
  ) async {
    final pack = await artifactStore.load(packName);
    if (pack == null) {
      throw ArgumentError('Unknown artifact: $packName');
    }
    // Index artifact matrix by feature id.
    final byFeatureId = <String, _RowSummary>{
      for (final row in pack.matrix.features)
        row.id.toString(): _RowSummary(
          canonical: row.canonical,
          tests: row.cell.tests,
        ),
    };

    final entries = <IntentDriftEntry>[];
    for (final ref in pack.meta.referencesCanonical) {
      final canonical = await canonicalStore.load(
        ref.conceptId,
        lockedVersion: ref.lockedVersion,
      );
      if (canonical == null) continue;
      for (final feature in canonical.matrix.features) {
        final invariant = feature.cells['invariant'];
        if (invariant == null || invariant.isEmpty) continue;
        final row = byFeatureId[feature.id.toString()];
        final hasYes = row != null &&
            row.canonical == ref.conceptId &&
            row.tests == TestStatus.yes;
        if (!hasYes) {
          entries.add(IntentDriftEntry(
            featureId: feature.id,
            canonical: ref.conceptId,
            invariant: invariant,
            reason: row == null
                ? 'no artifact matrix row for ${feature.id}'
                : 'matrix row has tests=${row.tests?.value ?? "absent"} (need yes)',
          ));
        }
      }
    }
    return entries;
  }

  @override
  Future<DriftReport> buildReport(
    final String packName, {
    required final String generatedBy,
  }) async {
    final code = await computeCodeDrift(packName);
    final intent = await computeIntentDrift(packName);
    return DriftReport(
      generatedBy: generatedBy,
      generatedAt: DateTime.now().toUtc(),
      codeDrift: code,
      intentDrift: intent,
      accepted: const [],
    );
  }
}

class _RowSummary {
  const _RowSummary({required this.canonical, required this.tests});
  final String canonical;
  final TestStatus? tests;
}

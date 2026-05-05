import 'artifact_matrix.dart';
import 'artifact_pack.dart';

/// In-memory result of a [HeuristicExtractor.extract] run.
///
/// Represents a single source-directory's structural parse, ready to be
/// materialized as an [ArtifactPack] (kind = local, empty matrix until
/// canonical references are linked).
class HeuristicArtifact {
  const HeuristicArtifact({
    required this.name,
    required this.languageId,
    required this.meta,
    required this.indexMd,
  });

  /// The artifact pack directory name (slug-safe). Typically the package name.
  final String name;

  /// Language id, e.g. "dart" | "rust" | "kotlin_swift".
  final String languageId;

  /// Ready-to-write artifact metadata (kind=local, source, license, etc.).
  final ArtifactMeta meta;

  /// Generated index.md content (title, README excerpt, public API summary,
  /// dependency list).
  final String indexMd;

  /// Convert to a fully-formed [ArtifactPack] with an empty matrix.
  /// The matrix gains feature rows when canonical references are linked
  /// (Phase 4: `ArtifactService.materialize`).
  ArtifactPack toArtifactPack() => ArtifactPack(
        name: name,
        meta: meta,
        indexContent: indexMd,
        matrix: const ArtifactMatrix(columnSchema: [], features: []),
      );
}

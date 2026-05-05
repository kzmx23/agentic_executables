import 'dart:io';

import '../models/heuristic_artifact.dart';

/// Parses a local source directory into a structural [HeuristicArtifact]
/// without invoking any LLM. Implementations are language-specific.
abstract interface class HeuristicExtractor {
  /// Stable language id, e.g. "dart" | "rust" | "kotlin_swift".
  String get languageId;

  /// Whether this extractor recognizes the source directory's manifest
  /// (e.g. pubspec.yaml for Dart, Cargo.toml for Rust, Package.swift /
  /// build.gradle.kts for Kotlin/Swift). Should be cheap; reads only the
  /// top-level entries of [sourceDir].
  Future<bool> canHandle(final Directory sourceDir);

  /// Extract structural artifact data from [sourceDir]. The returned
  /// [HeuristicArtifact] is suitable for [HeuristicArtifact.toArtifactPack].
  Future<HeuristicArtifact> extract(final Directory sourceDir);
}

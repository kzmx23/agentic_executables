import 'dart:io';

import '../ports/heuristic_extractor.dart';

/// Picks the first registered [HeuristicExtractor] whose `canHandle` returns
/// true for a given directory. Order matters: more-specific extractors should
/// come first when registered.
class HeuristicExtractorRegistry {
  HeuristicExtractorRegistry(this._extractors);

  final List<HeuristicExtractor> _extractors;

  /// Returns the first matching extractor, or null when no extractor handles
  /// [sourceDir].
  Future<HeuristicExtractor?> findFor(final Directory sourceDir) async {
    for (final extractor in _extractors) {
      if (await extractor.canHandle(sourceDir)) return extractor;
    }
    return null;
  }
}

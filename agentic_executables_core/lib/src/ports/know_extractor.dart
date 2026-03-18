import '../models/know.dart';

abstract interface class KnowledgeExtractor {
  /// Whether this extractor can handle the given source.
  bool canHandle(final KnowSource source);

  /// Extract domain knowledge from the source into a KnowPack.
  Future<KnowPack> extract(final String name, final KnowSource source);
}

import 'feature_id.dart';

class ArtifactRequiresEntry {
  const ArtifactRequiresEntry({
    required this.artifact,
    required this.canonical,
    required this.features,
    this.featuresAll = false,
  });

  final String artifact;
  final String canonical;
  final List<FeatureId> features;

  /// True when the entry was declared as `features: ["*"]`,
  /// meaning "all features of this canonical from this artifact."
  final bool featuresAll;

  Map<String, dynamic> toJson() => {
        'artifact': artifact,
        'canonical': canonical,
        'features': featuresAll
            ? const ['*']
            : features.map((final f) => f.toString()).toList(growable: false),
      };

  factory ArtifactRequiresEntry.fromMap(final Map<dynamic, dynamic> map) {
    final featsRaw = map['features'];
    if (featsRaw is List &&
        featsRaw.length == 1 &&
        featsRaw.first.toString() == '*') {
      return ArtifactRequiresEntry(
        artifact: map['artifact']?.toString() ?? '',
        canonical: map['canonical']?.toString() ?? '',
        features: const [],
        featuresAll: true,
      );
    }
    final feats = featsRaw is List
        ? featsRaw
            .map((final v) => FeatureId.parse(v.toString()))
            .toList(growable: false)
        : <FeatureId>[];
    return ArtifactRequiresEntry(
      artifact: map['artifact']?.toString() ?? '',
      canonical: map['canonical']?.toString() ?? '',
      features: feats,
    );
  }
}

class RequiresSpec {
  const RequiresSpec({required this.entries});

  final List<ArtifactRequiresEntry> entries;

  List<dynamic> toJson() =>
      entries.map((final e) => e.toJson()).toList(growable: false);

  factory RequiresSpec.fromList(final List<dynamic> list) => RequiresSpec(
        entries: list
            .whereType<Map>()
            .map(ArtifactRequiresEntry.fromMap)
            .toList(growable: false),
      );
}

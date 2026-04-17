import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:test/test.dart';

void main() {
  group('ArtifactRequiresEntry', () {
    test('toJson + fromMap round-trip with explicit features', () {
      final e = ArtifactRequiresEntry(
        artifact: 'dart_ecs',
        canonical: 'ecs',
        features: [
          FeatureId.parse('entity.create'),
          FeatureId.parse('system.tick'),
        ],
      );
      final j = e.toJson();
      expect(j['artifact'], 'dart_ecs');
      expect(j['canonical'], 'ecs');
      expect((j['features'] as List).length, 2);
      final back = ArtifactRequiresEntry.fromMap(j);
      expect(back.artifact, 'dart_ecs');
      expect(back.features.length, 2);
      expect(back.features.first.toString(), 'entity.create');
      expect(back.featuresAll, isFalse);
    });

    test('features: ["*"] means all', () {
      final entry = ArtifactRequiresEntry.fromMap({
        'artifact': 'dart_ecs_render',
        'canonical': 'ecsly/render_pipeline',
        'features': ['*'],
      });
      expect(entry.featuresAll, isTrue);
      expect(entry.features, isEmpty);
    });
  });

  group('RequiresSpec', () {
    test('list serialization', () {
      final spec = RequiresSpec(entries: [
        ArtifactRequiresEntry(
          artifact: 'dart_ecs',
          canonical: 'ecs',
          features: [FeatureId.parse('entity.create')],
        ),
      ]);
      final j = spec.toJson();
      expect(j, isA<List>());
      expect((j as List).length, 1);
    });
  });
}

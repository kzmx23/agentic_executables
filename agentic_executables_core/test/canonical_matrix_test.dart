import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('CanonicalMatrix', () {
    test('builds and serializes to JSON', () {
      final m = CanonicalMatrix(
        concept: 'ecs',
        version: 1,
        columnSchema: const [
          CanonicalColumn(id: 'spec', type: 'text'),
          CanonicalColumn(id: 'invariant', type: 'text'),
        ],
        features: [
          CanonicalFeature(
            id: FeatureId.parse('entity.create'),
            cells: const {
              'spec': 'An entity is created with a unique opaque handle.',
              'invariant': 'Handles are non-reusable within a session.',
            },
          ),
        ],
      );

      final j = m.toJson();
      expect(j['schema'], 'ae.canonical_matrix.v1');
      expect(j['concept'], 'ecs');
      expect(j['version'], 1);
      expect((j['column_schema'] as List).length, 2);
      expect((j['features'] as List).length, 1);
      expect(((j['features'] as List).first as Map)['id'], 'entity.create');
    });

    test('toYamlString round-trips through fromMap', () {
      final m = CanonicalMatrix(
        concept: 'ecs',
        version: 1,
        columnSchema: const [
          CanonicalColumn(id: 'spec', type: 'text'),
        ],
        features: [
          CanonicalFeature(
            id: FeatureId.parse('system.tick'),
            cells: const {'spec': 'Systems run in declared order each tick.'},
          ),
        ],
      );
      final yamlStr = m.toYamlString();
      final loaded = loadYaml(yamlStr);
      expect(loaded, isA<Map>());
      final parsed = CanonicalMatrix.fromMap(loaded as Map);
      expect(parsed.concept, 'ecs');
      expect(parsed.features.first.id.toString(), 'system.tick');
      expect(parsed.features.first.cells['spec'], contains('declared order'));
    });

    test('fromMap rejects wrong schema', () {
      expect(
        () => CanonicalMatrix.fromMap({
          'schema': 'wrong.schema.v9',
          'concept': 'x',
          'version': 1,
          'features': const [],
        }),
        throwsArgumentError,
      );
    });
  });

  group('CanonicalFeature.fromMap', () {
    test('parses the literal distill_prompt example (flat cells)', () {
      // Pins the LLM-prompt response shape to the parser.
      // Generalizes the round-trip-from-LLM convention from phase-b-smoke/SUMMARY.md.
      final exampleResponseRow = {
        'id': 'demo.example',
        'spec': 'example spec',
        'invariant': 'example invariant',
      };
      final feature = CanonicalFeature.fromMap(exampleResponseRow);
      expect(feature.cells['spec'], 'example spec');
      expect(feature.cells['invariant'], 'example invariant');
      expect(feature.cells.containsKey('cells'), isFalse);
    });

    test('still parses nested-cells shape (back-compat from 7f68969)', () {
      final nestedRow = {
        'id': 'demo.example',
        'cells': {'spec': 'nested spec', 'invariant': 'nested invariant'},
      };
      final feature = CanonicalFeature.fromMap(nestedRow);
      expect(feature.cells['spec'], 'nested spec');
      expect(feature.cells['invariant'], 'nested invariant');
    });
  });
}

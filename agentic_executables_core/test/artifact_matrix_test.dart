import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('ImplStatus', () {
    test('all values', () {
      expect(ImplStatus.fromString('done'), ImplStatus.done);
      expect(ImplStatus.fromString('partial'), ImplStatus.partial);
      expect(ImplStatus.fromString('missing'), ImplStatus.missing);
      expect(ImplStatus.fromString('planned'), ImplStatus.planned);
      expect(ImplStatus.fromString('n_a'), ImplStatus.nA);
      expect(ImplStatus.fromString('deviates'), ImplStatus.deviates);
    });
    test('rejects invalid', () {
      expect(() => ImplStatus.fromString('foo'), throwsArgumentError);
    });
  });

  group('ArtifactCell', () {
    test('serializes only set fields', () {
      const cell = ArtifactCell(
        impl: ImplStatus.done,
        location: 'lib/x.dart:42',
        tests: TestStatus.yes,
      );
      final j = cell.toJson();
      expect(j['impl'], 'done');
      expect(j['location'], 'lib/x.dart:42');
      expect(j['tests'], 'yes');
      expect(j.containsKey('algorithm'), isFalse);
    });
  });

  group('ArtifactMatrix', () {
    test('serializes feature rows and round-trips', () {
      final matrix = ArtifactMatrix(
        columnSchema: const [
          ArtifactColumn(
            id: 'impl',
            type: 'enum',
            values: ['done', 'partial', 'missing'],
          ),
          ArtifactColumn(id: 'location', type: 'path'),
        ],
        features: [
          ArtifactFeatureRow(
            id: FeatureId.parse('entity.create'),
            canonical: 'ecs',
            cell: const ArtifactCell(
              impl: ImplStatus.done,
              location: 'lib/entities.dart:42',
            ),
          ),
        ],
      );
      final yamlStr = matrix.toYamlString();
      final loaded = loadYaml(yamlStr) as Map;
      final back = ArtifactMatrix.fromMap(loaded);
      expect(back.features.first.id.toString(), 'entity.create');
      expect(back.features.first.canonical, 'ecs');
      expect(back.features.first.cell.impl, ImplStatus.done);
    });

    test('fromMap rejects wrong schema', () {
      expect(
        () => ArtifactMatrix.fromMap({
          'schema': 'wrong',
          'column_schema': const [],
          'features': const [],
        }),
        throwsArgumentError,
      );
    });
  });
}

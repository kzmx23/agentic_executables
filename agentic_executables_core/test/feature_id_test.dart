import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:test/test.dart';

void main() {
  group('FeatureId', () {
    test('valid simple id', () {
      final id = FeatureId.parse('entity.create');
      expect(id.toString(), 'entity.create');
      expect(id.namespace, 'entity');
      expect(id.name, 'create');
    });

    test('valid nested namespace', () {
      final id = FeatureId.parse('lights.spot.cone');
      expect(id.namespace, 'lights.spot');
      expect(id.name, 'cone');
    });

    test('valid with underscores in segment', () {
      final id = FeatureId.parse('swarm.flocking_movement');
      expect(id.namespace, 'swarm');
      expect(id.name, 'flocking_movement');
    });

    test('rejects empty', () {
      expect(() => FeatureId.parse(''), throwsArgumentError);
    });

    test('rejects no dot', () {
      expect(() => FeatureId.parse('just_a_name'), throwsArgumentError);
    });

    test('rejects uppercase', () {
      expect(() => FeatureId.parse('Entity.Create'), throwsArgumentError);
    });

    test('rejects hyphens', () {
      expect(() => FeatureId.parse('entity-create.id'), throwsArgumentError);
    });

    test('equality and hashCode', () {
      final a = FeatureId.parse('entity.create');
      final b = FeatureId.parse('entity.create');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}

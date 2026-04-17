import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('CodeDriftEntry', () {
    test('serializes change types', () {
      const a = CodeDriftEntry(
        path: 'lib/x.dart',
        change: CodeDriftChange.modified,
        hashWas: 'abc',
        hashIs: 'def',
      );
      expect(a.toJson()['change'], 'modified');

      const b = CodeDriftEntry(path: 'lib/y.dart', change: CodeDriftChange.added);
      expect(b.toJson()['change'], 'added');

      const c = CodeDriftEntry(path: 'lib/z.dart', change: CodeDriftChange.removed);
      expect(c.toJson()['change'], 'removed');
    });
  });

  group('IntentDriftEntry', () {
    test('serializes feature + reason', () {
      final e = IntentDriftEntry(
        featureId: FeatureId.parse('system.tick'),
        canonical: 'ecs',
        invariant: 'monotonic',
        reason: 'no test asserts this',
      );
      final j = e.toJson();
      expect(j['feature_id'], 'system.tick');
      expect(j['canonical'], 'ecs');
      expect(j['invariant'], 'monotonic');
    });
  });

  group('AcceptedDrift', () {
    test('serializes feature + note', () {
      final a = AcceptedDrift(
        featureId: FeatureId.parse('mesh.primitive'),
        note: 'tangents per-pixel deliberately',
      );
      expect(a.toJson()['feature_id'], 'mesh.primitive');
    });
  });

  group('DriftReport', () {
    test('toYamlString round-trips', () {
      final r = DriftReport(
        generatedBy: 'ae sync',
        generatedAt: DateTime.utc(2026, 4, 17, 14),
        codeDrift: const [
          CodeDriftEntry(
            path: 'lib/x.dart',
            change: CodeDriftChange.modified,
            hashWas: 'a',
            hashIs: 'b',
          ),
          CodeDriftEntry(path: 'lib/new.dart', change: CodeDriftChange.added),
        ],
        intentDrift: [
          IntentDriftEntry(
            featureId: FeatureId.parse('system.tick'),
            canonical: 'ecs',
            invariant: 'monotonic',
            reason: 'no test',
          ),
        ],
        accepted: [
          AcceptedDrift(
            featureId: FeatureId.parse('mesh.primitive'),
            note: 'on purpose',
          ),
        ],
      );
      final yamlStr = r.toYamlString();
      final loaded = loadYaml(yamlStr) as Map;
      final back = DriftReport.fromMap(loaded);
      expect(back.generatedBy, 'ae sync');
      expect(back.codeDrift.length, 2);
      expect(back.intentDrift.first.featureId.toString(), 'system.tick');
      expect(back.accepted.first.note, 'on purpose');
    });
  });
}

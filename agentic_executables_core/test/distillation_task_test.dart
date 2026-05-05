import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:test/test.dart';

void main() {
  group('DistillationTask', () {
    test('schema_in is fixed', () {
      expect(DistillationTask.schemaIn, 'ae.distillation.task.v1');
      expect(DistillationTask.schemaOut, 'ae.canonical.draft.v1');
    });

    test('toJson + fromMap round-trip', () {
      const task = DistillationTask(
        conceptId: 'ecsly/render_pipeline',
        conceptVersion: 1,
        sourceArtifact: DistillationSourceArtifact(
          name: 'dart_ecs_render3d_core',
          language: 'dart',
          files: ['lib/src/passes/basic.dart', 'lib/src/scene.dart'],
          structuralSummary: '# Render core\n\nExports: BasicPass, Scene',
        ),
        matrixSeedRows: [],
        examples: [],
      );
      final j = task.toJson();
      expect(j['task'], 'distill_pack');
      expect(j['schema_in'], 'ae.distillation.task.v1');
      expect(j['schema_out'], 'ae.canonical.draft.v1');
      expect(j['concept_id'], 'ecsly/render_pipeline');
      expect((j['source_artifact'] as Map)['name'], 'dart_ecs_render3d_core');

      final back = DistillationTask.fromMap(j);
      expect(back.conceptId, 'ecsly/render_pipeline');
      expect(back.sourceArtifact.files.length, 2);
    });
  });

  group('DistillationOutput', () {
    test('round-trips with feature rows', () {
      final out = DistillationOutput(
        conceptId: 'ecsly/render_pipeline',
        conceptVersion: 1,
        indexMd: '# Render pipeline\n\nDistilled.',
        matrix: CanonicalMatrix(
          concept: 'ecsly/render_pipeline',
          version: 1,
          columnSchema: const [
            CanonicalColumn(id: 'spec', type: 'text'),
            CanonicalColumn(id: 'invariant', type: 'text'),
          ],
          features: [
            CanonicalFeature(
              id: FeatureId.parse('render.scene_extract'),
              cells: const {
                'spec': 'Extract render-relevant entities into a render queue.',
                'invariant': 'Queue is rebuilt each frame; no stale entries.',
              },
            ),
          ],
        ),
        patternsMd: 'Use double-buffering.',
      );
      final j = out.toJson();
      expect(j['schema'], 'ae.canonical.draft.v1');

      final back = DistillationOutput.fromMap(j);
      expect(back.conceptId, 'ecsly/render_pipeline');
      expect(back.matrix.features.first.id.toString(), 'render.scene_extract');
      expect(back.patternsMd, 'Use double-buffering.');
    });

    test('fromMap rejects wrong schema', () {
      expect(
        () => DistillationOutput.fromMap({
          'schema': 'wrong',
          'concept_id': 'x',
          'concept_version': 1,
          'index_md': '',
          'matrix': const {},
        }),
        throwsArgumentError,
      );
    });
  });
}

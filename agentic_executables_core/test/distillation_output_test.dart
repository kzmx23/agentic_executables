import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:test/test.dart';

void main() {
  group('DistillationOutput.proposedConcepts', () {
    test('defaults to empty list when not provided', () {
      final out = DistillationOutput(
        conceptId: 'x',
        conceptVersion: 1,
        indexMd: '',
        matrix: CanonicalMatrix(
          concept: 'x',
          version: 1,
          columnSchema: const [],
          features: const [],
        ),
      );
      expect(out.proposedConcepts, isEmpty);
    });

    test('round-trips through toJson / fromMap when populated', () {
      final out = DistillationOutput(
        conceptId: 'x',
        conceptVersion: 1,
        indexMd: '',
        matrix: CanonicalMatrix(
          concept: 'x',
          version: 1,
          columnSchema: const [],
          features: const [],
        ),
        proposedConcepts: const [
          ProposedConcept(
            name: 'json-envelope',
            spec: 'every command writes JSON',
            invariant: 'success is bool',
            rationale: 'cross-cutting, no symbol',
          ),
        ],
      );
      final json = out.toJson();
      expect(json['proposed_concepts'], isA<List<dynamic>>());
      expect((json['proposed_concepts'] as List).single['name'], 'json-envelope');

      final round = DistillationOutput.fromMap(json);
      expect(round.proposedConcepts, hasLength(1));
      expect(round.proposedConcepts.single.name, 'json-envelope');
      expect(round.proposedConcepts.single.rationale, 'cross-cutting, no symbol');
    });

    test('fromMap accepts payloads without proposed_concepts (back-compat)', () {
      final json = {
        'schema': 'ae.canonical.draft.v1',
        'concept_id': 'x',
        'concept_version': 1,
        'index_md': '',
        'matrix': {
          'schema': 'ae.canonical_matrix.v1',
          'concept': 'x',
          'version': 1,
          'column_schema': [],
          'features': [],
        },
      };
      final out = DistillationOutput.fromMap(json);
      expect(out.proposedConcepts, isEmpty);
    });
  });
}

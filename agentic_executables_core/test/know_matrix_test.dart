import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:test/test.dart';

void main() {
  group('KnowFeatureMatrix', () {
    test('round-trip YAML and diff', () {
      final a = KnowFeatureMatrix(
        version: 1,
        schema: KnowFeatureMatrix.defaultSchema,
        title: 'Test',
        statusDate: '2026-03-25',
        columns: const [
          KnowMatrixColumn(id: 'import', label: 'Import'),
          KnowMatrixColumn(id: 'proof', label: 'Proof'),
        ],
        columnLegend: const {'import': 'Parsed'},
        features: [
          KnowMatrixFeature(
            id: 'buffers',
            label: 'Buffers',
            cells: {'import': 'yes', 'proof': 'yes'},
          ),
        ],
      );
      final yaml = a.toYamlString();
      final b = KnowFeatureMatrix.parseYamlString(yaml);
      expect(b.features.length, 1);
      expect(b.features.first.id, 'buffers');

      final a2 = KnowFeatureMatrix(
        version: 1,
        schema: KnowFeatureMatrix.defaultSchema,
        title: 'Test',
        columns: const [
          KnowMatrixColumn(id: 'import', label: 'Import'),
          KnowMatrixColumn(id: 'proof', label: 'Proof'),
        ],
        features: [
          KnowMatrixFeature(
            id: 'buffers',
            label: 'Buffers',
            cells: {'import': 'yes', 'proof': 'no'},
          ),
        ],
      );
      final diff = diffKnowMatrices(a, a2);
      expect(diff.changedCells.length, 1);
      expect(diff.changedCells.first.columnId, 'proof');
    });

    test('renderMarkdown contains table header', () {
      final m = KnowFeatureMatrix(
        version: 1,
        schema: KnowFeatureMatrix.defaultSchema,
        title: 'M',
        columns: const [
          KnowMatrixColumn(id: 'a', label: 'A'),
        ],
        features: const [],
      );
      final md = m.renderMarkdown();
      expect(md.contains('## Coverage'), isTrue);
      expect(md.contains('| Feature |'), isTrue);
    });
  });
}

import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:test/test.dart';

void main() {
  test('template engine emits required AE files and sections', () async {
    const engine = TemplateGenerationEngine();

    final result = await engine.generate(
      const GenerateInput(
        libraryId: 'dart_provider',
        libraryRoot: '/tmp/repo',
        outputDir: '/tmp/repo/ae_use',
      ),
    );

    expect(result.success, isTrue);
    final output = result.data!;
    final names = output.files.map((final file) => file.path).toSet();

    expect(
      names,
      equals({'ae_install.md', 'ae_uninstall.md', 'ae_update.md', 'ae_use.md'}),
    );

    final install = output.files.firstWhere(
      (final file) => file.path == 'ae_install.md',
    );
    expect(install.content, contains('## Setup'));
    expect(install.content, contains('## Validation'));
  });
}

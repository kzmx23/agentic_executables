import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:test/test.dart';

void main() {
  group('KnowFormat', () {
    test('pdf is first-class format', () {
      expect(KnowFormat.fromString('pdf'), KnowFormat.pdf);
      expect(KnowFormat.pdf.value, 'pdf');
    });

    test('fromString accepts all known formats', () {
      expect(KnowFormat.fromString('llms_txt'), KnowFormat.llmsTxt);
      expect(KnowFormat.fromString('html'), KnowFormat.html);
      expect(KnowFormat.fromString('markdown'), KnowFormat.markdown);
      expect(KnowFormat.fromString('pdf'), KnowFormat.pdf);
      expect(KnowFormat.fromString('repo'), KnowFormat.repo);
    });

    test('fromString throws for unknown format', () {
      expect(
        () => KnowFormat.fromString('unknown'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}

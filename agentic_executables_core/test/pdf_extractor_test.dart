import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:test/test.dart';

void main() {
  group('PdfExtractor', () {
    late PdfExtractor extractor;

    setUp(() {
      extractor = PdfExtractor();
    });

    test('canHandle URL with format pdf', () {
      final source = KnowSource(
        type: KnowSourceType.url,
        url: 'https://example.com/any',
        format: KnowFormat.pdf,
      );
      expect(extractor.canHandle(source), isTrue);
    });

    test('canHandle URL with format null and url ending .pdf', () {
      final source = KnowSource(
        type: KnowSourceType.url,
        url: 'https://arxiv.org/pdf/2312.11514',
        format: null,
      );
      expect(extractor.canHandle(source), isTrue);
    });

    test('canHandle URL with format null and path containing /pdf/', () {
      final source = KnowSource(
        type: KnowSourceType.url,
        url: 'https://example.com/pdf/123',
        format: null,
      );
      expect(extractor.canHandle(source), isTrue);
    });

    test('canHandle returns false for HTML format', () {
      final source = KnowSource(
        type: KnowSourceType.url,
        url: 'https://example.com/page.pdf',
        format: KnowFormat.html,
      );
      expect(extractor.canHandle(source), isFalse);
    });

    test('canHandle returns false for non-PDF URL when format null', () {
      final source = KnowSource(
        type: KnowSourceType.url,
        url: 'https://example.com/spec.html',
        format: null,
      );
      expect(extractor.canHandle(source), isFalse);
    });

    test('canHandle returns false for repo source', () {
      final source = KnowSource(
        type: KnowSourceType.repo,
        url: 'https://github.com/foo/bar',
      );
      expect(extractor.canHandle(source), isFalse);
    });

    test('canHandle returns false when url is null', () {
      final source = KnowSource(
        type: KnowSourceType.url,
        url: null,
        format: KnowFormat.pdf,
      );
      expect(extractor.canHandle(source), isFalse);
    });
  });
}

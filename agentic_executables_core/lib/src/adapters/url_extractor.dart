import 'dart:convert';
import 'dart:io';

import '../models/know.dart';
import '../ports/know_extractor.dart';

class UrlExtractor implements KnowledgeExtractor {
  UrlExtractor({final HttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

  @override
  bool canHandle(final KnowSource source) =>
      source.type == KnowSourceType.url &&
      source.format == KnowFormat.html;

  @override
  Future<KnowPack> extract(final String name, final KnowSource source) async {
    final url = source.url!;
    final readerUrl = 'https://r.jina.ai/$url';

    final uri = Uri.parse(readerUrl);
    final request = await _httpClient.getUrl(uri);
    request.headers.set('Accept', 'text/markdown');
    final response = await request.close();

    if (response.statusCode != 200) {
      throw HttpException(
        'Jina Reader failed for $url: HTTP ${response.statusCode}',
        uri: uri,
      );
    }

    final content = await response.transform(utf8.decoder).join();
    final fingerprint = _computeFingerprint(content);
    final tokenEstimate = content.length ~/ 4;

    final meta = KnowMeta(
      name: name,
      source: KnowSource(
        type: KnowSourceType.url,
        url: source.url,
        format: KnowFormat.html,
      ),
      distillEngine: KnowDistillEngine.passthrough,
      tokenEstimate: tokenEstimate,
      fetchedAt: DateTime.now(),
      sha256: fingerprint,
    );

    return KnowPack(meta: meta, indexContent: content);
  }

  String _computeFingerprint(final String content) {
    final bytes = utf8.encode(content);
    var sum = 0;
    for (final b in bytes) {
      sum = (sum + b) & 0xFFFFFFFF;
    }
    return sum.toRadixString(16).padLeft(8, '0');
  }
}

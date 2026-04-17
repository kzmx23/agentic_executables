import 'dart:convert';
import 'dart:io';

import '../models/know_source.dart';

class PdfExtractor {
  PdfExtractor({final HttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

  static bool _urlLooksPdf(final String? url) {
    if (url == null || url.isEmpty) return false;
    final lower = url.toLowerCase();
    return lower.endsWith('.pdf') || lower.contains('/pdf/');
  }

  bool canHandle(final KnowSource source) {
    if (source.type != KnowSourceType.url || source.url == null) return false;
    if (source.format == KnowFormat.pdf) return true;
    if (source.format == null && _urlLooksPdf(source.url)) return true;
    return false;
  }

  Future<KnowPack> extract(final String name, final KnowSource source) async {
    final url = source.url!;
    final readerUrl = 'https://r.jina.ai/$url';

    final uri = Uri.parse(readerUrl);
    final request = await _httpClient.getUrl(uri);
    request.headers.set('Accept', 'text/markdown');
    final response = await request.close();

    if (response.statusCode != 200) {
      throw HttpException(
        'Jina Reader failed for PDF $url: HTTP ${response.statusCode}',
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
        format: KnowFormat.pdf,
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

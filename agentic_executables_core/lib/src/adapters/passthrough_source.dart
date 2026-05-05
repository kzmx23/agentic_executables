import 'dart:convert';
import 'dart:io';

import '../models/know_source.dart';

class PassthroughExtractor {
  PassthroughExtractor({final HttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

  bool canHandle(final KnowSource source) =>
      source.type == KnowSourceType.url || source.type == KnowSourceType.local;

  Future<KnowPack> extract(final String name, final KnowSource source) async {
    final content = switch (source.type) {
      KnowSourceType.url => await _fetchUrl(source.url!),
      KnowSourceType.local => await File(source.path!).readAsString(),
      _ => throw ArgumentError('Unsupported source type: ${source.type}'),
    };

    final format = _detectFormat(source);
    final fingerprint = _computeFingerprint(content);
    final tokenEstimate = content.length ~/ 4;

    final meta = KnowMeta(
      name: name,
      source: KnowSource(
          type: source.type,
          url: source.url,
          path: source.path,
          format: format),
      distillEngine: KnowDistillEngine.passthrough,
      tokenEstimate: tokenEstimate,
      fetchedAt: DateTime.now(),
      sha256: fingerprint,
    );

    return KnowPack(meta: meta, indexContent: content);
  }

  KnowFormat _detectFormat(final KnowSource source) {
    final ref = source.url ?? source.path ?? '';
    if (ref.endsWith('.txt') || ref.contains('llms')) return KnowFormat.llmsTxt;
    return KnowFormat.markdown;
  }

  String _computeFingerprint(final String content) {
    final bytes = utf8.encode(content);
    var sum = 0;
    for (final b in bytes) {
      sum = (sum + b) & 0xFFFFFFFF;
    }
    return sum.toRadixString(16).padLeft(8, '0');
  }

  Future<String> _fetchUrl(final String url) async {
    final uri = Uri.parse(url);
    if (uri.scheme == 'file') {
      return File.fromUri(uri).readAsString();
    }
    final request = await _httpClient.getUrl(uri);
    final response = await request.close();

    if (response.statusCode != 200) {
      throw HttpException(
        'Failed to fetch $url: HTTP ${response.statusCode}',
        uri: uri,
      );
    }

    return response.transform(utf8.decoder).join();
  }
}

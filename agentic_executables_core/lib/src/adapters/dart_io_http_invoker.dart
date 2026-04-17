import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../ports/http_invoker.dart';

class DartIoHttpInvoker implements HttpInvoker {
  DartIoHttpInvoker({final HttpClient? client})
      : _client = client ?? HttpClient();

  final HttpClient _client;

  @override
  Future<HttpResponseRaw> post({
    required final Uri uri,
    required final Map<String, String> headers,
    required final String body,
    final Duration? timeout,
  }) async {
    final request = await _client.postUrl(uri);
    headers.forEach(request.headers.set);
    request.add(utf8.encode(body));
    final responseFuture = request.close();
    final response = timeout == null
        ? await responseFuture
        : await responseFuture.timeout(timeout);
    final bodyString = await response.transform(utf8.decoder).join();
    final headersOut = <String, String>{};
    response.headers.forEach((final name, final values) {
      headersOut[name] = values.join(', ');
    });
    return HttpResponseRaw(
      statusCode: response.statusCode,
      body: bodyString,
      headers: headersOut,
    );
  }
}

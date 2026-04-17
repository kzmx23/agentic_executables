class HttpResponseRaw {
  const HttpResponseRaw({
    required this.statusCode,
    required this.body,
    this.headers = const {},
  });

  final int statusCode;
  final String body;
  final Map<String, String> headers;
}

/// Minimal HTTP abstraction. Production uses [DartIoHttpInvoker]; tests
/// inject a fake.
abstract interface class HttpInvoker {
  /// POST [body] to [uri] with the given [headers]. Returns the raw response.
  /// Throws on transport failures (DNS, connection refused, timeout).
  Future<HttpResponseRaw> post({
    required final Uri uri,
    required final Map<String, String> headers,
    required final String body,
    final Duration? timeout,
  });
}

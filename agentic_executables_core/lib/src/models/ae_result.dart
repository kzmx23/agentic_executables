import 'ae_error.dart';

class AeResult<T> {
  const AeResult({
    required this.success,
    this.data,
    this.error,
    this.warnings = const [],
    this.meta = const {},
  });

  factory AeResult.ok(
    final T data, {
    final List<String> warnings = const [],
    final Map<String, dynamic> meta = const {},
  }) =>
      AeResult<T>(success: true, data: data, warnings: warnings, meta: meta);

  factory AeResult.fail({
    required final String code,
    required final String message,
    final Object? details,
    final List<String> warnings = const [],
    final Map<String, dynamic> meta = const {},
  }) =>
      AeResult<T>(
        success: false,
        error: AeError(code: code, message: message, details: details),
        warnings: warnings,
        meta: meta,
      );

  final bool success;
  final T? data;
  final AeError? error;
  final List<String> warnings;
  final Map<String, dynamic> meta;

  Map<String, dynamic> toJson(final Object? Function(T value) toData) => {
        'success': success,
        'data': data == null ? null : toData(data as T),
        if (error != null) 'error': error!.toJson(),
        'warnings': warnings,
        'meta': meta,
      };
}

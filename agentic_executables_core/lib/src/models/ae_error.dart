class AeError {
  const AeError({required this.code, required this.message, this.details});

  final String code;
  final String message;
  final Object? details;

  Map<String, dynamic> toJson() => {
        'code': code,
        'message': message,
        if (details != null) 'details': details,
      };
}

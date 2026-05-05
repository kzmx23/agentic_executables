class InferenceRequest {
  const InferenceRequest({
    required this.prompt,
    required this.outputSchema,
    required this.workingDirectory,
    this.metadata = const {},
  });

  final String prompt;
  final Map<String, dynamic> outputSchema;
  final String workingDirectory;
  final Map<String, dynamic> metadata;
}

class InferenceResponse {
  const InferenceResponse({
    required this.output,
    this.rawOutput,
    this.warnings = const [],
    this.meta = const {},
  });

  final Map<String, dynamic> output;
  final String? rawOutput;
  final List<String> warnings;
  final Map<String, dynamic> meta;
}

import 'types.dart';

class GetInstructionsInput {
  const GetInstructionsInput({
    required this.context,
    required this.action,
    this.knowContext,
  });

  final AeContext context;
  final AeAction action;
  final String? knowContext;
}

class GetInstructionsOutput {
  const GetInstructionsOutput({
    required this.context,
    required this.action,
    required this.documents,
    this.message = 'Instructions retrieved successfully',
  });

  final AeContext context;
  final AeAction action;
  final Map<String, String> documents;
  final String message;

  Map<String, dynamic> toJson() => {
        'context_type': context.value,
        'action': action.value,
        'documents': documents,
        'message': message,
      };
}

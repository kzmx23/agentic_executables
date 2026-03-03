import '../models/ae_result.dart';
import '../models/get_instructions.dart';
import '../models/types.dart';
import '../ports/document_store.dart';
import 'ae_instruction_service.dart';

class DefaultAeInstructionService implements AeInstructionService {
  const DefaultAeInstructionService(this._documentStore);

  final DocumentStore _documentStore;

  @override
  Future<AeResult<GetInstructionsOutput>> getInstructions(
    final GetInstructionsInput input,
  ) async {
    try {
      final contextAction = AeContextAction(input.context, input.action);
      final files = contextAction.getDocumentFiles();
      final docs = await _documentStore.getDocuments(files);

      return AeResult.ok(
        GetInstructionsOutput(
          context: input.context,
          action: input.action,
          documents: docs,
        ),
        meta: {'documents_loaded': files.length},
      );
    } catch (error) {
      return AeResult.fail(
        code: 'instructions_failed',
        message: 'Failed to load AE instructions',
        details: error.toString(),
      );
    }
  }
}

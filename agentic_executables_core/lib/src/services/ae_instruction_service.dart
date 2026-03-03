import '../models/ae_result.dart';
import '../models/get_instructions.dart';

abstract interface class AeInstructionService {
  Future<AeResult<GetInstructionsOutput>> getInstructions(
    GetInstructionsInput input,
  );
}

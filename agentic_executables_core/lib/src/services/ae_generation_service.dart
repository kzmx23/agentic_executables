import '../models/ae_result.dart';
import '../models/generate.dart';

abstract interface class AeGenerationService {
  Future<AeResult<GenerateOutput>> generate(GenerateInput input);
}

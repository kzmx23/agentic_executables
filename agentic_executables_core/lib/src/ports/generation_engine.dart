import '../models/ae_result.dart';
import '../models/generate.dart';

abstract interface class GenerationEngine {
  String get id;

  bool get isAvailable;

  Future<AeResult<GenerateOutput>> generate(GenerateInput input);
}

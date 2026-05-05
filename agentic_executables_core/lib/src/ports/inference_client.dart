import '../models/ae_result.dart';
import '../models/inference.dart';

abstract interface class InferenceClient {
  String get id;

  bool get isAvailable;

  Future<AeResult<InferenceResponse>> infer(InferenceRequest request);
}

import '../models/ae_result.dart';
import '../models/evaluate.dart';
import '../models/verify.dart';

abstract interface class AeValidationService {
  AeResult<VerifyOutput> verify(VerifyInput input);

  AeResult<EvaluateOutput> evaluate(EvaluateInput input);
}

import '../models/ae_result.dart';
import '../models/get_definition.dart';

abstract interface class AeDefinitionService {
  AeResult<GetDefinitionOutput> getDefinition();
}

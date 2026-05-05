import '../models/ae_result.dart';
import '../models/registry.dart';

abstract interface class AeRegistryService {
  Future<AeResult<RegistrySubmitOutput>> submitToRegistry(
    RegistrySubmitInput input,
  );

  Future<AeResult<RegistryGetOutput>> getFromRegistry(RegistryGetInput input);

  AeResult<RegistryBootstrapLocalOutput> bootstrapLocalRegistry(
    RegistryBootstrapLocalInput input,
  );
}

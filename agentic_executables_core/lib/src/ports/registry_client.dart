import '../models/types.dart';

abstract interface class RegistryClient {
  Future<bool> libraryExists(String libraryId);

  Future<String> fetchRegistryFile(String libraryId, AeAction action);

  String buildRegistryUrl(String libraryId, AeAction action);
}

abstract interface class DocumentStore {
  Future<String> getDocument(String filename);

  Future<Map<String, String>> getDocuments(List<String> filenames);

  void clearCache();
}

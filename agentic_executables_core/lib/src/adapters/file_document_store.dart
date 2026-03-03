import 'dart:io';

import 'package:path/path.dart' as path;

import '../ports/document_store.dart';

class FileDocumentStore implements DocumentStore {
  FileDocumentStore(this.resourcesPath);

  final String resourcesPath;
  final Map<String, String> _cache = <String, String>{};

  @override
  Future<String> getDocument(final String filename) async {
    final cached = _cache[filename];
    if (cached != null) {
      return cached;
    }

    final filePath = path.join(resourcesPath, filename);
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Document not found: $filename', filePath);
    }

    final content = await file.readAsString();
    _cache[filename] = content;
    return content;
  }

  @override
  Future<Map<String, String>> getDocuments(final List<String> filenames) async {
    final docs = <String, String>{};
    for (final filename in filenames) {
      docs[filename] = await getDocument(filename);
    }
    return docs;
  }

  @override
  void clearCache() {
    _cache.clear();
  }
}

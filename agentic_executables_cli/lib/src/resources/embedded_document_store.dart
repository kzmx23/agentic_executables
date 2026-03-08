import 'dart:io';

import 'package:agentic_executables_core/agentic_executables_core.dart';

class EmbeddedDocumentStore implements DocumentStore {
  EmbeddedDocumentStore(this._documents);

  final Map<String, String> _documents;

  @override
  Future<String> getDocument(final String filename) async {
    final content = _documents[filename];
    if (content == null) {
      throw FileSystemException(
        'Embedded document not found: $filename',
        filename,
      );
    }
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
  void clearCache() {}
}

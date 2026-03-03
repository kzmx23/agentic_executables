import 'types.dart';

class GenerateInput {
  const GenerateInput({
    required this.libraryId,
    required this.libraryRoot,
    required this.outputDir,
    this.engineMode = AeGenerationEngineMode.auto,
    this.dryRun = false,
  });

  final String libraryId;
  final String libraryRoot;
  final String outputDir;
  final AeGenerationEngineMode engineMode;
  final bool dryRun;

  GenerateInput copyWith({final AeGenerationEngineMode? engineMode}) =>
      GenerateInput(
        libraryId: libraryId,
        libraryRoot: libraryRoot,
        outputDir: outputDir,
        engineMode: engineMode ?? this.engineMode,
        dryRun: dryRun,
      );
}

class GeneratedFile {
  const GeneratedFile({required this.path, required this.content});

  final String path;
  final String content;

  int get loc => content.split('\n').length;

  Map<String, dynamic> toJson() => {
        'path': path,
        'loc': loc,
        'content': content,
      };
}

class GenerateOutput {
  const GenerateOutput({
    required this.libraryId,
    required this.engineUsed,
    required this.files,
    this.notes,
  });

  final String libraryId;
  final String engineUsed;
  final List<GeneratedFile> files;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'library_id': libraryId,
        'engine_used': engineUsed,
        'files': files.map((final e) => e.toJson()).toList(growable: false),
        if (notes != null) 'notes': notes,
      };
}

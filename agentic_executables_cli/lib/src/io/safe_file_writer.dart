import 'dart:io';

import 'package:path/path.dart' as path;

enum FileWriteStatus {
  added('added'),
  updated('updated'),
  unchanged('unchanged'),
  blocked('blocked');

  const FileWriteStatus(this.value);

  final String value;
}

class SafeWriteOptions {
  const SafeWriteOptions({
    this.check = false,
    this.diff = false,
    this.backup = false,
    this.noOverwrite = false,
  });

  final bool check;
  final bool diff;
  final bool backup;
  final bool noOverwrite;

  Map<String, dynamic> toJson() => {
        'check': check,
        'diff': diff,
        'backup': backup,
        'no_overwrite': noOverwrite,
      };
}

class FileWriteRequest {
  const FileWriteRequest({required this.path, required this.content});

  final String path;
  final String content;
}

class FileWriteResult {
  const FileWriteResult({
    required this.path,
    required this.status,
    required this.changed,
    this.diff,
    this.backupPath,
    this.message,
  });

  final String path;
  final FileWriteStatus status;
  final bool changed;
  final String? diff;
  final String? backupPath;
  final String? message;

  Map<String, dynamic> toJson() => {
        'path': path,
        'status': status.value,
        'changed': changed,
        if (diff != null) 'diff': diff,
        if (backupPath != null) 'backup_path': backupPath,
        if (message != null) 'message': message,
      };
}

class SafeWriteBatchResult {
  const SafeWriteBatchResult({required this.files});

  final List<FileWriteResult> files;

  bool get hasChanges => files.any((final file) => file.changed);

  bool get hasBlocked => files.any(
        (final file) => file.status == FileWriteStatus.blocked,
      );

  bool get wroteAny => files.any(
        (final file) =>
            file.status == FileWriteStatus.added ||
            file.status == FileWriteStatus.updated,
      );

  Map<String, dynamic> toJson() => {
        'files':
            files.map((final file) => file.toJson()).toList(growable: false),
        'has_changes': hasChanges,
        'has_blocked': hasBlocked,
        'wrote_any': wroteAny,
      };
}

class SafeFileWriter {
  const SafeFileWriter();

  Future<SafeWriteBatchResult> writeAll({
    required final List<FileWriteRequest> requests,
    required final SafeWriteOptions options,
  }) async {
    final sorted = [...requests]
      ..sort((final a, final b) => a.path.compareTo(b.path));

    final results = <FileWriteResult>[];
    for (final request in sorted) {
      results.add(
        await _writeOne(request: request, options: options),
      );
    }

    return SafeWriteBatchResult(files: results);
  }

  Future<FileWriteResult> _writeOne({
    required final FileWriteRequest request,
    required final SafeWriteOptions options,
  }) async {
    final target = File(request.path);
    final exists = await target.exists();
    final before = exists ? await target.readAsString() : null;
    final changed = before != request.content;

    if (!changed) {
      return FileWriteResult(
        path: request.path,
        status: FileWriteStatus.unchanged,
        changed: false,
      );
    }

    final diff = options.diff
        ? _buildUnifiedDiff(
            filePath: request.path,
            before: before ?? '',
            after: request.content,
          )
        : null;

    if (options.check) {
      return FileWriteResult(
        path: request.path,
        status: exists ? FileWriteStatus.updated : FileWriteStatus.added,
        changed: true,
        diff: diff,
        message: 'Write skipped due to --check',
      );
    }

    if (exists && options.noOverwrite) {
      return FileWriteResult(
        path: request.path,
        status: FileWriteStatus.blocked,
        changed: true,
        diff: diff,
        message: 'Overwrite blocked by --no-overwrite',
      );
    }

    await target.parent.create(recursive: true);

    String? backupPath;
    if (exists && options.backup) {
      backupPath = '${request.path}.backup.${_timestampToken()}';
      await target.copy(backupPath);
    }

    final tempPath =
        '${request.path}.tmp.${pid}.${DateTime.now().microsecondsSinceEpoch}';
    final temp = File(tempPath);

    try {
      await temp.writeAsString(request.content);
      if (await target.exists()) {
        await target.delete();
      }
      await temp.rename(request.path);
    } on Object {
      if (await temp.exists()) {
        await temp.delete();
      }
      rethrow;
    }

    return FileWriteResult(
      path: request.path,
      status: exists ? FileWriteStatus.updated : FileWriteStatus.added,
      changed: true,
      diff: diff,
      backupPath: backupPath,
    );
  }

  String _buildUnifiedDiff({
    required final String filePath,
    required final String before,
    required final String after,
  }) {
    final beforeLines = _splitLines(before);
    final afterLines = _splitLines(after);

    final relativePath = path.normalize(filePath);
    final buffer = StringBuffer()
      ..writeln('--- $relativePath')
      ..writeln('+++ $relativePath')
      ..writeln(
        '@@ -1,${beforeLines.length} +1,${afterLines.length} @@',
      );

    for (final line in beforeLines) {
      buffer.writeln('-$line');
    }
    for (final line in afterLines) {
      buffer.writeln('+$line');
    }

    return buffer.toString().trimRight();
  }

  List<String> _splitLines(final String value) {
    if (value.isEmpty) {
      return const [];
    }
    return value.split('\n');
  }

  String _timestampToken() {
    final now = DateTime.now().toUtc().toIso8601String();
    return now.replaceAll(RegExp(r'[^0-9]'), '');
  }
}

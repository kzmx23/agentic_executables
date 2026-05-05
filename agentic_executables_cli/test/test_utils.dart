import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agentic_executables_cli/agentic_executables_cli.dart';
import 'package:agentic_executables_core/agentic_executables_core.dart';

/// Walks upward from [Directory.current] (run tests from `agentic_executables_cli/`).
Directory findRepoRootDirectory({
  required bool Function(String rootPath) matches,
}) {
  var dir = Directory.current.absolute;
  while (true) {
    if (matches(dir.path)) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Unable to locate repository root (from ${dir.path})');
    }
    dir = parent;
  }
}

class CliRunResult {
  const CliRunResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;

  Map<String, dynamic> get json {
    final lines = stdout
        .split('\n')
        .map((final line) => line.trim())
        .where((final line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) {
      return const {};
    }
    return jsonDecode(lines.last) as Map<String, dynamic>;
  }
}

Future<CliRunResult> runCli(
  final List<String> args, {
  final String? repoRoot,
  final String? codexBinary,
  final Map<String, String>? environment,
  final InferenceClient? inferenceClient,
  final String? registryProbeUrl,
  final RegistryClient? registryClient,
}) async {
  final outController = StreamController<List<int>>();
  final errController = StreamController<List<int>>();
  final outBuffer = StringBuffer();
  final errBuffer = StringBuffer();

  final outDone = Completer<void>();
  final errDone = Completer<void>();

  outController.stream
      .transform(utf8.decoder)
      .listen(outBuffer.write, onDone: () => outDone.complete());
  errController.stream
      .transform(utf8.decoder)
      .listen(errBuffer.write, onDone: () => errDone.complete());

  final outSink = IOSink(outController.sink);
  final errSink = IOSink(errController.sink);

  final cli = AeCli(
    out: outSink,
    err: errSink,
    codexBinary: codexBinary,
    environment: environment,
    inferenceClient: inferenceClient,
    registryProbeUrl: registryProbeUrl,
    registryClient: registryClient,
  );

  final exitCode = await cli.run(args);

  await outSink.close();
  await errSink.close();
  await outDone.future;
  await errDone.future;

  return CliRunResult(
    exitCode: exitCode,
    stdout: outBuffer.toString(),
    stderr: errBuffer.toString(),
  );
}

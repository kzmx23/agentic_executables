import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../ports/process_runner.dart';

/// Production [ProcessRunner] backed by `dart:io` Process.
class ProcessRunnerIo implements ProcessRunner {
  const ProcessRunnerIo();

  @override
  Future<ProcessRunResult> run({
    required final String executable,
    required final List<String> arguments,
    final String? stdinInput,
    final Map<String, String>? environment,
    final String? workingDirectory,
    final Duration? timeout,
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      environment: environment,
      workingDirectory: workingDirectory,
      runInShell: false,
    );

    final stdoutFuture = process.stdout.transform(utf8.decoder).join();
    final stderrFuture = process.stderr.transform(utf8.decoder).join();

    if (stdinInput != null) {
      process.stdin.add(utf8.encode(stdinInput));
    }
    await process.stdin.close();

    Timer? killer;
    if (timeout != null) {
      killer = Timer(timeout, () => process.kill());
    }

    final exitCode = await process.exitCode;
    killer?.cancel();
    final stdout = await stdoutFuture;
    final stderr = await stderrFuture;

    return ProcessRunResult(
      exitCode: exitCode,
      stdout: stdout,
      stderr: stderr,
    );
  }
}

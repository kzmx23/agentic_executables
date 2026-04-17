/// Result of running a child process to completion.
class ProcessRunResult {
  const ProcessRunResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

/// Runs a child process. Test seam — production uses [ProcessRunnerIo].
abstract interface class ProcessRunner {
  /// Run [executable] with [arguments]. If [stdinInput] is given, it is
  /// written to the child's stdin and stdin is closed. Returns once the
  /// process exits. If [timeout] elapses, the process is killed and a
  /// non-zero [ProcessRunResult.exitCode] is returned.
  Future<ProcessRunResult> run({
    required final String executable,
    required final List<String> arguments,
    final String? stdinInput,
    final Map<String, String>? environment,
    final String? workingDirectory,
    final Duration? timeout,
  });
}

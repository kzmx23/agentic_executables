import 'dart:convert';
import 'dart:io';

import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:path/path.dart' as path;

class CodexExecGenerationEngine implements GenerationEngine {
  CodexExecGenerationEngine({
    final String binaryName = 'codex',
    final Map<String, String>? environment,
    final GenerationPromptBuilder? promptBuilder,
  }) : _delegate = InferenceGenerationEngine(
          client: CodexExecInferenceClient(
            binaryName: binaryName,
            environment: environment,
          ),
          promptBuilder: promptBuilder,
        );

  final InferenceGenerationEngine _delegate;

  @override
  String get id => _delegate.id;

  @override
  bool get isAvailable => _delegate.isAvailable;

  @override
  Future<AeResult<GenerateOutput>> generate(final GenerateInput input) =>
      _delegate.generate(input);
}

class CodexExecInferenceClient implements InferenceClient {
  CodexExecInferenceClient({this.binaryName = 'codex', this.environment});

  final String binaryName;
  final Map<String, String>? environment;

  @override
  String get id => 'codex';

  @override
  bool get isAvailable => _resolveBinaryPath() != null;

  @override
  Future<AeResult<InferenceResponse>> infer(
    final InferenceRequest request,
  ) async {
    final binaryPath = _resolveBinaryPath();
    if (binaryPath == null) {
      return AeResult.fail(
        code: 'engine_unavailable',
        message: 'codex binary not found in PATH',
      );
    }

    Directory? tempDir;
    try {
      tempDir = await Directory.systemTemp.createTemp('ae_codex_schema_');
      final schemaPath = path.join(tempDir.path, 'schema.json');
      final outputPath = path.join(tempDir.path, 'last_message.json');

      await File(schemaPath).writeAsString(jsonEncode(request.outputSchema));

      final primaryArgs = [
        'exec',
        '--sandbox',
        'workspace-write',
        '--full-auto',
        '--output-schema',
        schemaPath,
        '--output-last-message',
        outputPath,
        request.prompt,
      ];

      var result = await Process.run(
        binaryPath,
        primaryArgs,
        workingDirectory: request.workingDirectory,
        environment: environment,
      );

      if (result.exitCode != 0 &&
          _shouldRetryLegacy(result.stderr.toString())) {
        final fallbackArgs = [
          'exec',
          '--sandbox',
          'workspace-write',
          '-a',
          'on-failure',
          '--output-schema',
          schemaPath,
          '--output-last-message',
          outputPath,
          request.prompt,
        ];

        result = await Process.run(
          binaryPath,
          fallbackArgs,
          workingDirectory: request.workingDirectory,
          environment: environment,
        );
      }

      if (result.exitCode != 0) {
        return AeResult.fail(
          code: 'codex_exec_failed',
          message: 'codex exec failed with exit code ${result.exitCode}',
          details: _coalesceErrorDetails(result),
        );
      }

      final outputFile = File(outputPath);
      final String rawOutput;
      if (await outputFile.exists()) {
        rawOutput = await outputFile.readAsString();
      } else {
        rawOutput = result.stdout.toString();
      }

      final decoded = _decodeStructuredOutput(rawOutput);
      if (decoded == null) {
        return AeResult.fail(
          code: 'codex_parse_failed',
          message: 'Failed to parse structured output from codex',
          details: rawOutput,
        );
      }

      return AeResult.ok(
        InferenceResponse(output: decoded, rawOutput: rawOutput),
        meta: const {'engine': 'codex'},
      );
    } on FileSystemException catch (error) {
      return AeResult.fail(
        code: 'codex_exec_failed',
        message: 'Failed to prepare codex schema/output files',
        details: error.toString(),
      );
    } catch (error) {
      return AeResult.fail(
        code: 'codex_exec_failed',
        message: 'Failed to execute codex',
        details: error.toString(),
      );
    } finally {
      if (tempDir != null) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {
          // Best-effort cleanup.
        }
      }
    }
  }

  bool _shouldRetryLegacy(final String stderr) {
    final normalized = stderr.toLowerCase();
    return normalized.contains('unexpected argument') ||
        normalized.contains('found argument') ||
        normalized.contains('unrecognized option');
  }

  String _coalesceErrorDetails(final ProcessResult result) {
    final stderr = result.stderr.toString().trim();
    final stdout = result.stdout.toString().trim();
    if (stderr.isNotEmpty) {
      return stderr;
    }
    if (stdout.isNotEmpty) {
      return stdout;
    }
    return 'codex exec failed without stderr/stdout output';
  }

  Map<String, dynamic>? _decodeStructuredOutput(final String output) {
    final trimmed = output.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(trimmed);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      final lines = trimmed
          .split('\n')
          .map((final line) => line.trim())
          .where((final line) => line.isNotEmpty)
          .toList(growable: false);

      for (var index = lines.length - 1; index >= 0; index--) {
        final candidate = lines[index];
        if (!(candidate.startsWith('{') || candidate.startsWith('['))) {
          continue;
        }

        try {
          final decoded = jsonDecode(candidate);
          if (decoded is Map<String, dynamic>) {
            return decoded;
          }
        } catch (_) {
          continue;
        }
      }

      final firstBrace = trimmed.indexOf('{');
      final lastBrace = trimmed.lastIndexOf('}');
      if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
        final slice = trimmed.substring(firstBrace, lastBrace + 1);
        try {
          final decoded = jsonDecode(slice);
          return decoded is Map<String, dynamic> ? decoded : null;
        } catch (_) {
          return null;
        }
      }

      return null;
    }
  }

  String? _resolveBinaryPath() {
    if (binaryName.contains(Platform.pathSeparator)) {
      return File(binaryName).existsSync() ? binaryName : null;
    }

    final pathEnv = (environment ?? Platform.environment)['PATH'];
    if (pathEnv == null || pathEnv.isEmpty) {
      return null;
    }

    final candidates = pathEnv
        .split(Platform.isWindows ? ';' : ':')
        .where((final segment) => segment.isNotEmpty)
        .map((final segment) => '$segment${Platform.pathSeparator}$binaryName')
        .toList(growable: false);

    if (Platform.isWindows) {
      for (final candidate in candidates) {
        final exe = File('$candidate.exe');
        if (exe.existsSync()) {
          return exe.path;
        }
        final cmd = File('$candidate.cmd');
        if (cmd.existsSync()) {
          return cmd.path;
        }
      }
    }

    for (final candidate in candidates) {
      final file = File(candidate);
      if (file.existsSync()) {
        return file.path;
      }
    }

    return null;
  }
}

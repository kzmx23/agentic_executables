import 'dart:io';

import 'package:agentic_executables_core/agentic_executables_core.dart';

/// Builds a [DistillationService] whose executor list is derived from
/// [config] and the current process environment.
///
/// Priority order (first runnable wins in [DefaultDistillationService]):
///
/// 1. Claude Code subagent  (host detected via `CLAUDECODE` /
///    `CLAUDE_CODE_VERSION`)
/// 2. Codex exec            (host detected via `CODEX_HOME` /
///    `OPENAI_CODEX_VERSION`)
/// 3. BYOK direct LLM       (configured via [HubConfig.byok])
///
/// Each executor's own `canRun()` decides if it is viable; the
/// dispatcher always lists all three in order so that the service's
/// fallthrough logic works without further conditionals here.
///
/// [processEnv], [processRunner], and [httpInvoker] are overridable
/// seams for tests.
DistillationService buildDistillationService({
  required final HubConfig config,
  final Map<String, String>? processEnv,
  final ProcessRunner? processRunner,
  final HttpInvoker? httpInvoker,
}) {
  final env = processEnv ?? Platform.environment;
  final runner = processRunner ?? ProcessRunnerIo();

  final executors = <DistillationExecutor>[
    ClaudeCodeSubagentExecutor(
      processRunner: runner,
      environment: env,
    ),
    CodexExecExecutor(
      processRunner: runner,
      environment: env,
    ),
  ];

  final byok = _buildByokExecutor(
    byok: config.byok,
    env: env,
    httpInvoker: httpInvoker,
  );
  if (byok != null) executors.add(byok);

  return DefaultDistillationService(executors: executors);
}

ByokLlmExecutor? _buildByokExecutor({
  required final HubByokConfig? byok,
  required final Map<String, String> env,
  final HttpInvoker? httpInvoker,
}) {
  if (byok == null) return null;

  final resolvedKey = _resolveApiKey(byok, env);
  if (resolvedKey == null || resolvedKey.isEmpty) return null;

  final provider = _parseProvider(byok.provider);
  if (provider == null) return null;

  return ByokLlmExecutor(
    httpInvoker: httpInvoker ?? DartIoHttpInvoker(),
    provider: provider,
    apiKey: resolvedKey,
    model: byok.model ?? _defaultModelFor(provider),
  );
}

String? _resolveApiKey(
  final HubByokConfig byok,
  final Map<String, String> env,
) {
  final envName = byok.apiKeyEnv;
  if (envName != null && envName.isNotEmpty) {
    final v = env[envName];
    if (v != null && v.isNotEmpty) return v;
  }
  final plain = byok.apiKey;
  if (plain != null && plain.isNotEmpty) return plain;
  return null;
}

ByokProvider? _parseProvider(final String raw) {
  switch (raw) {
    case 'anthropic':
      return ByokProvider.anthropic;
    case 'openai':
      return ByokProvider.openai;
    default:
      return null;
  }
}

String _defaultModelFor(final ByokProvider provider) {
  switch (provider) {
    case ByokProvider.anthropic:
      return 'claude-sonnet-4-6';
    case ByokProvider.openai:
      return 'gpt-4o';
  }
}

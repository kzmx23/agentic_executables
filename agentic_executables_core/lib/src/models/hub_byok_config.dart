/// Optional BYOK (Bring Your Own Key) block parsed from hub.yaml.
///
/// When present, the AE distillation dispatcher can instantiate
/// a [ByokLlmExecutor] as a fallback when no in-host subagent
/// (Claude Code, Codex) is available.
class HubByokConfig {
  const HubByokConfig({
    required this.provider,
    this.apiKeyEnv,
    this.apiKey,
    this.model,
  });

  /// Provider id: "anthropic" or "openai". Kept as a free string here
  /// to decouple the config model from the executor enum.
  final String provider;

  /// Env-var name to read the key from (preferred).
  final String? apiKeyEnv;

  /// Plaintext key (discouraged; supported for completeness).
  final String? apiKey;

  /// Optional model override (e.g. "claude-opus-4-7").
  final String? model;

  Map<String, dynamic> toJson() => {
        'provider': provider,
        if (apiKeyEnv != null) 'api_key_env': apiKeyEnv,
        if (apiKey != null) 'api_key': apiKey,
        if (model != null) 'model': model,
      };

  factory HubByokConfig.fromMap(final Map<dynamic, dynamic> map) =>
      HubByokConfig(
        provider: map['provider']?.toString() ?? '',
        apiKeyEnv: map['api_key_env']?.toString(),
        apiKey: map['api_key']?.toString(),
        model: map['model']?.toString(),
      );
}

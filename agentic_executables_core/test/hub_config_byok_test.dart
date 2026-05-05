import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:test/test.dart';

void main() {
  group('HubConfig.byok (Phase 4E)', () {
    test('parses full byok block (provider + api_key_env + model)', () {
      final cfg = HubConfig.fromMap({
        'version': 1,
        'remotes': const {},
        'byok': {
          'provider': 'anthropic',
          'api_key_env': 'ANTHROPIC_API_KEY',
          'model': 'claude-opus-4-7',
        },
      });
      expect(cfg.byok, isNotNull);
      expect(cfg.byok!.provider, 'anthropic');
      expect(cfg.byok!.apiKeyEnv, 'ANTHROPIC_API_KEY');
      expect(cfg.byok!.apiKey, isNull);
      expect(cfg.byok!.model, 'claude-opus-4-7');

      final j = cfg.toJson();
      expect(j['byok'], isA<Map>());
      final bj = j['byok'] as Map;
      expect(bj['provider'], 'anthropic');
      expect(bj['api_key_env'], 'ANTHROPIC_API_KEY');
      expect(bj.containsKey('api_key'), isFalse);
      expect(bj['model'], 'claude-opus-4-7');

      final y = cfg.toYamlString();
      expect(y, contains('byok:'));
      expect(y, contains('provider: "anthropic"'));
      expect(y, contains('api_key_env: "ANTHROPIC_API_KEY"'));
      expect(y, contains('model: "claude-opus-4-7"'));
    });

    test('parses minimal block (provider + api_key plaintext)', () {
      final cfg = HubConfig.fromMap({
        'version': 1,
        'byok': {
          'provider': 'openai',
          'api_key': 'sk-test',
        },
      });
      expect(cfg.byok, isNotNull);
      expect(cfg.byok!.provider, 'openai');
      expect(cfg.byok!.apiKeyEnv, isNull);
      expect(cfg.byok!.apiKey, 'sk-test');
      expect(cfg.byok!.model, isNull);
    });

    test('missing byok key leaves byok null and toJson omits it', () {
      final cfg = HubConfig.fromMap({'version': 1, 'remotes': const {}});
      expect(cfg.byok, isNull);
      expect(cfg.toJson().containsKey('byok'), isFalse);
      expect(cfg.toYamlString(), isNot(contains('byok:')));
    });
  });
}

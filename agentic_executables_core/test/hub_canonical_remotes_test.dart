import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:test/test.dart';

void main() {
  group('HubConfig.canonicalRemotes (3.0 placeholder)', () {
    test('default is empty map', () {
      const cfg = HubConfig();
      expect(cfg.canonicalRemotes, isEmpty);
    });

    test('toJson includes canonical_remotes when set', () {
      const cfg = HubConfig(
        canonicalRemotes: {
          'public': HubRemote(url: 'https://example.com/canonical'),
        },
      );
      final j = cfg.toJson();
      expect(j['canonical_remotes'], isA<Map>());
      expect(
        (j['canonical_remotes'] as Map)['public'],
        isA<Map>(),
      );
    });

    test('toJson omits canonical_remotes when empty', () {
      const cfg = HubConfig();
      expect(cfg.toJson().containsKey('canonical_remotes'), isFalse);
    });

    test('fromMap parses canonical_remotes', () {
      final cfg = HubConfig.fromMap({
        'version': 1,
        'remotes': const {},
        'canonical_remotes': {
          'public': {
            'url': 'https://example.com/canonical',
            'branch': 'main',
            'type': 'github',
          },
        },
      });
      expect(cfg.canonicalRemotes.length, 1);
      expect(cfg.canonicalRemotes['public']?.url, 'https://example.com/canonical');
    });

    test('toYamlString emits canonical_remotes', () {
      const cfg = HubConfig(
        canonicalRemotes: {
          'public': HubRemote(url: 'https://x.com/y'),
        },
      );
      final yamlStr = cfg.toYamlString();
      expect(yamlStr, contains('canonical_remotes:'));
      expect(yamlStr, contains('public:'));
      expect(yamlStr, contains('https://x.com/y'));
    });
  });
}

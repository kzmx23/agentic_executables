import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  test('all command surfaces parse and execute without parse errors', () async {
    final temp = await Directory.systemTemp.createTemp('ae_cli_parse_');
    addTearDown(() => temp.delete(recursive: true));

    final verifyInput = File(p.join(temp.path, 'verify.json'));
    await verifyInput.writeAsString(
      jsonEncode({'context_type': 'project', 'action': 'install'}),
    );

    final evaluateInput = File(p.join(temp.path, 'evaluate.json'));
    await evaluateInput.writeAsString(
      jsonEncode({'context_type': 'project', 'action': 'install'}),
    );

    final commands = <List<String>>[
      ['definition'],
      ['instructions', '--context', 'project', '--action', 'install'],
      ['verify', '--input', verifyInput.path],
      ['evaluate', '--input', evaluateInput.path],
      ['registry', 'get', '--library-id', 'dart_provider'],
      ['registry', 'submit', '--library-id', 'dart_provider'],
      ['registry', 'bootstrap-local', '--ae-use-path', temp.path],
      [
        'generate',
        '--library-id',
        'dart_provider',
        '--library-root',
        temp.path,
        '--engine',
        'template',
        '--dry-run',
      ],
      ['skill', 'install', '--target', p.join(temp.path, 'skills')],
      ['skill', 'update', '--target', p.join(temp.path, 'skills')],
    ];

    for (final args in commands) {
      final result = await runCli(args, repoRoot: _repoRoot());
      expect(result.exitCode, isNot(64), reason: 'Failed parsing: $args');
    }
  });
}

String _repoRoot() {
  var dir = Directory.current.absolute;
  while (true) {
    if (Directory(p.join(dir.path, 'skills')).existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      return Directory.current.path;
    }
    dir = parent;
  }
}

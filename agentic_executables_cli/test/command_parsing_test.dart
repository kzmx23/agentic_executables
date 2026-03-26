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
      ['package', 'resolve', '--package', 'dev.xs.registry'],
      [
        'package',
        'validate',
        '--instructions',
        '{"contract_version":"ae.v3.package.v1","package":{"id":"dev.xs.registry","version":"1.0.0"},"profile":{"id":"direct","major":1},"build":{"steps":[{"type":"copy","config":{"src":"."}}]},"deploy":{"plugins":[{"name":"systemd_service","version":1,"config":{"unit_name":"lythe-dev-xs-registry.service"}}],"inputs":{"required":[]}},"domain":{"capabilities":{"wildcard_support_mode":"none"}},"safety":{"constraints":{"allowed_executors":["lythe"],"forbidden_actions":[]}}}',
      ],
      ['instructions', '--context', 'project', '--action', 'install'],
      ['verify', '--input', verifyInput.path],
      ['evaluate', '--input', evaluateInput.path],
      ['doctor', '--target', p.join(temp.path, 'skills')],
      [
        'registry',
        'get',
        '--library-id',
        'dart_provider',
        '--action',
        'install',
      ],
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
      [
        'know',
        'build',
        '--url',
        'https://arxiv.org/pdf/2312.11514',
        '--name',
        'llm_flash',
        '--format',
        'pdf',
      ],
      [
        'know',
        'build',
        '--url',
        'https://example.com/doc.pdf',
        '--name',
        'pdf_pack',
        '--format',
        'auto',
      ],
      ['know', 'build', '--url', 'https://example.com/same.pdf', '--name', 'dup', '--on-conflict', 'reuse'],
      ['know', 'build', '--url', 'https://example.com/same.pdf', '--name', 'other', '--on-conflict', 'fail'],
      ['know', 'migrate', '--dry-run'],
      ['know', 'migrate'],
      [
        'e2e',
        'sync-know',
        '--manifest',
        p.join(temp.path, 'e2e_know_sources.yaml'),
        '--hub',
        p.join(temp.path, 'empty_hub'),
      ],
      [
        'spec',
        'export',
        '--out',
        p.join(temp.path, 'specout'),
        '--hub',
        p.join(temp.path, 'empty_hub'),
        '--matrix',
        p.join(temp.path, 'matrix.yaml'),
        '--manifest',
        p.join(temp.path, 'e2e_know_sources.yaml'),
        '--matrix-baseline',
        p.join(temp.path, 'matrix.yaml'),
      ],
    ];

    await File(p.join(temp.path, 'matrix.yaml')).writeAsString('''
version: 1
schema: ae.know.matrix.v1
title: T
''');
    await File(p.join(temp.path, 'e2e_know_sources.yaml')).writeAsString('''
version: 1
schema: spec_export.know_sources.v1
default_locale: en
packs: []
''');
    await Directory(p.join(temp.path, 'empty_hub')).create(recursive: true);
    await File(p.join(temp.path, 'empty_hub', 'hub.yaml')).writeAsString(
      'version: 1\n',
    );

    for (final args in commands) {
      final result = await runCli(args);
      expect(result.exitCode, isNot(64), reason: 'Failed parsing: $args');
    }
  });
}

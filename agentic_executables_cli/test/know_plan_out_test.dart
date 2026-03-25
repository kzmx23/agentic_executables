import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  test('know plan --out writes markdown file', () async {
    final temp = await Directory.systemTemp.createTemp('ae_plan_out_');
    addTearDown(() => temp.delete(recursive: true));

    final hubPath = p.join(temp.path, 'hub');
    final docPath = p.join(temp.path, 'doc.md');
    await File(docPath).writeAsString('# Hello\n\nBody.\n');
    final outPath = p.join(temp.path, 'plan_out.md');

    var r = await runCli(['hub', 'init', '--path', hubPath]);
    expect(r.exitCode, 0);

    r = await runCli([
      'know',
      'build',
      '--path',
      docPath,
      '--name',
      'plan_out_pack',
      '--hub',
      hubPath,
    ]);
    expect(r.exitCode, 0, reason: r.stderr);

    r = await runCli([
      'know',
      'plan',
      '--name',
      'plan_out_pack',
      '--hub',
      hubPath,
      '--out',
      outPath,
    ]);
    expect(r.exitCode, 0, reason: r.stderr);
    final env = r.json;
    expect(env['success'], isTrue);
    expect(
      (env['data'] as Map)['plan_markdown'],
      isNotEmpty,
    );

    final written = await File(outPath).readAsString();
    expect(written, contains('# Implementation plan: plan_out_pack'));
    expect(written, contains('Hello'));
  });
}

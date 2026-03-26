import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  test('spec export writes spec_index and per-pack fixtures', () async {
    final temp = await Directory.systemTemp.createTemp('ae_spec_export_');
    addTearDown(() => temp.delete(recursive: true));

    final hubPath = p.join(temp.path, 'hub');
    final specDir = p.join(temp.path, 'spec');
    final docPath = p.join(temp.path, 'doc.md');
    final docPath2 = p.join(temp.path, 'doc2.md');
    await File(docPath).writeAsString('# Hello\n\nBody.\n');
    await File(docPath2).writeAsString('# Beta\n\nOther.\n');
    final matrixPath = p.join(temp.path, 'feature_matrix.yaml');
    await File(matrixPath).writeAsString('''
version: 1
schema: ae.know.matrix.v1
title: T
''');

    var r = await runCli(['hub', 'init', '--path', hubPath]);
    expect(r.exitCode, 0);

    r = await runCli([
      'know',
      'build',
      '--path',
      docPath,
      '--name',
      'alpha_pack',
      '--hub',
      hubPath,
    ]);
    expect(r.exitCode, 0, reason: r.stderr);

    r = await runCli([
      'know',
      'build',
      '--path',
      docPath2,
      '--name',
      'beta_pack',
      '--hub',
      hubPath,
    ]);
    expect(r.exitCode, 0, reason: r.stderr);

    r = await runCli([
      'spec',
      'export',
      '--out',
      specDir,
      '--hub',
      hubPath,
      '--matrix',
      matrixPath,
      '--locale',
      'en',
    ]);
    expect(r.exitCode, 0, reason: r.stderr);
    final env = r.json;
    expect(env['success'], isTrue);

    final indexRaw =
        await File(p.join(specDir, 'spec_index.json')).readAsString();
    final index = jsonDecode(indexRaw) as Map<String, dynamic>;
    expect(index['schema'], 'spec_export.v2');
    expect(index['version'], 2);
    expect(index['export_base'], '.');
    expect(index['definition_yaml'], 'definition.yaml');
    expect(index['definition_md'], 'definition.md');
    expect(index['definition_json'], 'definition.json');
    expect(File(p.join(specDir, 'definition.yaml')).existsSync(), isTrue);
    expect(File(p.join(specDir, 'definition.md')).existsSync(), isTrue);
    final defPtr = jsonDecode(
      File(p.join(specDir, 'definition.json')).readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(defPtr['schema'], 'ae.spec_definition_ptr.v1');
    expect(index['locale'], 'en');
    final packs = index['packs'] as List<dynamic>;
    expect(packs.length, 2);

    for (final pack in packs) {
      final m = pack as Map<String, dynamic>;
      final ks = m['know_show'] as String;
      final pl = m['plan'] as String;
      expect(File(p.join(specDir, ks)).existsSync(), isTrue);
      expect(File(p.join(specDir, pl)).readAsStringSync(), isNotEmpty);
    }
  });

  test('spec export matrix-baseline writes matrix_diff.json', () async {
    final temp = await Directory.systemTemp.createTemp('ae_spec_matrix_diff_');
    addTearDown(() => temp.delete(recursive: true));

    final hubPath = p.join(temp.path, 'hub');
    final specDir = p.join(temp.path, 'spec');
    final docPath = p.join(temp.path, 'doc.md');
    await File(docPath).writeAsString('# X\n');
    final matrixPath = p.join(temp.path, 'feature_matrix.yaml');
    final baselinePath = p.join(temp.path, 'baseline_matrix.yaml');
    const matrixBody = '''
version: 1
schema: ae.know.matrix.v1
title: T
''';
    await File(matrixPath).writeAsString(matrixBody);
    await File(baselinePath).writeAsString(matrixBody);

    var r = await runCli(['hub', 'init', '--path', hubPath]);
    expect(r.exitCode, 0);

    r = await runCli([
      'know',
      'build',
      '--path',
      docPath,
      '--name',
      'only_pack',
      '--hub',
      hubPath,
    ]);
    expect(r.exitCode, 0, reason: r.stderr);

    r = await runCli([
      'spec',
      'export',
      '--out',
      specDir,
      '--hub',
      hubPath,
      '--matrix',
      matrixPath,
      '--matrix-baseline',
      baselinePath,
      '--locale',
      'en',
    ]);
    expect(r.exitCode, 0, reason: r.stderr);

    final index = jsonDecode(
      File(p.join(specDir, 'spec_index.json')).readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(index['matrix_diff'], 'matrix_diff.json');
    final diffRaw =
        File(p.join(specDir, 'matrix_diff.json')).readAsStringSync();
    final diff = jsonDecode(diffRaw) as Map<String, dynamic>;
    expect(diff['summary'], isNotNull);
    expect((diff['changed_cells'] as List).length, 0);
  });
}

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Core prompt sync', () {
    final mcpRoot = _findMcpRoot();
    final repoRoot = Directory(p.normalize(p.join(mcpRoot.path, '..')));
    final canonicalDir = Directory(p.join(repoRoot.path, 'prompts_framework'));
    final resourceDir = Directory(p.join(mcpRoot.path, 'resources'));

    const coreFiles = ['ae_context.md', 'ae_use.md', 'ae_bootstrap.md'];

    test('canonical and resource files are byte-equivalent', () {
      for (final fileName in coreFiles) {
        final sourceFile = File(p.join(canonicalDir.path, fileName));
        final resourceFile = File(p.join(resourceDir.path, fileName));

        expect(sourceFile.existsSync(), isTrue,
            reason: 'Missing canonical file: ${sourceFile.path}');
        expect(resourceFile.existsSync(), isTrue,
            reason: 'Missing resource file: ${resourceFile.path}');

        final sourceBytes = sourceFile.readAsBytesSync();
        final resourceBytes = resourceFile.readAsBytesSync();

        expect(resourceBytes, equals(sourceBytes),
            reason:
                'Prompt drift detected for $fileName. Run scripts/sync_core_prompts.sh.');
      }
    });

    test('canonical files contain required section headers in order', () {
      final requiredSections = <String, List<String>>{
        'ae_context.md': [
          '# AE Context',
          '## Purpose',
          '## Canonical Terms',
          '## Context-Action Matrix',
          '## Core Principles',
          '## File Responsibilities',
          '## Minimal File Skeletons',
          '## Quality Constraints',
          '## Authoring Rules',
        ],
        'ae_use.md': [
          '# AE Use',
          '## Objective',
          '## Inputs',
          '## Action Mapping',
          '## Execution Algorithm',
          '## Adaptation Rules',
          '## Validation Protocol',
          '## Error Protocol',
          '## Completion Report Format',
          '## Stop Conditions',
        ],
        'ae_bootstrap.md': [
          '# AE Bootstrap',
          '## Objective',
          '## Inputs',
          '## Discovery',
          '## Output Contracts',
          '## Generation Algorithm',
          '## Update Algorithm',
          '## Quality Gates',
          '## Compression Rules',
          '## Done Criteria',
        ],
      };

      for (final entry in requiredSections.entries) {
        final fileName = entry.key;
        final expectedHeaders = entry.value;
        final lines =
            File(p.join(canonicalDir.path, fileName)).readAsLinesSync();

        var lastIndex = -1;
        for (final header in expectedHeaders) {
          final currentIndex =
              lines.indexWhere((final line) => line.trim() == header);

          expect(currentIndex, greaterThanOrEqualTo(0),
              reason: 'Missing required header "$header" in $fileName');
          expect(currentIndex, greaterThan(lastIndex),
              reason:
                  'Header "$header" is out of order in $fileName (expected strict order).');

          lastIndex = currentIndex;
        }
      }
    });

    test('canonical files satisfy hard line caps', () {
      const lineCaps = <String, int>{
        'ae_context.md': 90,
        'ae_use.md': 180,
        'ae_bootstrap.md': 240,
      };

      for (final entry in lineCaps.entries) {
        final fileName = entry.key;
        final maxLines = entry.value;
        final lineCount =
            File(p.join(canonicalDir.path, fileName)).readAsLinesSync().length;

        expect(lineCount, lessThanOrEqualTo(maxLines),
            reason: '$fileName is $lineCount lines; cap is $maxLines.');
      }
    });
  });
}

Directory _findMcpRoot() {
  var dir = Directory.current.absolute;

  while (true) {
    final hasPubspec = File(p.join(dir.path, 'pubspec.yaml')).existsSync();
    final hasResources = Directory(p.join(dir.path, 'resources')).existsSync();

    if (hasPubspec && hasResources) {
      return dir;
    }

    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError(
        'Unable to locate agentic_executables_mcp root from ${Directory.current.path}',
      );
    }

    dir = parent;
  }
}

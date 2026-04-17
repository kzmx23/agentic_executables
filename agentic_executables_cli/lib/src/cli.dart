import 'dart:convert';
import 'dart:io';

import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;

import 'doctor/preflight_doctor.dart';
import 'engine/codex_exec_generation_engine.dart';
import 'io/safe_file_writer.dart';
import 'resources/embedded_cli_resources.dart';
import 'resources/embedded_document_store.dart';
import 'resources/skill_template_providers.dart';
import 'e2e_support.dart';
import 'spec_export_support.dart';

String? _knowPackDomainContext(final KnowPack? pack) {
  if (pack == null) return null;
  final b = StringBuffer(pack.indexContent);
  if (pack.matrixYamlContent != null) {
    b
      ..writeln()
      ..writeln('## Feature matrix')
      ..writeln()
      ..writeln(
        KnowFeatureMatrix.parseYamlString(pack.matrixYamlContent!)
            .renderMarkdown(),
      );
  }
  final n = pack.meta.artifacts?.normative;
  if (n != null) {
    b
      ..writeln()
      ..writeln('## Normative reference')
      ..writeln()
      ..writeln('- **${n.kind}**: ${n.ref}');
  }
  return b.toString();
}

class AeCli {
  AeCli({
    IOSink? out,
    IOSink? err,
    this.codexBinary,
    this.environment,
    this.inferenceClient,
    this.registryProbeUrl,
    this.registryClient,
  })  : _out = out ?? stdout,
        _err = err ?? stderr;

  final IOSink _out;
  final IOSink _err;
  final String? codexBinary;
  final Map<String, String>? environment;
  final InferenceClient? inferenceClient;
  final String? registryProbeUrl;
  final RegistryClient? registryClient;

  Future<int> run(final List<String> args) async {
    final parser = _buildParser();

    late final ArgResults results;
    try {
      results = parser.parse(args);
    } on FormatException catch (error) {
      final envelope = _errorEnvelope(
        command: 'parse',
        code: 'invalid_arguments',
        message: error.message,
      );
      _out.writeln(jsonEncode(envelope));
      return 64;
    }

    if (_shouldRenderHelp(results)) {
      _out.writeln(_helpText(results, parser));
      return 0;
    }

    final human = results['human'] == true;
    final commandPath = _commandPath(results);
    final stopwatch = Stopwatch()..start();

    late final Map<String, dynamic> envelope;
    try {
      final commandResult = await _dispatch(results);
      envelope = _resultToEnvelope(commandPath, commandResult);
    } catch (error, stack) {
      envelope = _errorEnvelope(
        command: commandPath,
        code: 'internal_error',
        message: 'Unhandled command error',
        details: '$error\n$stack',
      );
    }

    stopwatch.stop();

    final meta = (envelope['meta'] as Map<String, dynamic>?) ?? {};
    envelope['meta'] = {
      ...meta,
      'timing_ms': stopwatch.elapsedMilliseconds,
      'versions': {'cli': '3.0.0', 'core': AeCoreConfig.frameworkVersion},
    };

    if (!human &&
        (commandPath == 'package resolve' ||
            commandPath == 'package validate')) {
      return _renderPackageCommand(commandPath, envelope);
    }

    if (human) {
      _printHuman(envelope);
    } else {
      _out.writeln(jsonEncode(envelope));
    }

    if (commandPath == 'doctor' && envelope['success'] == true) {
      final data = envelope['data'] as Map<String, dynamic>?;
      final overall = data?['overall_status']?.toString();
      return overall == 'fail' ? 1 : 0;
    }

    return envelope['success'] == true ? 0 : 1;
  }

  ArgParser _buildParser() {
    final parser = ArgParser()
      ..addFlag('human', negatable: false, help: 'Readable output mode')
      ..addFlag('help', abbr: 'h', negatable: false, help: 'Show help');

    parser
        .addCommand('definition')
        ?.addFlag('help', abbr: 'h', negatable: false, help: 'Show help');

    parser.addCommand('instructions')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption(
        'context',
        allowed: AeContext.validValues,
        help: 'Context type',
      )
      ..addOption('action', allowed: AeAction.validValues, help: 'Action type')
      ..addOption(
        'resources-path',
        help: 'Optional override path to prompts resources',
      )
      ..addOption('know', help: 'Knowledge pack name for domain context');

    parser.addCommand('verify')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption(
        'input',
        defaultsTo: '-',
        help: 'JSON file path or - for stdin',
      );

    parser.addCommand('evaluate')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption(
        'input',
        defaultsTo: '-',
        help: 'JSON file path or - for stdin',
      );

    final package = parser.addCommand('package')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help');
    package?.addCommand('resolve')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption('package', help: 'Package identifier')
      ..addOption(
        'package-root',
        help:
            'Directory to read pubspec/package version from (default: cwd)',
      )
      ..addOption('target', defaultsTo: 'linux', help: 'Target runtime')
      ..addOption('format', defaultsTo: 'json', help: 'Output format');
    package?.addCommand('validate')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption(
        'instructions',
        help: 'Instruction file path, inline JSON payload, or - for stdin',
      );

    parser.addCommand('doctor')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption(
        'target',
        help: 'Override target skill directory checked for writability',
      );

    final registry = parser.addCommand('registry')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help');
    registry?.addCommand('get')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption('library-id', help: 'Library id')
      ..addOption(
        'action',
        allowed: AeAction.registryActions,
        help: 'Registry action',
      )
      ..addOption('out', help: 'Write fetched file to output path')
      ..addFlag('check', negatable: false, help: 'Detect drift without writes')
      ..addFlag('diff', negatable: false, help: 'Emit unified diff metadata')
      ..addFlag(
        'backup',
        negatable: false,
        help: 'Create timestamped backup before overwrite',
      )
      ..addFlag(
        'no-overwrite',
        negatable: false,
        help: 'Block overwriting existing files',
      );

    registry?.addCommand('submit')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption('library-url', help: 'Library repository URL')
      ..addOption('library-id', help: 'Library id')
      ..addMultiOption(
        'ae-use-files',
        splitCommas: true,
        help: 'AE file list (CSV or repeated flag)',
      );

    registry?.addCommand('bootstrap-local')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption('ae-use-path', help: 'Path to ae_use directory');

    parser.addCommand('generate')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption('library-id', help: 'Library id')
      ..addOption('library-root', help: 'Library root path')
      ..addOption('output-dir', help: 'Output directory for generated files')
      ..addOption(
        'engine',
        allowed: AeGenerationEngineMode.validValues,
        defaultsTo: AeGenerationEngineMode.auto.value,
        help: 'Generation engine mode',
      )
      ..addOption('know', help: 'Knowledge pack name for domain context')
      ..addFlag('dry-run', negatable: false, help: 'Do not write files')
      ..addFlag('check', negatable: false, help: 'Detect drift without writes')
      ..addFlag('diff', negatable: false, help: 'Emit unified diff metadata')
      ..addFlag(
        'backup',
        negatable: false,
        help: 'Create timestamped backup before overwrite',
      )
      ..addFlag(
        'no-overwrite',
        negatable: false,
        help: 'Block overwriting existing files',
      );

    final skill = parser.addCommand('skill')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help');
    skill?.addCommand('install')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption('target', help: 'Skills directory target')
      ..addOption('name', defaultsTo: 'ae-cli', help: 'Skill folder name')
      ..addFlag('upgrade', negatable: false, help: 'Upgrade existing skill')
      ..addOption(
        'template-path',
        help: 'Optional override path to SKILL.md template',
      );

    skill?.addCommand('update')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption('target', help: 'Skills directory target')
      ..addOption('name', defaultsTo: 'ae-cli', help: 'Skill folder name')
      ..addOption(
        'template-path',
        help: 'Optional override path to SKILL.md template',
      );

    final hub = parser.addCommand('hub')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help');
    hub?.addCommand('init')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption('path', help: 'Hub directory path')
      ..addFlag('project', negatable: false, help: 'Create hub in current project');
    hub?.addCommand('status')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption('hub', help: 'Hub path override');
    hub?.addCommand('pull')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption('hub', help: 'Hub path override')
      ..addOption('remote', defaultsTo: 'origin', help: 'Remote name')
      ..addOption('library-id', help: 'Specific library to pull')
      ..addOption(
        'type',
        allowed: ['know', 'use', 'packages'],
        help: 'Artifact type to pull',
      );
    hub?.addCommand('push')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption('hub', help: 'Hub path override')
      ..addOption('remote', defaultsTo: 'origin', help: 'Remote name');

    final know = parser.addCommand('know')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help');
    know?.addCommand('build')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption('url', help: 'Source URL (llms.txt, markdown, file://..., etc.)')
      ..addOption(
        'path',
        help: 'Local file path (alternative to --url; reads file directly)',
      )
      ..addOption('repo', help: 'Git repository URL to extract from')
      ..addOption('name', help: 'Short name for the knowledge pack')
      ..addOption('format',
          allowed: ['auto', 'llms_txt', 'html', 'markdown', 'pdf'],
          defaultsTo: 'auto',
          help: 'Source format hint')
      ..addOption('on-conflict',
          allowed: ['reuse', 'update', 'fail', 'new_version'],
          defaultsTo: 'reuse',
          help: 'When source already exists: reuse existing, update, fail, or new_version')
      ..addOption('hub', help: 'Hub path override');
    know?.addCommand('diff')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption('from', help: 'Source knowledge pack name')
      ..addOption('to', help: 'Target knowledge pack name')
      ..addOption('hub', help: 'Hub path override');
    know?.addCommand('list')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption('hub', help: 'Hub path override');
    know?.addCommand('show')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption('name', help: 'Knowledge pack name')
      ..addOption('hub', help: 'Hub path override');
    know?.addCommand('remove')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption('name', help: 'Knowledge pack name')
      ..addOption('hub', help: 'Hub path override');
    know?.addCommand('update')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption('name', help: 'Knowledge pack name')
      ..addOption('hub', help: 'Hub path override');
    know?.addCommand('migrate')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addFlag('dry-run', negatable: false, help: 'Report only, do not write')
      ..addOption('hub', help: 'Hub path override');

    final knowMatrix = know?.addCommand('matrix')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help');
    knowMatrix?.addCommand('init')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption('name', help: 'Knowledge pack name')
      ..addOption(
        'columns',
        help: 'Comma-separated matrix column ids (e.g. import,bundle,runtime,proof)',
      )
      ..addOption('title', help: 'Matrix title')
      ..addOption(
        'normative-kind',
        help: 'Normative ref kind: url or path',
      )
      ..addOption('normative-ref', help: 'Normative spec URL or path')
      ..addOption('hub', help: 'Hub path override');
    knowMatrix?.addCommand('scaffold')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption('name', help: 'Knowledge pack name')
      ..addOption('repo', help: 'Target repository root path')
      ..addOption(
        'out',
        help: 'Output YAML path (default: <repo>/docs/feature_matrix.yaml)',
      )
      ..addOption('hub', help: 'Hub path override');
    knowMatrix?.addCommand('diff')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption('from-name', help: 'Hub pack name (from)')
      ..addOption('to-name', help: 'Hub pack name (to)')
      ..addOption('from-file', help: 'matrix.yaml path (from)')
      ..addOption('to-file', help: 'matrix.yaml path (to)')
      ..addOption('hub', help: 'Hub path override');

    know?.addCommand('plan')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption('name', help: 'Knowledge pack name')
      ..addOption(
        'out',
        help: 'Write plan markdown to this file (UTF-8); stdout still emits JSON envelope',
      )
      ..addOption(
        'locale',
        help: 'BCP 47 locale for YAML front matter (inner agents)',
      )
      ..addOption('language', help: 'Alias for --locale')
      ..addOption('hub', help: 'Hub path override');

    final spec = parser.addCommand('spec')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help');
    spec?.addCommand('export')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption('out', help: 'Output spec directory')
      ..addOption('hub', help: 'Hub path override')
      ..addOption(
        'matrix',
        help: 'Path to feature_matrix.yaml (default: <cwd>/docs/feature_matrix.yaml)',
      )
      ..addOption(
        'matrix-baseline',
        help:
            'Optional prior matrix YAML; writes matrix_diff.json against --matrix',
      )
      ..addOption(
        'manifest',
        help:
            'Optional e2e_know_sources.yaml path (recorded in spec_index as e2e_manifest)',
      )
      ..addOption(
        'locale',
        help: 'BCP 47 locale for exported plans (default: en)',
      )
      ..addOption('language', help: 'Alias for --locale');

    final e2e = parser.addCommand('e2e')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help');
    e2e?.addCommand('sync-know')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption('manifest', help: 'Path to e2e_know_sources.yaml')
      ..addOption('hub', help: 'Hub path override')
      ..addOption(
        'base',
        help: 'Base path for resolving relative pack paths (default: cwd)',
      );

    parser.addCommand('init')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption(
        'root',
        help: 'Project root to scan (defaults to cwd). Hub must exist '
            'at <root>/.ae_hub.',
      )
      ..addFlag(
        'strict',
        defaultsTo: false,
        negatable: false,
        help: 'Exit non-zero if any sub-directory has no extractor.',
      );

    parser.addCommand('status')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption('root', help: 'Project root (defaults to cwd).')
      ..addOption(
        'pack',
        help: 'Narrow to a single artifact pack name (verifyOne).',
      )
      ..addOption('tier', help: 'Show only entries at this tier (1-4).');

    parser.addCommand('sync')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption('root', help: 'Project root (defaults to cwd).')
      ..addOption('pack', help: 'Sync only the named artifact pack.');

    final canonical = parser.addCommand('canonical')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help');
    canonical?.addCommand('init')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption('concept', help: 'Concept slug (required).')
      ..addOption('title', help: 'Human title (required).')
      ..addOption('root', help: 'Project root (defaults to cwd).');
    canonical?.addCommand('list')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption('root', help: 'Project root.');
    canonical?.addCommand('snapshot')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption('concept', help: 'Concept slug to snapshot.')
      ..addOption('root', help: 'Project root.');
    canonical?.addCommand('diff')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption('concept', help: 'Concept slug.')
      ..addOption('from', help: 'From version (e.g. v1).')
      ..addOption('to', help: 'To version (e.g. v2 or "current").')
      ..addOption('root', help: 'Project root.');
    canonical?.addCommand('import')
      ?..addFlag('help', abbr: 'h', negatable: false, help: 'Show help')
      ..addOption('from', help: 'External canonical directory path.')
      ..addOption('as', help: 'Concept id under which to import.')
      ..addOption('root', help: 'Project root.');

    return parser;
  }

  bool _shouldRenderHelp(final ArgResults root) {
    if (root.command == null) {
      return true;
    }

    if (root['help'] == true) {
      return true;
    }

    var current = root.command!;
    while (true) {
      if (current['help'] == true) {
        return true;
      }
      if (current.command == null) {
        return false;
      }
      current = current.command!;
    }
  }

  String _helpText(final ArgResults root, final ArgParser parser) {
    if (root.command == null || root['help'] == true && root.command == null) {
      return _globalUsage(parser);
    }

    final segments = <String>[];
    var current = root.command!;
    while (true) {
      final name = current.name;
      if (name != null) {
        segments.add(name);
      }
      if (current.command == null) {
        break;
      }
      current = current.command!;
    }

    final commandPath = segments.join(' ');
    return _contextualHelp(commandPath);
  }

  String _globalUsage(final ArgParser parser) => '''
ae CLI v3

${parser.usage}

Run `ae <command> --help` for contextual command help and examples.

Commands:
  ae definition
  ae package resolve --package <id> --target linux --format json
  ae package validate --instructions <file-or-json>
  ae instructions --context <library|project> --action <...> [--resources-path <path>] [--know <name>]
  ae verify --input <json-file|->
  ae evaluate --input <json-file|->
  ae doctor [--target <skills-dir>]
  ae registry get --library-id <id> --action <install|uninstall|update|use> [--out <path>] [--check] [--diff] [--backup] [--no-overwrite]
  ae registry submit --library-url <url> --library-id <id> --ae-use-files <csv|repeatable>
  ae registry bootstrap-local --ae-use-path <path>
  ae generate --library-id <id> --library-root <path> [--output-dir <path>] [--engine auto|codex|template] [--know <name>] [--dry-run] [--check] [--diff] [--backup] [--no-overwrite]
  ae skill install [--target <skills-dir>] [--name ae-cli] [--upgrade] [--template-path <path>]
  ae skill update [--target <skills-dir>] [--name ae-cli] [--template-path <path>]
  ae hub init [--path <dir>] [--project]
  ae hub status [--hub <path>]
  ae hub pull [--hub <path>] [--remote origin] [--library-id <id>] [--type <know|use|packages>]
  ae hub push [--hub <path>] [--remote origin]
  ae know build (--url <url> | --path <file>) --name <name> [--format auto|llms_txt|html|markdown|pdf] [--repo <git-url>] [--hub <path>]
  ae know list [--hub <path>]
  ae know show --name <name> [--hub <path>]
  ae know remove --name <name> [--hub <path>]
  ae know update --name <name> [--hub <path>]
  ae know diff --from <name> --to <name> [--hub <path>]
  ae know migrate [--dry-run] [--hub <path>]
  ae know plan --name <name> [--out <file.md>] [--hub <path>]
  ae know matrix init --name <name> --columns <csv> [--hub <path>]
  ae know matrix scaffold --name <name> --repo <path> [--out <file>] [--hub <path>]
  ae know matrix diff [--from-name ...] [--to-file ...] [--hub <path>]
  ae spec export --out <spec-dir> [--hub <path>] [--matrix <yaml>] [--matrix-baseline <yaml>] [--manifest <yaml>] [--locale <bcp47>]
  ae e2e sync-know --manifest <e2e_know_sources.yaml> [--hub <path>] [--base <dir>]
''';

  String _contextualHelp(final String commandPath) {
    switch (commandPath) {
      case 'definition':
        return '''
Usage: ae definition

Returns AE framework definition and capability matrix.

Example:
  ae definition
''';
      case 'package':
        return '''
Usage: ae package <resolve|validate> [options]

Subcommands:
  ae package resolve --help
  ae package validate --help
''';
      case 'package resolve':
        return '''
Usage: ae package resolve --package <id> --target linux --format json

Resolves Lythe-compatible package instructions from the current package repository.

Example:
  ae package resolve --package dev.xs.registry --target linux --format json
''';
      case 'package validate':
        return '''
Usage: ae package validate --instructions <file-or-json>

Examples:
  ae package validate --instructions ./instructions.json
  ae package validate --instructions '{"contract_version":"ae.v3.package.v1", ...}'
  cat ae.instructions.json | ae package validate --instructions -
''';
      case 'instructions':
        return '''
Usage: ae instructions --context <library|project> --action <bootstrap|install|uninstall|update|use> [--resources-path <path>] [--know <name>]

Options:
  --context         Required context type.
  --action          Required action type.
  --resources-path  Optional filesystem override for prompt documents.
  --know            Knowledge pack name for domain context.

Examples:
  ae instructions --context library --action bootstrap
  ae instructions --context project --action install --know flutter
''';
      case 'verify':
        return '''
Usage: ae verify --input <json-file|->

Examples:
  ae verify --input verify.json
  cat verify.json | ae verify --input -
''';
      case 'evaluate':
        return '''
Usage: ae evaluate --input <json-file|->

Examples:
  ae evaluate --input evaluate.json
  cat evaluate.json | ae evaluate --input -
''';
      case 'doctor':
        return '''
Usage: ae doctor [--target <skills-dir>]

Performs CLI preflight checks for:
- Codex availability (warning)
- Dart SDK availability (warning)
- Skill target writability (critical)
- Registry reachability (critical)

Examples:
  ae doctor
  ae doctor --target ~/.codex/skills
''';
      case 'registry':
        return '''
Usage: ae registry <get|submit|bootstrap-local> [options]

Subcommands:
  ae registry get --help
  ae registry submit --help
  ae registry bootstrap-local --help
''';
      case 'registry get':
        return '''
Usage: ae registry get --library-id <id> --action <install|uninstall|update|use> [--out <path>] [--check] [--diff] [--backup] [--no-overwrite]

Options:
  --out           Optional output destination.
  --check         Detect drift and skip writes.
  --diff          Include unified diff metadata for changes.
  --backup        Backup overwritten files to timestamped copies.
  --no-overwrite  Block overwrites of existing files.

Examples:
  ae registry get --library-id python_requests --action install
  ae registry get --library-id python_requests --action install --out ./ae_use
  ae registry get --library-id python_requests --action install --out ./ae_use --check --diff
''';
      case 'registry submit':
        return '''
Usage: ae registry submit --library-url <url> --library-id <id> --ae-use-files <csv|repeatable>

Example:
  ae registry submit --library-url https://github.com/example/lib --library-id dart_provider --ae-use-files ae_use/ae_install.md,ae_use/ae_uninstall.md,ae_use/ae_update.md,ae_use/ae_use.md
''';
      case 'registry bootstrap-local':
        return '''
Usage: ae registry bootstrap-local --ae-use-path <path>

Example:
  ae registry bootstrap-local --ae-use-path ./ae_use
''';
      case 'generate':
        return '''
Usage: ae generate --library-id <id> --library-root <path> [--output-dir <path>] [--engine auto|codex|template] [--know <name>] [--dry-run] [--check] [--diff] [--backup] [--no-overwrite]

Options:
  --know          Knowledge pack name for domain context.
  --check         Detect drift and skip writes.
  --diff          Include unified diff metadata for changes.
  --backup        Backup overwritten files to timestamped copies.
  --no-overwrite  Block overwrites of existing files.

Examples:
  ae generate --library-id dart_provider --library-root . --engine auto
  ae generate --library-id dart_provider --library-root . --engine template --know flutter
''';
      case 'skill':
        return '''
Usage: ae skill <install|update> [options]

Subcommands:
  ae skill install --help
  ae skill update --help
''';
      case 'skill install':
        return '''
Usage: ae skill install [--target <skills-dir>] [--name ae-cli] [--upgrade] [--template-path <path>]

Behavior:
- Missing skill: install.
- Same template content: success with no_op=true.
- Different installed content: fail with skill_upgrade_required unless --upgrade is provided.

Examples:
  ae skill install
  ae skill install --target ~/.codex/skills --name ae-cli
  ae skill install --upgrade
''';
      case 'skill update':
        return '''
Usage: ae skill update [--target <skills-dir>] [--name ae-cli] [--template-path <path>]

Compatibility wrapper for upgrade semantics.

Examples:
  ae skill update
  ae skill update --target ~/.codex/skills
''';
      case 'hub':
        return '''
Usage: ae hub <init|status|pull|push> [options]

Subcommands:
  ae hub init --help
  ae hub status --help
  ae hub pull --help
  ae hub push --help
''';
      case 'hub init':
        return '''
Usage: ae hub init [--path <dir>] [--project]

Initializes a new AE hub directory structure.

Examples:
  ae hub init
  ae hub init --project
  ae hub init --path /tmp/my-hub
''';
      case 'hub status':
        return '''
Usage: ae hub status [--hub <path>]

Shows hub status including artifact counts and config.

Examples:
  ae hub status
  ae hub status --hub ~/.ae_hub
''';
      case 'hub pull':
        return '''
Usage: ae hub pull [--hub <path>] [--remote origin] [--library-id <id>] [--type <know|use|packages>]

Pulls artifacts from a remote registry into the local hub.
If --library-id is given, fetches that library's ae_use files.
Without --library-id, shows remote config info.

Examples:
  ae hub pull
  ae hub pull --library-id dart_provider
  ae hub pull --remote upstream --library-id python_requests
''';
      case 'hub push':
        return '''
Usage: ae hub push [--hub <path>] [--remote origin]

Generates instructions for pushing local hub artifacts to a remote registry.

Examples:
  ae hub push
  ae hub push --remote upstream
''';
      case 'know':
        return '''
Usage: ae know <build|list|show|remove|update|diff|migrate|plan|matrix> [options]

Subcommands:
  ae know build --help
  ae know list --help
  ae know show --help
  ae know remove --help
  ae know update --help
  ae know diff --help
  ae know migrate --help
  ae know plan --help
  ae know matrix init --help
  ae know matrix scaffold --help
  ae know matrix diff --help
''';
      case 'know build':
        return '''
Usage: ae know build (--url <url> | --path <file>) --name <name> [--format auto|llms_txt|html|markdown|pdf] [--repo <git-url>] [--on-conflict reuse|update|fail|new_version] [--hub <path>]

Fetches content from a URL, local file path, or git repository and builds a knowledge pack.
Use --format html to convert HTML pages via Jina Reader.
Use --on-conflict reuse (default) to attach name as alias when source already exists; update to refresh; fail to error; new_version to add another version.

Examples:
  ae know build --url https://docs.flutter.dev/llms.txt --name flutter
  ae know build --path ./README.md --name local_readme
  ae know build --url https://example.com/docs --name my_docs --format html
  ae know build --url https://example.com/api.md --name my_api --hub ~/.ae_hub
  ae know build --repo https://github.com/anthropics/anthropic-sdk-python --name anthropic_sdk
  ae know build --url https://example.com/doc.pdf --name doc_a --on-conflict reuse
''';
      case 'know list':
        return '''
Usage: ae know list [--hub <path>]

Lists all knowledge packs in the hub.

Examples:
  ae know list
  ae know list --hub ~/.ae_hub
''';
      case 'know show':
        return '''
Usage: ae know show --name <name> [--hub <path>]

Shows details and content of a knowledge pack.

Examples:
  ae know show --name flutter
  ae know show --name my_api --hub ~/.ae_hub
''';
      case 'know remove':
        return '''
Usage: ae know remove --name <name> [--hub <path>]

Removes a knowledge pack from the hub.

Examples:
  ae know remove --name flutter
  ae know remove --name my_api --hub ~/.ae_hub
''';
      case 'know update':
        return '''
Usage: ae know update --name <name> [--hub <path>]

Re-fetches and rebuilds a knowledge pack from its original source.

Examples:
  ae know update --name flutter
  ae know update --name my_api --hub ~/.ae_hub
''';
      case 'know diff':
        return '''
Usage: ae know diff --from <name> --to <name> [--hub <path>]

Compares two knowledge packs section by section.

Examples:
  ae know diff --from flutter_v1 --to flutter_v2
  ae know diff --from old_api --to new_api --hub ~/.ae_hub
''';
      case 'know migrate':
        return '''
Usage: ae know migrate [--dry-run] [--hub <path>]

Migrates legacy name-keyed know packs to canonical layout (source-id + aliases).
Use --dry-run to report what would be done without writing.

Examples:
  ae know migrate --dry-run
  ae know migrate --hub ~/.ae_hub
''';
      case 'know plan':
        return '''
Usage: ae know plan --name <name> [--out <file.md>] [--locale <bcp47>] [--language <bcp47>] [--hub <path>]

Exports a single markdown implementation plan: index.md + feature matrix + normative pointer.
With --out, writes the markdown to a file; JSON envelope is still printed to stdout.
Optional --locale/--language adds YAML front matter for inner agents.

Examples:
  ae know plan --name gltf_2
  ae know plan --name gltf_2 --out ./implementation_plan.md
  ae know plan --name gltf_2 --locale en
''';
      case 'spec':
        return '''
Usage: ae spec export --out <dir> [options]

Exports spec_export.v2 (definition.yaml/md, know list, matrix copy, per-pack know show + plan, spec_index.json).

Subcommands:
  ae spec export --help
''';
      case 'spec export':
        return '''
Usage: ae spec export --out <spec-dir> [--hub <path>] [--matrix <feature_matrix.yaml>] [--matrix-baseline <prior.yaml>] [--manifest <e2e_know_sources.yaml>] [--locale <bcp47>] [--language <bcp47>]

Writes spec_export.v2: definition.yaml, definition.md, small definition.json pointer, know_list, per-pack know show (portable paths) + plan, feature_matrix copy, optional matrix_diff.json, spec_index.json.

Examples:
  ae spec export --out experiments/ae_rust_contract/spec --hub .ae_hub
  ae spec export --out spec --matrix-baseline docs/matrix_baseline.yaml
''';
      case 'e2e':
        return '''
Usage: ae e2e sync-know --manifest <path> [options]

E2E helper: builds know packs from a declarative YAML manifest.

Subcommands:
  ae e2e sync-know --help
''';
      case 'e2e sync-know':
        return '''
Usage: ae e2e sync-know --manifest <e2e_know_sources.yaml> [--hub <path>] [--base <dir>]

Paths in the manifest are resolved relative to --base (default: current directory).
Rows with network: true require AE_E2E_NETWORK=1.

Examples:
  ae e2e sync-know --manifest docs/e2e_know_sources.yaml
''';
      case 'know matrix init':
        return '''
Usage: ae know matrix init --name <name> --columns <csv> [--title <t>] [--normative-kind url|path] [--normative-ref <ref>] [--hub <path>]

Creates matrix.yaml + matrix.md in the pack content root and records artifacts in meta.yaml.

Examples:
  ae know matrix init --name gltf_2 --columns import,bundle,runtime,proof
''';
      case 'know matrix scaffold':
        return '''
Usage: ae know matrix scaffold --name <name> --repo <path> [--out <file.yaml>] [--hub <path>]

Copies hub matrix.yaml into a repo (default: <repo>/docs/feature_matrix.yaml).

Examples:
  ae know matrix scaffold --name gltf_2 --repo ~/my/app
''';
      case 'know matrix diff':
        return '''
Usage: ae know matrix diff (--from-name <name> --to-name <name)|(--from-file <a.yaml> --to-file <b.yaml>) [--hub <path>]

Deterministic structural diff by feature id (YAML source of truth).

Examples:
  ae know matrix diff --from-name gltf_v1 --to-name gltf_v2
  ae know matrix diff --from-file ./hub.yaml --to-file ./repo/docs/feature_matrix.yaml
''';
      case 'init':
        return '''
Usage: ae init [--root <dir>] [--strict]

Scans the current project for known language manifests and ingests each
sub-package as a local artifact. Requires a .ae_hub directory at root.

Options:
  --root    Project root to scan (default: cwd).
  --strict  Exit non-zero if any sub-directory has no matching extractor.

Examples:
  ae init
  ae init --root . --strict
''';
      case 'status':
        return '''
Usage: ae status [--root <dir>] [--pack <name>] [--tier <1-4>]

Project-wide tier-classified gap report.

Tiers:
  1 — invariant violations (canonical asserts; no test verifies)
  2 — upstream blockers (downstream-required features missing/partial)
  3 — partial referenced features
  4 — unreferenced canonicals

Examples:
  ae status
  ae status --pack my_pkg --tier 1
''';
      case 'sync':
        return '''
Usage: ae sync [--root <dir>] [--pack <name>]

Re-scan source files for artifact packs and report drift (code + intent).

Options:
  --pack  Sync only the named pack (default: all packs in hub).

Examples:
  ae sync
  ae sync --pack my_pkg
''';
      case 'canonical':
        return '''
Usage: ae canonical <subcommand> [options]

Manage canonical concept packs (specs + matrices) stored under
<hub>/canonical/<concept>/.

Subcommands:
  init      Scaffold a new canonical pack.
  list      List concept ids in the hub.
  snapshot  Freeze the live canonical into v<n>/ (bumps version).
  diff      Structural diff between two versions of a concept.
  import    Copy an external canonical directory into this hub.

Run `ae canonical <subcommand> --help` for details.
''';
      case 'canonical init':
        return '''
Usage: ae canonical init --concept <slug> --title <text> [--root <dir>]

Scaffold a new canonical pack with empty matrix and minimal meta.

Examples:
  ae canonical init --concept ecs --title "Entity Component System"
''';
      case 'canonical list':
        return '''
Usage: ae canonical list [--root <dir>]

List all canonical concept ids in the hub.
''';
      case 'canonical snapshot':
        return '''
Usage: ae canonical snapshot --concept <slug> [--root <dir>]

Freeze the live canonical into v<n>/ and bump the live version.

Examples:
  ae canonical snapshot --concept ecs
''';
      case 'canonical diff':
        return '''
Usage: ae canonical diff --concept <slug> [--from <vN>] [--to <vM|current>] [--root <dir>]

Structural diff between two versions of the same concept. Either side may be
omitted (compares against live).

Examples:
  ae canonical diff --concept ecs --from v1 --to current
  ae canonical diff --concept ecs --from v1 --to v2
''';
      case 'canonical import':
        return '''
Usage: ae canonical import --from <dir> --as <concept-id> [--root <dir>]

Copy a canonical directory (meta.yaml + index.md + matrix.yaml) from another
hub into this hub under the given concept id.

Examples:
  ae canonical import --from ../other/.ae_hub/canonical/ecs --as ecs
''';
      default:
        return 'No contextual help found for "$commandPath"';
    }
  }

  String _commandPath(final ArgResults root) {
    final parts = <String>[];
    var current = root;
    while (current.command != null) {
      current = current.command!;
      if (current.name != null) {
        parts.add(current.name!);
      }
    }
    return parts.join(' ');
  }

  Future<AeResult<Map<String, dynamic>>> _dispatch(
    final ArgResults root,
  ) async {
    final command = root.command;
    if (command == null) {
      return AeResult.fail(code: 'invalid_command', message: 'Missing command');
    }

    switch (command.name) {
      case 'definition':
        return _handleDefinition();
      case 'instructions':
        return _handleInstructions(command);
      case 'package':
        return _handlePackage(command);
      case 'verify':
        return _handleVerify(command);
      case 'evaluate':
        return _handleEvaluate(command);
      case 'doctor':
        return _handleDoctor(command);
      case 'registry':
        return _handleRegistry(command);
      case 'generate':
        return _handleGenerate(command);
      case 'skill':
        return _handleSkill(command);
      case 'hub':
        return _handleHub(command);
      case 'know':
        return _handleKnow(command);
      case 'spec':
        return _handleSpec(command);
      case 'e2e':
        return _handleE2e(command);
      case 'init':
        return _handleInit(command);
      case 'status':
        return _handleStatus(command);
      case 'sync':
        return _handleSync(command);
      case 'canonical':
        return _handleCanonical(command);
      default:
        return AeResult.fail(
          code: 'invalid_command',
          message: 'Unknown command: ${command.name}',
        );
    }
  }

  AeResult<Map<String, dynamic>> _handleDefinition() {
    final result = const DefaultAeDefinitionService().getDefinition();
    if (!result.success || result.data == null) {
      return AeResult.fail(
        code: result.error?.code ?? 'definition_failed',
        message: result.error?.message ?? 'Failed to get definition',
        details: result.error?.details,
      );
    }

    return AeResult.ok(
      result.data!.toJson(),
      warnings: result.warnings,
      meta: result.meta,
    );
  }

  Future<AeResult<Map<String, dynamic>>> _handleInstructions(
    final ArgResults command,
  ) async {
    final contextRaw = command['context']?.toString();
    final actionRaw = command['action']?.toString();
    if (contextRaw == null || contextRaw.isEmpty) {
      return AeResult.fail(
        code: 'validation_error',
        message: 'Missing required argument: --context',
      );
    }
    if (actionRaw == null || actionRaw.isEmpty) {
      return AeResult.fail(
        code: 'validation_error',
        message: 'Missing required argument: --action',
      );
    }

    final AeContext context;
    final AeAction action;
    try {
      context = AeContext.fromString(contextRaw);
      action = AeAction.fromString(actionRaw);
    } catch (error) {
      return AeResult.fail(code: 'validation_error', message: error.toString());
    }

    final resourcesPath = command['resources-path']?.toString();
    final documentStore = resourcesPath == null || resourcesPath.isEmpty
        ? EmbeddedDocumentStore(EmbeddedCliResources.prompts)
        : FileDocumentStore(resourcesPath);

    final knowName = command['know']?.toString();
    String? knowContext;
    if (knowName != null && knowName.isNotEmpty) {
      final resolver = FileHubResolver();
      final hubPath = await resolver.resolveHub();
      if (hubPath != null) {
        final store = FileKnowledgeStore(
          path.join(hubPath, AeCoreConfig.hubKnowDir),
        );
        final pack = await store.load(knowName);
        knowContext = _knowPackDomainContext(pack);
      }
      if (knowContext == null) {
        return AeResult.fail(
          code: 'know_not_found',
          message: 'Knowledge pack "$knowName" not found in hub',
        );
      }
    }

    final service = DefaultAeInstructionService(documentStore);
    final result = await service.getInstructions(
      GetInstructionsInput(
        context: context,
        action: action,
        knowContext: knowContext,
      ),
    );

    if (!result.success || result.data == null) {
      return AeResult.fail(
        code: result.error?.code ?? 'instructions_failed',
        message: result.error?.message ?? 'Failed to get instructions',
        details: result.error?.details,
      );
    }

    return AeResult.ok(
      result.data!.toJson(),
      warnings: result.warnings,
      meta: {
        ...result.meta,
        if (resourcesPath == null || resourcesPath.isEmpty)
          'resources_source': 'embedded',
        if (resourcesPath != null && resourcesPath.isNotEmpty)
          'resources_path': resourcesPath,
      },
    );
  }

  Future<AeResult<Map<String, dynamic>>> _handlePackage(
    final ArgResults command,
  ) async {
    final subcommand = command.command;
    if (subcommand == null) {
      return AeResult.fail(
        code: 'validation_error',
        message: 'Missing package subcommand',
      );
    }
    switch (subcommand.name) {
      case 'resolve':
        return _handlePackageResolve(subcommand);
      case 'validate':
        return _handlePackageValidate(subcommand);
      default:
        return AeResult.fail(
          code: 'invalid_command',
          message: 'Unknown package subcommand: ${subcommand.name}',
        );
    }
  }

  Future<AeResult<Map<String, dynamic>>> _handlePackageResolve(
    final ArgResults command,
  ) async {
    final packageId = command['package']?.toString().trim() ?? '';
    final target = command['target']?.toString().trim() ?? 'linux';
    final format = command['format']?.toString().trim() ?? 'json';
    if (packageId.isEmpty) {
      return AeResult.fail(
        code: 'validation_error',
        message: 'Missing required argument: --package',
      );
    }
    if (target != 'linux') {
      return AeResult.fail(
        code: 'validation_error',
        message: 'Unsupported target "$target"; only linux is supported',
      );
    }
    if (format != 'json') {
      return AeResult.fail(
        code: 'validation_error',
        message: 'Unsupported format "$format"; only json is supported',
      );
    }

    final rootRaw = command['package-root']?.toString().trim() ?? '';
    final packageRoot =
        rootRaw.isNotEmpty ? Directory(rootRaw) : Directory.current;
    final packageVersion =
        await _detectPackageVersion(packageRoot) ?? '1.0.0';
    final slug = packageId
        .replaceAll(RegExp(r'[.:/]'), '-')
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    final instructions = <String, dynamic>{
      'contract_version': 'ae.v3.package.v1',
      'package': <String, dynamic>{'id': packageId, 'version': packageVersion},
      'profile': <String, dynamic>{'id': 'direct', 'major': 1},
      'build': <String, dynamic>{
        'steps': <Map<String, dynamic>>[
          <String, dynamic>{
            'type': 'copy',
            'config': <String, dynamic>{'src': '.'},
          },
        ],
      },
      'deploy': <String, dynamic>{
        'plugins': <Map<String, dynamic>>[
          <String, dynamic>{
            'name': 'systemd_service',
            'version': 1,
            'config': <String, dynamic>{
              'unit_name': 'lythe-$slug.service',
              'exec_start': 'payload/run-gateway.sh',
              'working_dir': 'payload',
              'environment_file': 'payload/gateway.env',
              'port': 8080,
            },
          },
        ],
        'inputs': <String, dynamic>{'required': const <String>[]},
      },
      'domain': <String, dynamic>{
        'capabilities': <String, dynamic>{'wildcard_support_mode': 'none'},
      },
      'safety': <String, dynamic>{
        'constraints': <String, dynamic>{
          'allowed_executors': const <String>['lythe'],
          'forbidden_actions': const <String>[],
        },
      },
    };
    final validationError = _validatePackageInstructions(instructions);
    if (validationError != null) {
      return AeResult.fail(code: 'validation_error', message: validationError);
    }

    return AeResult.ok(<String, dynamic>{
      'instructions': instructions,
      'package': packageId,
      'target': target,
      'format': format,
    });
  }

  Future<AeResult<Map<String, dynamic>>> _handlePackageValidate(
    final ArgResults command,
  ) async {
    final source = command['instructions']?.toString().trim() ?? '';
    if (source.isEmpty) {
      return AeResult.fail(
        code: 'validation_error',
        message: 'Missing required argument: --instructions',
      );
    }

    late final Map<String, dynamic> instructions;
    try {
      instructions = await _readInstructionsPayload(source);
    } on FormatException catch (error) {
      return AeResult.fail(code: 'validation_error', message: error.message);
    } on FileSystemException catch (error) {
      return AeResult.fail(
        code: 'validation_error',
        message: 'Failed to read instructions: $error',
      );
    }

    final validationError = _validatePackageInstructions(instructions);
    if (validationError != null) {
      return AeResult.fail(code: 'validation_error', message: validationError);
    }

    return AeResult.ok(<String, dynamic>{
      'validated': true,
      'contract_version': instructions['contract_version'],
    });
  }

  Future<AeResult<Map<String, dynamic>>> _handleVerify(
    final ArgResults command,
  ) async {
    final inputPath = command['input'].toString();
    final payload = await _readInputJson(inputPath);

    final contextRaw = payload['context_type']?.toString();
    final actionRaw = payload['action']?.toString();
    if (contextRaw == null || actionRaw == null) {
      return AeResult.fail(
        code: 'validation_error',
        message: 'context_type and action are required',
      );
    }

    final AeContext context;
    final AeAction action;
    try {
      context = AeContext.fromString(contextRaw);
      action = AeAction.fromString(actionRaw);
    } catch (error) {
      return AeResult.fail(code: 'validation_error', message: error.toString());
    }

    final filesRaw = _parseList(payload['files_modified']);
    final files = filesRaw
        .whereType<Map>()
        .map(
          (final entry) => AeModifiedFile.fromJson(
            entry.map(
              (final key, final value) => MapEntry(key.toString(), value),
            ),
          ),
        )
        .toList(growable: false);

    final checklistRaw = _parseMap(payload['checklist_completed']);
    final checklist = <String, bool>{
      for (final entry in checklistRaw.entries)
        entry.key.toString(): _parseBool(entry.value),
    };

    final validation = const DefaultAeValidationService().verify(
      VerifyInput(
        context: context,
        action: action,
        filesModified: files,
        checklistCompleted: checklist,
      ),
    );

    if (!validation.success || validation.data == null) {
      return AeResult.fail(
        code: validation.error?.code ?? 'verify_failed',
        message: validation.error?.message ?? 'Verification failed',
        details: validation.error?.details,
      );
    }

    final output = validation.data!;
    return AeResult.ok(
      {
        'context_type': context.value,
        'action': action.value,
        'verification': output.toJson(),
        'overall_status': output.overallPass ? 'PASS' : 'FAIL',
        'message': output.overallPass
            ? 'Implementation verification passed.'
            : 'Implementation verification failed. Review missing items.',
      },
      warnings: validation.warnings,
      meta: validation.meta,
    );
  }

  Future<AeResult<Map<String, dynamic>>> _handleEvaluate(
    final ArgResults command,
  ) async {
    final inputPath = command['input'].toString();
    final payload = await _readInputJson(inputPath);

    final contextRaw = payload['context_type']?.toString();
    final actionRaw = payload['action']?.toString();
    if (contextRaw == null || actionRaw == null) {
      return AeResult.fail(
        code: 'validation_error',
        message: 'context_type and action are required',
      );
    }

    final AeContext context;
    final AeAction action;
    try {
      context = AeContext.fromString(contextRaw);
      action = AeAction.fromString(actionRaw);
    } catch (error) {
      return AeResult.fail(code: 'validation_error', message: error.toString());
    }

    final filesRaw = _parseList(payload['files_created']);
    final files = filesRaw
        .whereType<Map>()
        .map(
          (final entry) => AeCreatedFile.fromJson(
            entry.map(
              (final key, final value) => MapEntry(key.toString(), value),
            ),
          ),
        )
        .toList(growable: false);

    final sections = _parseList(
      payload['sections_present'],
    ).map((final entry) => entry.toString()).toList(growable: false);

    final validation = const DefaultAeValidationService().evaluate(
      EvaluateInput(
        context: context,
        action: action,
        filesCreated: files,
        sectionsPresent: sections,
        validationStepsExists: _parseBool(payload['validation_steps_exists']),
        integrationPointsDefined: _parseBool(
          payload['integration_points_defined'],
        ),
        reversibilityIncluded: _parseBool(payload['reversibility_included']),
        hasMetaRules: _parseBool(payload['has_meta_rules']),
      ),
    );

    if (!validation.success || validation.data == null) {
      return AeResult.fail(
        code: validation.error?.code ?? 'evaluate_failed',
        message: validation.error?.message ?? 'Evaluation failed',
        details: validation.error?.details,
      );
    }

    final output = validation.data!;
    return AeResult.ok(
      {
        'context_type': context.value,
        'action': action.value,
        'evaluation': output.toJson(),
        'overall_status': output.overallPass ? 'PASS' : 'FAIL',
        'message': output.overallPass
            ? 'Implementation meets AE compliance requirements.'
            : 'Implementation has issues that need to be addressed.',
      },
      warnings: validation.warnings,
      meta: validation.meta,
    );
  }

  Future<AeResult<Map<String, dynamic>>> _handleDoctor(
    final ArgResults command,
  ) async {
    final target = command['target']?.toString() ?? _defaultSkillsBaseDir();

    final doctor = AeDoctor(
      codexBinary: codexBinary ?? 'codex',
      environment: environment,
      registryProbeUrl: registryProbeUrl,
    );

    final output = await doctor.run(skillTarget: target);

    return AeResult.ok(output.toJson(), meta: const {'operation': 'doctor'});
  }

  Future<AeResult<Map<String, dynamic>>> _handleRegistry(
    final ArgResults command,
  ) async {
    final sub = command.command;
    if (sub == null) {
      return AeResult.fail(
        code: 'validation_error',
        message: 'Registry subcommand is required',
      );
    }

    final client = registryClient ?? GitHubRawRegistryClient();
    final ownsClient = registryClient == null;
    final service = DefaultAeRegistryService(client);
    void closeClient() {
      if (!ownsClient) {
        return;
      }
      if (client is GitHubRawRegistryClient) {
        client.close();
      }
    }

    switch (sub.name) {
      case 'get':
        final libraryId = sub['library-id']?.toString() ?? '';
        final actionRaw = sub['action']?.toString() ?? '';
        if (actionRaw.isEmpty) {
          closeClient();
          return AeResult.fail(
            code: 'validation_error',
            message: 'Missing required argument: --action',
          );
        }

        final AeAction action;
        try {
          action = AeAction.fromString(actionRaw);
        } catch (error) {
          closeClient();
          return AeResult.fail(
            code: 'validation_error',
            message: error.toString(),
          );
        }

        final result = await service.getFromRegistry(
          RegistryGetInput(libraryId: libraryId, action: action),
        );

        if (!result.success || result.data == null) {
          closeClient();
          return AeResult.fail(
            code: result.error?.code ?? 'registry_get_failed',
            message: result.error?.message ?? 'Registry get failed',
            details: result.error?.details,
            warnings: result.warnings,
            meta: result.meta,
          );
        }

        final outPathRaw = sub['out']?.toString();
        if (outPathRaw == null || outPathRaw.isEmpty) {
          closeClient();
          return AeResult.ok(
            result.data!.toJson(),
            warnings: result.warnings,
            meta: result.meta,
          );
        }

        final String resolvedOut;
        try {
          resolvedOut = _resolveRegistryOutPath(outPathRaw, action);
        } catch (error) {
          closeClient();
          return AeResult.fail(
            code: 'validation_error',
            message: error.toString(),
          );
        }
        final writeOptions = _safeWriteOptions(sub);
        final writeResult = await const SafeFileWriter().writeAll(
          requests: [
            FileWriteRequest(path: resolvedOut, content: result.data!.content),
          ],
          options: writeOptions,
        );

        closeClient();

        if (writeOptions.check && writeResult.hasChanges) {
          return AeResult.fail(
            code: 'check_mode_changes_detected',
            message: 'Changes detected in --check mode',
            details: writeResult.toJson(),
            warnings: result.warnings,
            meta: result.meta,
          );
        }

        if (writeResult.hasBlocked) {
          return AeResult.fail(
            code: 'write_conflict_no_overwrite',
            message: 'One or more writes were blocked by --no-overwrite',
            details: writeResult.toJson(),
            warnings: result.warnings,
            meta: result.meta,
          );
        }

        return AeResult.ok(
          {
            ...result.data!.toJson(),
            'out_path': resolvedOut,
            'write': writeResult.toJson(),
            'no_op': !writeResult.hasChanges,
          },
          warnings: result.warnings,
          meta: result.meta,
        );

      case 'submit':
        final libraryUrl = sub['library-url']?.toString() ?? '';
        final libraryId = sub['library-id']?.toString() ?? '';
        final files = (sub['ae-use-files'] as List)
            .map((final value) => value.toString())
            .where((final value) => value.isNotEmpty)
            .toList(growable: false);

        final result = await service.submitToRegistry(
          RegistrySubmitInput(
            libraryUrl: libraryUrl,
            libraryId: libraryId,
            aeUseFiles: files,
          ),
        );
        closeClient();

        if (!result.success || result.data == null) {
          return AeResult.fail(
            code: result.error?.code ?? 'registry_submit_failed',
            message: result.error?.message ?? 'Registry submit failed',
            details: result.error?.details,
            warnings: result.warnings,
            meta: result.meta,
          );
        }

        return AeResult.ok(
          result.data!.toJson(),
          warnings: result.warnings,
          meta: result.meta,
        );

      case 'bootstrap-local':
        final aeUsePath = sub['ae-use-path']?.toString() ?? '';
        final result = service.bootstrapLocalRegistry(
          RegistryBootstrapLocalInput(aeUsePath: aeUsePath),
        );
        closeClient();

        if (!result.success || result.data == null) {
          return AeResult.fail(
            code: result.error?.code ?? 'registry_bootstrap_failed',
            message: result.error?.message ?? 'Registry bootstrap failed',
            details: result.error?.details,
            warnings: result.warnings,
            meta: result.meta,
          );
        }

        return AeResult.ok(
          result.data!.toJson(),
          warnings: result.warnings,
          meta: result.meta,
        );
      default:
        closeClient();
        return AeResult.fail(
          code: 'invalid_command',
          message: 'Unknown registry subcommand: ${sub.name}',
        );
    }
  }

  String _resolveRegistryOutPath(final String out, final AeAction action) {
    final normalized = path.normalize(out);
    final entityType = FileSystemEntity.typeSync(normalized);

    final looksDirectory = normalized.endsWith(path.separator) ||
        path.extension(path.basename(normalized)).isEmpty;

    if (entityType == FileSystemEntityType.directory ||
        (entityType == FileSystemEntityType.notFound && looksDirectory)) {
      return path.join(normalized, action.fileName);
    }

    if (entityType == FileSystemEntityType.file && looksDirectory) {
      throw ArgumentError(
        'Path "$normalized" looks like a directory but already exists as a file',
      );
    }

    return normalized;
  }

  Future<AeResult<Map<String, dynamic>>> _handleGenerate(
    final ArgResults command,
  ) async {
    final libraryId = command['library-id']?.toString() ?? '';
    final libraryRoot = command['library-root']?.toString() ?? '';
    if (libraryId.isEmpty || libraryRoot.isEmpty) {
      return AeResult.fail(
        code: 'validation_error',
        message: '--library-id and --library-root are required',
      );
    }

    final engineModeRaw = command['engine']?.toString() ?? 'auto';
    final outputDir =
        command['output-dir']?.toString() ?? path.join(libraryRoot, 'ae_use');

    final AeGenerationEngineMode engineMode;
    try {
      engineMode = AeGenerationEngineMode.fromString(engineModeRaw);
    } catch (error) {
      return AeResult.fail(code: 'validation_error', message: error.toString());
    }

    final dryRun = command['dry-run'] == true;
    final writeOptions = _safeWriteOptions(command);

    final knowName = command['know']?.toString();
    String? knowContext;
    if (knowName != null && knowName.isNotEmpty) {
      final resolver = FileHubResolver();
      final hubPath = await resolver.resolveHub();
      if (hubPath != null) {
        final store = FileKnowledgeStore(
          path.join(hubPath, AeCoreConfig.hubKnowDir),
        );
        final pack = await store.load(knowName);
        knowContext = _knowPackDomainContext(pack);
      }
      if (knowContext == null) {
        return AeResult.fail(
          code: 'know_not_found',
          message: 'Knowledge pack "$knowName" not found in hub',
        );
      }
    }

    final codexClient = inferenceClient ??
        CodexExecInferenceClient(
          binaryName: codexBinary ?? 'codex',
          environment: environment,
        );

    final generationService = DefaultAeGenerationService(
      templateEngine: const TemplateGenerationEngine(),
      codexEngine: InferenceGenerationEngine(client: codexClient),
    );

    final generationResult = await generationService.generate(
      GenerateInput(
        libraryId: libraryId,
        libraryRoot: libraryRoot,
        outputDir: outputDir,
        engineMode: engineMode,
        dryRun: dryRun,
        knowContext: knowContext,
      ),
    );

    if (!generationResult.success || generationResult.data == null) {
      return AeResult.fail(
        code: generationResult.error?.code ?? 'generation_failed',
        message: generationResult.error?.message ?? 'Generation failed',
        details: generationResult.error?.details,
        warnings: generationResult.warnings,
        meta: generationResult.meta,
      );
    }

    final output = generationResult.data!;
    final unresolvedWarnings = output.files
        .where((final file) => file.content.contains('TODO:'))
        .map(
          (final file) =>
              'Unresolved placeholder markers found in ${file.path}',
        )
        .toList(growable: false);

    if (dryRun && !writeOptions.check) {
      return AeResult.ok(
        {
          ...output.toJson(),
          'output_dir': outputDir,
          'dry_run': true,
          'write': {
            'files': const [],
            'has_changes': false,
            'has_blocked': false,
            'wrote_any': false,
          },
          'no_op': false,
        },
        warnings: [...generationResult.warnings, ...unresolvedWarnings],
        meta: generationResult.meta,
      );
    }

    final requests = output.files
        .map(
          (final file) => FileWriteRequest(
            path: path.join(outputDir, file.path),
            content: file.content,
          ),
        )
        .toList(growable: false);

    final effectiveOptions = dryRun
        ? SafeWriteOptions(
            check: true,
            diff: writeOptions.diff,
            backup: false,
            noOverwrite: writeOptions.noOverwrite,
          )
        : writeOptions;

    final writeResult = await const SafeFileWriter().writeAll(
      requests: requests,
      options: effectiveOptions,
    );

    if (writeOptions.check && writeResult.hasChanges) {
      return AeResult.fail(
        code: 'check_mode_changes_detected',
        message: 'Changes detected in --check mode',
        details: writeResult.toJson(),
        warnings: [...generationResult.warnings, ...unresolvedWarnings],
        meta: generationResult.meta,
      );
    }

    if (writeResult.hasBlocked) {
      return AeResult.fail(
        code: 'write_conflict_no_overwrite',
        message: 'One or more writes were blocked by --no-overwrite',
        details: writeResult.toJson(),
        warnings: [...generationResult.warnings, ...unresolvedWarnings],
        meta: generationResult.meta,
      );
    }

    return AeResult.ok(
      {
        ...output.toJson(),
        'output_dir': outputDir,
        'dry_run': dryRun,
        'write': writeResult.toJson(),
        'no_op': !writeResult.hasChanges,
      },
      warnings: [...generationResult.warnings, ...unresolvedWarnings],
      meta: generationResult.meta,
    );
  }

  Future<AeResult<Map<String, dynamic>>> _handleSkill(
    final ArgResults command,
  ) async {
    final sub = command.command;
    if (sub == null) {
      return AeResult.fail(
        code: 'validation_error',
        message: 'Skill subcommand is required',
      );
    }

    switch (sub.name) {
      case 'install':
        return _handleSkillInstall(sub);
      case 'update':
        return _handleSkillUpdate(sub);
      default:
        return AeResult.fail(
          code: 'invalid_command',
          message: 'Unknown skill subcommand: ${sub.name}',
        );
    }
  }

  Future<AeResult<Map<String, dynamic>>> _handleSkillInstall(
    final ArgResults command,
  ) async {
    return _installOrUpgradeSkill(
      name: command['name'].toString(),
      targetBase: command['target']?.toString() ?? _defaultSkillsBaseDir(),
      upgrade: command['upgrade'] == true,
      templatePath: command['template-path']?.toString(),
      operation: 'skill_install',
      requireExisting: false,
    );
  }

  Future<AeResult<Map<String, dynamic>>> _handleSkillUpdate(
    final ArgResults command,
  ) async {
    return _installOrUpgradeSkill(
      name: command['name'].toString(),
      targetBase: command['target']?.toString() ?? _defaultSkillsBaseDir(),
      upgrade: true,
      templatePath: command['template-path']?.toString(),
      operation: 'skill_update',
      requireExisting: true,
    );
  }

  Future<AeResult<Map<String, dynamic>>> _handleHub(
    final ArgResults command,
  ) async {
    final sub = command.command;
    if (sub == null) {
      return AeResult.fail(
        code: 'validation_error',
        message: 'Hub subcommand is required',
      );
    }

    final resolver = FileHubResolver();
    final client = registryClient ?? GitHubRawRegistryClient();
    final service = DefaultAeHubService(resolver, registryClient: client);

    switch (sub.name) {
      case 'init':
        final pathArg = sub['path']?.toString();
        final project = sub['project'] == true;
        final result = await service.init(
          HubInitInput(path: pathArg, project: project),
        );
        if (!result.success || result.data == null) {
          return AeResult.fail(
            code: result.error?.code ?? 'hub_init_failed',
            message: result.error?.message ?? 'Hub init failed',
            details: result.error?.details,
          );
        }
        return AeResult.ok(result.data!.toJson());

      case 'status':
        final hubArg = sub['hub']?.toString();
        final result = await service.status(HubStatusInput(hubPath: hubArg));
        if (!result.success || result.data == null) {
          return AeResult.fail(
            code: result.error?.code ?? 'hub_status_failed',
            message: result.error?.message ?? 'Hub status failed',
            details: result.error?.details,
          );
        }
        return AeResult.ok(result.data!.toJson());

      case 'pull':
        final hubArg = sub['hub']?.toString();
        final remote = sub['remote']?.toString() ?? 'origin';
        final libraryId = sub['library-id']?.toString();
        final type = sub['type']?.toString();
        final result = await service.pull(
          HubPullInput(
            hubPath: hubArg,
            remote: remote,
            libraryId: libraryId,
            type: type,
          ),
        );
        if (!result.success || result.data == null) {
          return AeResult.fail(
            code: result.error?.code ?? 'hub_pull_failed',
            message: result.error?.message ?? 'Hub pull failed',
            details: result.error?.details,
          );
        }
        return AeResult.ok(result.data!.toJson(), warnings: result.warnings);

      case 'push':
        final hubArg = sub['hub']?.toString();
        final remote = sub['remote']?.toString() ?? 'origin';
        final result = await service.push(
          HubPushInput(hubPath: hubArg, remote: remote),
        );
        if (!result.success || result.data == null) {
          return AeResult.fail(
            code: result.error?.code ?? 'hub_push_failed',
            message: result.error?.message ?? 'Hub push failed',
            details: result.error?.details,
          );
        }
        return AeResult.ok(result.data!.toJson());

      default:
        return AeResult.fail(
          code: 'invalid_command',
          message: 'Unknown hub subcommand: ${sub.name}',
        );
    }
  }

  String? _hubOptionFromKnowCommand(final ArgResults knowCommand) {
    for (ArgResults? c = knowCommand; c != null; c = c.command) {
      if (!c.options.contains('hub')) continue;
      final h = c['hub']?.toString();
      if (h != null && h.isNotEmpty) return h;
    }
    return null;
  }

  Future<AeResult<Map<String, dynamic>>> _handleInit(
    final ArgResults command,
  ) async {
    final root = command['root']?.toString() ?? Directory.current.path;
    final strict = command['strict'] as bool? ?? false;
    final resolver = FileHubResolver();
    final hubPath = await resolver.resolveHub(projectRoot: root);
    if (hubPath == null) {
      return AeResult.fail(
        code: 'no_hub',
        message:
            'No .ae_hub found at $root. Create one with: ae hub init --project',
      );
    }
    final artStore = FileArtifactStore(hubPath);
    final canStore = FileCanonicalStore(hubPath);
    final registry = HeuristicExtractorRegistry(const [
      DartHeuristicExtractor(),
      RustHeuristicExtractor(),
      KotlinSwiftHeuristicExtractor(),
    ]);
    final svc = DefaultArtifactService(
      artifactStore: artStore,
      canonicalStore: canStore,
      extractorRegistry: registry,
    );

    final ingested = <String>[];
    final skipped = <String>[];
    // Scan immediate children of root for handle-able manifests; recurse one
    // level if a child is a workspace-style "umbrella" directory.
    final rootDir = Directory(root);
    final entries = await rootDir.list(followLinks: false).toList();
    for (final entity in entries) {
      if (entity is! Directory) continue;
      final base = path.basename(entity.path);
      if (base.startsWith('.') || base == '.ae_hub') continue;
      final handler = await registry.findFor(entity);
      if (handler != null) {
        final name = await svc.ingest(entity);
        ingested.add(name);
      } else {
        skipped.add(entity.path);
      }
    }
    // Also try the root itself.
    final rootHandler = await registry.findFor(rootDir);
    if (rootHandler != null) {
      final name = await svc.ingest(rootDir);
      ingested.add(name);
    }

    if (strict && skipped.isNotEmpty) {
      return AeResult.fail(
        code: 'unhandled_subdirs',
        message: 'No extractor for ${skipped.length} subdirectories',
        details: {'skipped': skipped},
      );
    }
    return AeResult.ok({
      'hub_path': hubPath,
      'ingested': ingested,
      'skipped_count': skipped.length,
    });
  }

  Future<AeResult<Map<String, dynamic>>> _handleStatus(
    final ArgResults command,
  ) async {
    final root = command['root']?.toString() ?? Directory.current.path;
    final packName = command['pack']?.toString();
    final tierFilterRaw = command['tier']?.toString();
    final resolver = FileHubResolver();
    final hubPath = await resolver.resolveHub(projectRoot: root);
    if (hubPath == null) {
      return AeResult.fail(
        code: 'no_hub',
        message: 'No .ae_hub found at $root.',
      );
    }
    final artStore = FileArtifactStore(hubPath);
    final canStore = FileCanonicalStore(hubPath);
    final svc = DefaultArtifactService(
      artifactStore: artStore,
      canonicalStore: canStore,
      extractorRegistry: HeuristicExtractorRegistry(const []),
    );
    final report = packName != null
        ? await svc.verifyOne(packName)
        : await svc.verifyProject();
    final entries = tierFilterRaw == null
        ? report.entries
        : report.entries
            .where((final e) => e.tier.tier.toString() == tierFilterRaw)
            .toList();
    return AeResult.ok({
      'hub_path': hubPath,
      'entries': entries.map((final e) => e.toJson()).toList(),
      'tier_counts': {
        for (final entry in report.tierCounts.entries)
          entry.key.code: entry.value,
      },
    });
  }

  Future<AeResult<Map<String, dynamic>>> _handleSync(
    final ArgResults command,
  ) async {
    final root = command['root']?.toString() ?? Directory.current.path;
    final packName = command['pack']?.toString();
    final resolver = FileHubResolver();
    final hubPath = await resolver.resolveHub(projectRoot: root);
    if (hubPath == null) {
      return AeResult.fail(code: 'no_hub', message: 'No hub at $root.');
    }
    final artStore = FileArtifactStore(hubPath);
    final canStore = FileCanonicalStore(hubPath);
    final svc = DefaultArtifactService(
      artifactStore: artStore,
      canonicalStore: canStore,
      extractorRegistry: HeuristicExtractorRegistry(const []),
    );
    final drift = DefaultDriftService(
      artifactStore: artStore,
      canonicalStore: canStore,
    );
    final names = packName != null ? [packName] : await svc.list();
    final results = <Map<String, dynamic>>[];
    for (final name in names) {
      try {
        final changed = await svc.sync(name);
        final report = await drift.buildReport(name, generatedBy: 'ae sync');
        results.add({
          'pack': name,
          'changed': changed,
          'code_drift_count': report.codeDrift.length,
          'intent_drift_count': report.intentDrift.length,
        });
      } on ArgumentError catch (e) {
        results.add({'pack': name, 'error': e.message?.toString()});
      }
    }
    return AeResult.ok({'hub_path': hubPath, 'results': results});
  }

  Future<AeResult<Map<String, dynamic>>> _handleCanonical(
    final ArgResults command,
  ) async {
    final sub = command.command;
    if (sub == null) {
      return AeResult.fail(
        code: 'invalid_command',
        message: 'Missing canonical subcommand. See: ae canonical --help',
      );
    }
    final root = sub['root']?.toString() ?? Directory.current.path;
    final resolver = FileHubResolver();
    final hubPath = await resolver.resolveHub(projectRoot: root);
    if (hubPath == null) {
      return AeResult.fail(code: 'no_hub', message: 'No hub at $root.');
    }
    final canStore = FileCanonicalStore(hubPath);
    final svc = DefaultCanonicalService(store: canStore);

    switch (sub.name) {
      case 'init':
        final concept = sub['concept']?.toString();
        final title = sub['title']?.toString();
        if (concept == null || concept.isEmpty) {
          return AeResult.fail(
            code: 'validation_error',
            message: 'Missing required --concept',
          );
        }
        if (title == null || title.isEmpty) {
          return AeResult.fail(
            code: 'validation_error',
            message: 'Missing required --title',
          );
        }
        final pack = await svc.scaffold(concept, title: title);
        return AeResult.ok({
          'concept': pack.meta.concept,
          'version': pack.meta.version,
        });

      case 'list':
        final ids = await svc.list();
        return AeResult.ok({'concepts': ids});

      case 'snapshot':
        final concept = sub['concept']?.toString();
        if (concept == null || concept.isEmpty) {
          return AeResult.fail(
            code: 'validation_error',
            message: 'Missing --concept',
          );
        }
        final dir = await svc.snapshot(concept);
        return AeResult.ok({'concept': concept, 'snapshot_dir': dir});

      case 'diff':
        final concept = sub['concept']?.toString();
        if (concept == null) {
          return AeResult.fail(
            code: 'validation_error',
            message: 'Missing --concept',
          );
        }
        final fromRaw = sub['from']?.toString();
        final toRaw = sub['to']?.toString();
        int? parseVer(final String? raw) {
          if (raw == null || raw.isEmpty || raw == 'current') return null;
          final s = raw.startsWith('v') ? raw.substring(1) : raw;
          return int.tryParse(s);
        }

        final diff = await svc.diff(
          concept,
          fromVersion: parseVer(fromRaw),
          toVersion: parseVer(toRaw),
        );
        return AeResult.ok(diff.toJson());

      case 'import':
        final from = sub['from']?.toString();
        final asConcept = sub['as']?.toString();
        if (from == null || asConcept == null) {
          return AeResult.fail(
            code: 'validation_error',
            message: 'Missing --from and/or --as',
          );
        }
        final pack = await svc.import(from, asConceptId: asConcept);
        return AeResult.ok({
          'imported_as': asConcept,
          'concept_in_meta': pack.meta.concept,
        });

      default:
        return AeResult.fail(
          code: 'invalid_command',
          message: 'Unknown canonical subcommand: ${sub.name}',
        );
    }
  }

  Future<AeResult<Map<String, dynamic>>> _handleKnow(
    final ArgResults command,
  ) async {
    final sub = command.command;
    if (sub == null) {
      return AeResult.fail(
        code: 'validation_error',
        message: 'Know subcommand is required',
      );
    }

    final hubOverride = _hubOptionFromKnowCommand(command);
    final resolver = FileHubResolver();
    final hubPath = hubOverride ?? await resolver.resolveHub();
    if (hubPath == null) {
      return AeResult.fail(
        code: 'hub_not_found',
        message: 'No hub found. Run "ae hub init" to create one.',
      );
    }

    final basePath = path.join(hubPath, AeCoreConfig.hubKnowDir);
    final store = FileKnowledgeStore(basePath);
    final service = DefaultAeKnowService(
      store: store,
      extractors: [
        UrlExtractor(),
        PdfExtractor(),
        PassthroughExtractor(),
        RepoExtractor(),
      ],
    );

    if (sub.name == 'matrix') {
      final m = sub.command;
      if (m == null) {
        return AeResult.fail(
          code: 'validation_error',
          message: 'Know matrix subcommand is required (init|scaffold|diff)',
        );
      }
      switch (m.name) {
        case 'init':
          final name = m['name']?.toString() ?? '';
          final colsRaw = m['columns']?.toString() ?? '';
          final cols = colsRaw
              .split(',')
              .map((final s) => s.trim())
              .where((final s) => s.isNotEmpty)
              .toList();
          if (name.isEmpty) {
            return AeResult.fail(
              code: 'validation_error',
              message: 'Missing required argument: --name',
            );
          }
          final result = await service.matrixInit(
            KnowMatrixInitInput(
              name: name,
              columns: cols,
              title: m['title']?.toString(),
              hubPath: hubPath,
              normativeKind: m['normative-kind']?.toString(),
              normativeRef: m['normative-ref']?.toString(),
            ),
          );
          if (!result.success || result.data == null) {
            return AeResult.fail(
              code: result.error?.code ?? 'know_matrix_init_failed',
              message: result.error?.message ?? 'Matrix init failed',
              details: result.error?.details,
            );
          }
          return AeResult.ok(result.data!.toJson());
        case 'scaffold':
          final name = m['name']?.toString() ?? '';
          final repo = m['repo']?.toString() ?? '';
          if (name.isEmpty || repo.isEmpty) {
            return AeResult.fail(
              code: 'validation_error',
              message: 'Missing required arguments: --name and --repo',
            );
          }
          final result = await service.matrixScaffold(
            KnowMatrixScaffoldInput(
              name: name,
              repoPath: repo,
              outFile: m['out']?.toString(),
              hubPath: hubPath,
            ),
          );
          if (!result.success || result.data == null) {
            return AeResult.fail(
              code: result.error?.code ?? 'know_matrix_scaffold_failed',
              message: result.error?.message ?? 'Matrix scaffold failed',
              details: result.error?.details,
            );
          }
          return AeResult.ok(result.data!.toJson());
        case 'diff':
          final result = await service.matrixCompare(
            KnowMatrixCompareInput(
              fromName: m['from-name']?.toString(),
              toName: m['to-name']?.toString(),
              fromFile: m['from-file']?.toString(),
              toFile: m['to-file']?.toString(),
              hubPath: hubPath,
            ),
          );
          if (!result.success || result.data == null) {
            return AeResult.fail(
              code: result.error?.code ?? 'know_matrix_compare_failed',
              message: result.error?.message ?? 'Matrix diff failed',
              details: result.error?.details,
            );
          }
          return AeResult.ok(result.data!.toJson());
        default:
          return AeResult.fail(
            code: 'invalid_command',
            message: 'Unknown know matrix subcommand: ${m.name}',
          );
      }
    }

    if (sub.name == 'plan') {
      final name = sub['name']?.toString() ?? '';
      if (name.isEmpty) {
        return AeResult.fail(
          code: 'validation_error',
          message: 'Missing required argument: --name',
        );
      }
      final localeRaw = sub['language']?.toString() ?? sub['locale']?.toString();
      final String? locale =
          localeRaw != null && localeRaw.isNotEmpty ? localeRaw : null;
      final result = await service.plan(
        KnowPlanInput(name: name, hubPath: hubPath, locale: locale),
      );
      if (!result.success || result.data == null) {
        return AeResult.fail(
          code: result.error?.code ?? 'know_plan_failed',
          message: result.error?.message ?? 'Plan failed',
          details: result.error?.details,
        );
      }
      final outRaw = sub['out']?.toString();
      if (outRaw != null && outRaw.isNotEmpty) {
        final outPath = path.isAbsolute(outRaw)
            ? outRaw
            : path.join(Directory.current.path, outRaw);
        await File(outPath).writeAsString(result.data!.planMarkdown);
      }
      return AeResult.ok(result.data!.toJson());
    }

    switch (sub.name) {
      case 'build':
        final name = sub['name']?.toString() ?? '';
        final url = sub['url']?.toString();
        final localPath = sub['path']?.toString();
        final repoUrl = sub['repo']?.toString();
        if (name.isEmpty) {
          return AeResult.fail(
            code: 'validation_error',
            message: 'Missing required argument: --name',
          );
        }
        final hasUrl = url != null && url.isNotEmpty;
        final hasPath = localPath != null && localPath.isNotEmpty;
        final hasRepo = repoUrl != null && repoUrl.isNotEmpty;
        if ((hasUrl ? 1 : 0) + (hasPath ? 1 : 0) + (hasRepo ? 1 : 0) != 1) {
          return AeResult.fail(
            code: 'validation_error',
            message: 'Provide exactly one of: --url, --path, or --repo',
          );
        }
        final formatRaw = sub['format']?.toString() ?? 'auto';
        final KnowFormat? format =
            formatRaw == 'auto' ? null : KnowFormat.fromString(formatRaw);
        final onConflictRaw = sub['on-conflict']?.toString() ?? 'reuse';
        final onConflict = KnowOnConflict.fromString(onConflictRaw);
        final result = await service.build(
          KnowBuildInput(
            name: name,
            url: hasUrl ? url : null,
            localPath: hasPath ? localPath : null,
            repoUrl: hasRepo ? repoUrl : null,
            hubPath: hubPath,
            format: format,
            onConflict: onConflict,
          ),
        );
        if (!result.success || result.data == null) {
          return AeResult.fail(
            code: result.error?.code ?? 'know_build_failed',
            message: result.error?.message ?? 'Know build failed',
            details: result.error?.details,
          );
        }
        return AeResult.ok(result.data!.toJson());

      case 'list':
        final result = await service.list(KnowListInput(hubPath: hubPath));
        if (!result.success || result.data == null) {
          return AeResult.fail(
            code: result.error?.code ?? 'know_list_failed',
            message: result.error?.message ?? 'Know list failed',
            details: result.error?.details,
          );
        }
        return AeResult.ok(result.data!.toJson());

      case 'show':
        final name = sub['name']?.toString() ?? '';
        if (name.isEmpty) {
          return AeResult.fail(
            code: 'validation_error',
            message: 'Missing required argument: --name',
          );
        }
        final result = await service.show(
          KnowShowInput(name: name, hubPath: hubPath),
        );
        if (!result.success || result.data == null) {
          return AeResult.fail(
            code: result.error?.code ?? 'know_show_failed',
            message: result.error?.message ?? 'Know show failed',
            details: result.error?.details,
          );
        }
        return AeResult.ok(result.data!.toJson());

      case 'remove':
        final name = sub['name']?.toString() ?? '';
        if (name.isEmpty) {
          return AeResult.fail(
            code: 'validation_error',
            message: 'Missing required argument: --name',
          );
        }
        final result = await service.remove(
          KnowRemoveInput(name: name, hubPath: hubPath),
        );
        if (!result.success) {
          return AeResult.fail(
            code: result.error?.code ?? 'know_remove_failed',
            message: result.error?.message ?? 'Know remove failed',
            details: result.error?.details,
          );
        }
        return AeResult.ok({'name': name, 'removed': true});

      case 'update':
        final name = sub['name']?.toString() ?? '';
        if (name.isEmpty) {
          return AeResult.fail(
            code: 'validation_error',
            message: 'Missing required argument: --name',
          );
        }
        final result = await service.update(
          KnowUpdateInput(name: name, hubPath: hubPath),
        );
        if (!result.success || result.data == null) {
          return AeResult.fail(
            code: result.error?.code ?? 'know_update_failed',
            message: result.error?.message ?? 'Know update failed',
            details: result.error?.details,
          );
        }
        return AeResult.ok(result.data!.toJson());

      case 'diff':
        final fromName = sub['from']?.toString() ?? '';
        final toName = sub['to']?.toString() ?? '';
        if (fromName.isEmpty || toName.isEmpty) {
          return AeResult.fail(
            code: 'validation_error',
            message: 'Missing required arguments: --from and --to',
          );
        }
        final diffResult = await service.diff(
          KnowDiffInput(
              fromName: fromName, toName: toName, hubPath: hubPath),
        );
        if (!diffResult.success || diffResult.data == null) {
          return AeResult.fail(
            code: diffResult.error?.code ?? 'know_diff_failed',
            message: diffResult.error?.message ?? 'Know diff failed',
            details: diffResult.error?.details,
          );
        }
        return AeResult.ok(diffResult.data!.toJson());

      case 'migrate':
        final dryRun = sub['dry-run'] == true;
        try {
          final report = await store.migrate(dryRun: dryRun);
          return AeResult.ok(report.toJson());
        } catch (e) {
          return AeResult.fail(
            code: 'know_migrate_failed',
            message: 'Migration failed: $e',
          );
        }

      default:
        return AeResult.fail(
          code: 'invalid_command',
          message: 'Unknown know subcommand: ${sub.name}',
        );
    }
  }

  Future<AeResult<Map<String, dynamic>>> _handleSpec(
    final ArgResults command,
  ) async {
    final sub = command.command;
    if (sub == null || sub.name != 'export') {
      return AeResult.fail(
        code: 'validation_error',
        message: 'Usage: ae spec export --out <dir> [--hub ...] [--matrix ...]',
      );
    }
    final outRaw = sub['out']?.toString() ?? '';
    if (outRaw.isEmpty) {
      return AeResult.fail(
        code: 'validation_error',
        message: 'Missing required argument: --out',
      );
    }
    final outDir = path.isAbsolute(outRaw)
        ? outRaw
        : path.join(Directory.current.path, outRaw);
    await Directory(outDir).create(recursive: true);

    final hubOverride = _hubOptionFromKnowCommand(command);
    final resolver = FileHubResolver();
    final hubPath = hubOverride ?? await resolver.resolveHub();
    if (hubPath == null) {
      return AeResult.fail(
        code: 'hub_not_found',
        message: 'No hub found. Run "ae hub init" to create one.',
      );
    }

    const defaultExportLocale = 'en';
    final localeRaw = sub['language']?.toString() ?? sub['locale']?.toString();
    final locale = (localeRaw != null && localeRaw.isNotEmpty)
        ? localeRaw.trim()
        : defaultExportLocale;

    final matrixDefault =
        path.join(Directory.current.path, 'docs', 'feature_matrix.yaml');
    final matrixPath = sub['matrix']?.toString();
    final matrixSrc = (matrixPath != null && matrixPath.isNotEmpty)
        ? (path.isAbsolute(matrixPath)
            ? matrixPath
            : path.join(Directory.current.path, matrixPath))
        : matrixDefault;

    if (!await File(matrixSrc).exists()) {
      return AeResult.fail(
        code: 'validation_error',
        message: 'feature_matrix file not found: $matrixSrc',
      );
    }

    final exportBaseNorm = path.normalize(Directory.current.path);

    final defSvcResult = const DefaultAeDefinitionService().getDefinition();
    if (!defSvcResult.success || defSvcResult.data == null) {
      return AeResult.fail(
        code: defSvcResult.error?.code ?? 'definition_failed',
        message: defSvcResult.error?.message ?? 'Failed to get definition',
        details: defSvcResult.error?.details,
      );
    }
    final defOut = defSvcResult.data!;

    final baselineRaw = sub['matrix-baseline']?.toString().trim() ?? '';
    String? matrixDiffPath;
    if (baselineRaw.isNotEmpty) {
      final baselinePath = path.isAbsolute(baselineRaw)
          ? baselineRaw
          : path.join(Directory.current.path, baselineRaw);
      if (!await File(baselinePath).exists()) {
        return AeResult.fail(
          code: 'validation_error',
          message: 'matrix baseline file not found: $baselinePath',
        );
      }
      final fromYaml = await File(baselinePath).readAsString();
      final toYaml = await File(matrixSrc).readAsString();
      final a = KnowFeatureMatrix.parseYamlString(fromYaml);
      final b = KnowFeatureMatrix.parseYamlString(toYaml);
      final diff = diffKnowMatrices(a, b);
      matrixDiffPath = SpecExportSupport.matrixDiffFile;
      await File(path.join(outDir, matrixDiffPath)).writeAsString(
        JsonEncoder.withIndent('  ').convert(diff.toJson()),
      );
    }

    final manifestOpt = sub['manifest']?.toString().trim() ?? '';
    String? manifestRel;
    if (manifestOpt.isNotEmpty) {
      final absManifest = path.isAbsolute(manifestOpt)
          ? manifestOpt
          : path.join(Directory.current.path, manifestOpt);
      manifestRel = path.relative(absManifest, from: exportBaseNorm);
    }

    final basePath = path.join(hubPath, AeCoreConfig.hubKnowDir);
    final store = FileKnowledgeStore(basePath);
    final service = DefaultAeKnowService(
      store: store,
      extractors: [
        UrlExtractor(),
        PdfExtractor(),
        PassthroughExtractor(),
        RepoExtractor(),
      ],
    );

    final enc = JsonEncoder.withIndent('  ');
    await File(path.join(outDir, SpecExportSupport.definitionYamlFile))
        .writeAsString(SpecExportSupport.definitionYaml(defOut));
    await File(path.join(outDir, SpecExportSupport.definitionMdFile))
        .writeAsString(SpecExportSupport.definitionMarkdown(defOut));
    await File(path.join(outDir, SpecExportSupport.definitionJsonPtrFile))
        .writeAsString(enc.convert(SpecExportSupport.definitionJsonPointer()));

    final listResult = await service.list(KnowListInput(hubPath: hubPath));
    if (!listResult.success || listResult.data == null) {
      return AeResult.fail(
        code: listResult.error?.code ?? 'know_list_failed',
        message: listResult.error?.message ?? 'Know list failed',
      );
    }
    await File(path.join(outDir, 'know_list.json')).writeAsString(
      enc.convert(
        _resultToEnvelope('know list', AeResult.ok(listResult.data!.toJson())),
      ),
    );

    await File(matrixSrc).copy(path.join(outDir, 'feature_matrix.yaml'));

    final indexPacks = <Map<String, dynamic>>[];
    for (final meta in listResult.data!.packs) {
      final name = meta.name;
      final slug = packSpecSlug(name);
      final showJson = 'know_show_$slug.json';
      final planMd = 'plan_$slug.md';

      final showResult =
          await service.show(KnowShowInput(name: name, hubPath: hubPath));
      if (!showResult.success || showResult.data == null) {
        return AeResult.fail(
          code: showResult.error?.code ?? 'know_show_failed',
          message: showResult.error?.message ?? 'Know show failed for $name',
        );
      }
      final showRaw = showResult.data!.toJson();
      final portableShow = SpecExportSupport.relativizeKnowShowData(
        Map<String, dynamic>.from(showRaw as Map<dynamic, dynamic>),
        exportBaseNorm,
      );
      await File(path.join(outDir, showJson)).writeAsString(
        enc.convert(
          _resultToEnvelope(
            'know show',
            AeResult.ok(portableShow),
          ),
        ),
      );

      final planResult = await service.plan(
        KnowPlanInput(name: name, hubPath: hubPath, locale: locale),
      );
      if (!planResult.success || planResult.data == null) {
        return AeResult.fail(
          code: planResult.error?.code ?? 'know_plan_failed',
          message: planResult.error?.message ?? 'Know plan failed for $name',
        );
      }
      await File(path.join(outDir, planMd))
          .writeAsString(planResult.data!.planMarkdown);

      indexPacks.add({
        'name': name,
        'know_show': showJson,
        'plan': planMd,
      });
    }

    final specIndex = {
      'schema': 'spec_export.v2',
      'version': 2,
      'locale': locale,
      'export_base': '.',
      'definition_yaml': SpecExportSupport.definitionYamlFile,
      'definition_md': SpecExportSupport.definitionMdFile,
      'definition_json': SpecExportSupport.definitionJsonPtrFile,
      'know_list': 'know_list.json',
      'feature_matrix': 'feature_matrix.yaml',
      if (matrixDiffPath != null) 'matrix_diff': matrixDiffPath,
      if (manifestRel != null) 'e2e_manifest': manifestRel,
      'packs': indexPacks,
    };
    await File(path.join(outDir, 'spec_index.json')).writeAsString(
      enc.convert(specIndex),
    );

    return AeResult.ok(
      {
        'spec_dir': outDir,
        'pack_count': listResult.data!.packs.length,
        'locale': locale,
        'spec_index': 'spec_index.json',
        if (matrixDiffPath != null) 'matrix_diff': matrixDiffPath,
        if (manifestRel != null) 'e2e_manifest': manifestRel,
      },
    );
  }

  Future<AeResult<Map<String, dynamic>>> _handleE2e(
    final ArgResults command,
  ) async {
    final sub = command.command;
    if (sub == null || sub.name != 'sync-know') {
      return AeResult.fail(
        code: 'validation_error',
        message: 'Usage: ae e2e sync-know --manifest <path.yaml>',
      );
    }
    final manifestPath = sub['manifest']?.toString() ?? '';
    if (manifestPath.isEmpty) {
      return AeResult.fail(
        code: 'validation_error',
        message: 'Missing required argument: --manifest',
      );
    }
    final absManifest = path.isAbsolute(manifestPath)
        ? manifestPath
        : path.join(Directory.current.path, manifestPath);
    final manifest = E2eKnowManifest.loadFile(absManifest);

    final baseRaw = sub['base']?.toString();
    final baseDir = (baseRaw != null && baseRaw.isNotEmpty)
        ? (path.isAbsolute(baseRaw)
            ? baseRaw
            : path.join(Directory.current.path, baseRaw))
        : Directory.current.path;

    final hubOverride = _hubOptionFromKnowCommand(command);
    final resolver = FileHubResolver();
    final hubPath = hubOverride ?? await resolver.resolveHub();
    if (hubPath == null) {
      return AeResult.fail(
        code: 'hub_not_found',
        message: 'No hub found. Run "ae hub init" to create one.',
      );
    }

    final basePath = path.join(hubPath, AeCoreConfig.hubKnowDir);
    final store = FileKnowledgeStore(basePath);
    final service = DefaultAeKnowService(
      store: store,
      extractors: [
        UrlExtractor(),
        PdfExtractor(),
        PassthroughExtractor(),
        RepoExtractor(),
      ],
    );

    final network = environment?['AE_E2E_NETWORK'] ??
        Platform.environment['AE_E2E_NETWORK'] ??
        '';
    var built = 0;
    var skipped = 0;

    for (final pack in manifest.packs) {
      if (pack.network && network != '1') {
        skipped++;
        continue;
      }
      KnowFormat? format;
      if (pack.format != null && pack.format!.isNotEmpty) {
        format = KnowFormat.fromString(pack.format!);
      }
      final result = await service.build(
        KnowBuildInput(
          name: pack.name,
          url: pack.url,
          localPath:
              pack.path != null ? path.join(baseDir, pack.path!) : null,
          repoUrl: null,
          hubPath: hubPath,
          format: format,
          onConflict: KnowOnConflict.update,
        ),
      );
      if (!result.success || result.data == null) {
        return AeResult.fail(
          code: result.error?.code ?? 'know_build_failed',
          message:
              result.error?.message ?? 'know build failed for ${pack.name}',
        );
      }
      built++;
    }

    return AeResult.ok(
      {
        'manifest': absManifest,
        'schema': manifest.schema,
        'built': built,
        'skipped_network': skipped,
        'packs_total': manifest.packs.length,
      },
    );
  }

  Future<AeResult<Map<String, dynamic>>> _installOrUpgradeSkill({
    required final String name,
    required final String targetBase,
    required final bool upgrade,
    required final String operation,
    required final bool requireExisting,
    final String? templatePath,
  }) async {
    final SkillTemplateProvider provider;
    if (templatePath != null && templatePath.isNotEmpty) {
      provider = FileSkillTemplateProvider(templatePath);
    } else {
      provider = const EmbeddedSkillTemplateProvider();
    }

    final String template;
    final String? version;
    try {
      template = await provider.readTemplate();
      version = await provider.readVersion();
    } catch (error) {
      return AeResult.fail(
        code: 'skill_template_load_failed',
        message: 'Failed to load skill template',
        details: error.toString(),
      );
    }

    final skillDir = Directory(path.join(targetBase, name));
    final skillFile = File(path.join(skillDir.path, 'SKILL.md'));

    final exists = await skillFile.exists();
    if (!exists && requireExisting) {
      return AeResult.fail(
        code: 'skill_missing',
        message:
            'Skill not found at ${skillDir.path}. Run skill install first.',
      );
    }

    if (!exists) {
      await skillDir.create(recursive: true);
      await skillFile.writeAsString(template);
      if (version != null) {
        await File(
          path.join(skillDir.path, '.ae_cli_skill_version'),
        ).writeAsString(version);
      }

      return AeResult.ok(
        {
          'name': name,
          'target': skillDir.path,
          'installed': true,
          'upgraded': false,
          'version': version,
          'no_op': false,
        },
        meta: {'operation': operation},
      );
    }

    final currentContent = await skillFile.readAsString();
    final currentVersion = await _readInstalledSkillVersion(skillDir.path);

    if (currentContent == template) {
      return AeResult.ok(
        {
          'name': name,
          'target': skillDir.path,
          'installed': false,
          'upgraded': false,
          'version': currentVersion,
          'no_op': true,
          'message': 'Skill already up-to-date',
        },
        meta: {'operation': operation},
      );
    }

    if (!upgrade) {
      return AeResult.fail(
        code: 'skill_upgrade_required',
        message:
            'Skill at ${skillDir.path} differs from bundled template. Re-run with --upgrade to replace it.',
        details: {
          'name': name,
          'target': skillDir.path,
          'installed_version': currentVersion,
          'available_version': version,
        },
      );
    }

    final backupDir = Directory(
      '${skillDir.path}.backup.${DateTime.now().millisecondsSinceEpoch}',
    );
    await _copyDirectory(skillDir, backupDir);

    await skillFile.writeAsString(template);

    if (version != null) {
      await File(
        path.join(skillDir.path, '.ae_cli_skill_version'),
      ).writeAsString(version);
    }

    return AeResult.ok(
      {
        'name': name,
        'target': skillDir.path,
        'installed': false,
        'upgraded': true,
        'previous_version': currentVersion,
        'version': version,
        'backup_path': backupDir.path,
        'no_op': false,
      },
      meta: {'operation': operation},
    );
  }

  Future<void> _copyDirectory(
    final Directory source,
    final Directory destination,
  ) async {
    await destination.create(recursive: true);
    await for (final entity in source.list(recursive: true)) {
      final relative = path.relative(entity.path, from: source.path);
      final targetPath = path.join(destination.path, relative);

      if (entity is Directory) {
        await Directory(targetPath).create(recursive: true);
        continue;
      }
      if (entity is File) {
        await File(targetPath).parent.create(recursive: true);
        await entity.copy(targetPath);
      }
    }
  }

  Future<String?> _readInstalledSkillVersion(final String skillDir) async {
    final markerFile = File(path.join(skillDir, '.ae_cli_skill_version'));
    if (await markerFile.exists()) {
      final marker = (await markerFile.readAsString()).trim();
      if (marker.isNotEmpty) {
        return marker;
      }
    }

    final skillFile = File(path.join(skillDir, 'SKILL.md'));
    if (!await skillFile.exists()) {
      return null;
    }
    final content = await skillFile.readAsString();
    final lines = content.split('\n');
    for (final line in lines) {
      final normalized = line.trim();
      if (normalized.startsWith('<!-- ae-cli-skill-version:')) {
        return normalized
            .replaceFirst('<!-- ae-cli-skill-version:', '')
            .replaceFirst('-->', '')
            .trim();
      }
    }
    return null;
  }

  String _defaultSkillsBaseDir() {
    final envMap = environment ?? Platform.environment;
    final codexHome = envMap['CODEX_HOME'];
    if (codexHome != null && codexHome.isNotEmpty) {
      return path.join(codexHome, 'skills');
    }

    final home = envMap['HOME'] ?? envMap['USERPROFILE'];
    if (home == null || home.isEmpty) {
      throw StateError(
        'Unable to resolve home directory for skill target path',
      );
    }

    return path.join(home, '.codex', 'skills');
  }

  SafeWriteOptions _safeWriteOptions(final ArgResults command) {
    return SafeWriteOptions(
      check: command['check'] == true,
      diff: command['diff'] == true,
      backup: command['backup'] == true,
      noOverwrite: command['no-overwrite'] == true,
    );
  }

  int _renderPackageCommand(
    final String commandPath,
    final Map<String, dynamic> envelope,
  ) {
    if (envelope['success'] != true) {
      final error = envelope['error'] as Map<String, dynamic>?;
      _err.writeln(error?['message'] ?? 'Package command failed');
      if (error?['details'] != null) {
        _err.writeln(error!['details']);
      }
      return 1;
    }

    final data = envelope['data'] as Map<String, dynamic>? ?? const {};
    if (commandPath == 'package resolve') {
      _out.writeln(jsonEncode(data['instructions'] ?? const {}));
    } else if (commandPath == 'package validate') {
      _out.writeln('ok');
    }
    return 0;
  }

  Future<String?> _detectPackageVersion(final Directory cwd) async {
    for (final candidate in const [
      'pubspec.yaml',
      'package.json',
      'pyproject.toml'
    ]) {
      final file = File(path.join(cwd.path, candidate));
      if (!await file.exists()) {
        continue;
      }
      final raw = await file.readAsString();
      final match = switch (candidate) {
        'pubspec.yaml' =>
          RegExp(r'^version:\s*([^\s#]+)', multiLine: true).firstMatch(raw),
        'package.json' => RegExp(r'"version"\s*:\s*"([^"]+)"').firstMatch(raw),
        _ =>
          RegExp(r'^version\s*=\s*"([^"]+)"', multiLine: true).firstMatch(raw),
      };
      final version = match?.group(1)?.trim();
      if (version != null && version.isNotEmpty) {
        return version;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> _readInstructionsPayload(
    final String source,
  ) async {
    final raw = switch (source) {
      '-' => await stdin.transform(utf8.decoder).join(),
      _ => await (() async {
          final file = File(source);
          if (await file.exists()) {
            return file.readAsString();
          }
          return source;
        })(),
    };
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Instruction JSON must be an object');
    }
    return decoded;
  }

  String? _validatePackageInstructions(final Map<String, dynamic> payload) {
    const requiredTopLevel = <String>{
      'contract_version',
      'package',
      'profile',
      'build',
      'deploy',
      'domain',
      'safety',
    };
    for (final key in requiredTopLevel) {
      if (!payload.containsKey(key)) {
        return 'Missing required field: $key';
      }
    }

    if (payload['contract_version'] != 'ae.v3.package.v1') {
      return 'contract_version must equal ae.v3.package.v1';
    }
    final package = payload['package'];
    if (package is! Map ||
        !_nonEmptyString(package['id']) ||
        !_nonEmptyString(package['version'])) {
      return 'package.id and package.version are required';
    }
    final profile = payload['profile'];
    final profileMajor = profile is Map ? profile['major'] : null;
    if (profile is! Map ||
        !_nonEmptyString(profile['id']) ||
        profileMajor is! int ||
        profileMajor < 1) {
      return 'profile.id and profile.major are required';
    }
    final build = payload['build'];
    if (build is! Map ||
        build['steps'] is! List ||
        (build['steps'] as List).isEmpty) {
      return 'build.steps must contain at least one step';
    }
    final steps = build['steps'] as List;
    for (var i = 0; i < steps.length; i += 1) {
      final step = steps[i];
      if (step is! Map) {
        return 'build.steps[$i] must be an object';
      }
      if (!_nonEmptyString(step['type'])) {
        return 'build.steps[$i].type must be a non-empty string';
      }
      if (step['config'] is! Map) {
        return 'build.steps[$i].config must be an object';
      }
    }

    final deploy = payload['deploy'];
    if (deploy is! Map ||
        deploy['plugins'] is! List ||
        (deploy['plugins'] as List).isEmpty) {
      return 'deploy.plugins must contain at least one plugin';
    }
    if (deploy['inputs'] is! Map ||
        (deploy['inputs'] as Map)['required'] is! List) {
      return 'deploy.inputs.required must be present';
    }
    final plugins = deploy['plugins'] as List;
    for (var i = 0; i < plugins.length; i += 1) {
      final plugin = plugins[i];
      if (plugin is! Map) {
        return 'deploy.plugins[$i] must be an object';
      }
      if (!_nonEmptyString(plugin['name'])) {
        return 'deploy.plugins[$i].name must be a non-empty string';
      }
      final version = plugin['version'];
      if (version is! int || version < 1) {
        return 'deploy.plugins[$i].version must be an integer >= 1';
      }
      if (plugin['config'] is! Map) {
        return 'deploy.plugins[$i].config must be an object';
      }
    }
    final requiredInputs = (deploy['inputs'] as Map)['required'] as List;
    if (requiredInputs.any((final entry) => !_nonEmptyString(entry))) {
      return 'deploy.inputs.required must contain only non-empty strings';
    }

    final domain = payload['domain'];
    final capabilities = domain is Map ? domain['capabilities'] : null;
    final wildcard = capabilities is Map
        ? capabilities['wildcard_support_mode']?.toString()
        : null;
    const validWildcardModes = <String>{
      'none',
      'dns01_cloudflare',
      'dns01_route53',
      'dns01_any',
    };
    if (wildcard == null || !validWildcardModes.contains(wildcard)) {
      return 'domain.capabilities.wildcard_support_mode is invalid';
    }
    final safety = payload['safety'];
    final constraints = safety is Map ? safety['constraints'] : null;
    if (constraints is! Map) {
      return 'safety.constraints is required';
    }
    final allowedExecutors = constraints['allowed_executors'];
    if (allowedExecutors is! List || allowedExecutors.isEmpty) {
      return 'safety.constraints.allowed_executors must be a non-empty array';
    }
    if (allowedExecutors.any((final entry) => !_nonEmptyString(entry))) {
      return 'safety.constraints.allowed_executors must contain only non-empty strings';
    }
    if (allowedExecutors.any(
      (final entry) => entry != 'lythe' && entry != 'rust',
    )) {
      return 'safety.constraints.allowed_executors may contain only lythe or rust';
    }
    final forbiddenActions = constraints['forbidden_actions'];
    if (forbiddenActions is! List) {
      return 'safety.constraints.forbidden_actions must be an array';
    }
    for (final action in forbiddenActions) {
      if (!_nonEmptyString(action)) {
        return 'safety.constraints.forbidden_actions must contain only non-empty strings';
      }
      final value = action.toString().toLowerCase();
      if (value.contains('ssh') ||
          value.contains('shell') ||
          value.contains('remote_exec') ||
          value.contains('exec')) {
        return 'safety.constraints.forbidden_actions contains a forbidden runtime action';
      }
    }
    return null;
  }

  bool _nonEmptyString(final Object? value) =>
      value is String && value.trim().isNotEmpty;

  Future<Map<String, dynamic>> _readInputJson(final String source) async {
    final raw = source == '-'
        ? await stdin.transform(utf8.decoder).join()
        : await File(source).readAsString();

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Input JSON must be an object');
    }
    return decoded;
  }

  List _parseList(final Object? value) {
    if (value == null) {
      return const [];
    }
    if (value is List) {
      return value;
    }
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded;
        }
      } catch (_) {
        return value
            .split(',')
            .map((final part) => part.trim())
            .where((final part) => part.isNotEmpty)
            .toList(growable: false);
      }
    }
    return const [];
  }

  Map _parseMap(final Object? value) {
    if (value == null) {
      return const {};
    }
    if (value is Map) {
      return value;
    }
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        return decoded is Map ? decoded : const {};
      } catch (_) {
        return const {};
      }
    }
    return const {};
  }

  bool _parseBool(final Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      return value.toLowerCase() == 'true';
    }
    return false;
  }

  Map<String, dynamic> _resultToEnvelope(
    final String command,
    final AeResult<Map<String, dynamic>> result,
  ) {
    if (!result.success || result.data == null) {
      return _errorEnvelope(
        command: command,
        code: result.error?.code ?? 'command_failed',
        message: result.error?.message ?? 'Command failed',
        details: result.error?.details,
        warnings: result.warnings,
        meta: result.meta,
      );
    }

    return {
      'success': true,
      'command': command,
      'data': result.data,
      'warnings': result.warnings,
      'meta': result.meta,
    };
  }

  Map<String, dynamic> _errorEnvelope({
    required final String command,
    required final String code,
    required final String message,
    final Object? details,
    final List<String> warnings = const [],
    final Map<String, dynamic> meta = const {},
  }) =>
      {
        'success': false,
        'command': command,
        'data': const {},
        'error': {
          'code': code,
          'message': message,
          if (details != null) 'details': details,
        },
        'warnings': warnings,
        'meta': meta,
      };

  void _printHuman(final Map<String, dynamic> envelope) {
    if (envelope['success'] == true) {
      _out.writeln('Success: ${envelope['command']}');
      _out.writeln(
        const JsonEncoder.withIndent('  ').convert(envelope['data']),
      );
      final warnings = envelope['warnings'] as List<dynamic>?;
      if (warnings != null && warnings.isNotEmpty) {
        _out.writeln('Warnings:');
        for (final warning in warnings) {
          _out.writeln('- $warning');
        }
      }
    } else {
      final error = envelope['error'] as Map<String, dynamic>?;
      _err.writeln(
        'Error [${error?['code'] ?? 'unknown'}]: ${error?['message'] ?? 'Unknown error'}',
      );
      if (error?['details'] != null) {
        _err.writeln(error!['details']);
      }
    }
  }
}

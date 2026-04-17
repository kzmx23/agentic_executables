import 'dart:io';

import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;

/// Handles the `ae know <subcommand>` CLI. Extracted from cli.dart so that
/// deleting the know subsystem is a single-commit hard cut.
///
/// Task 4 will delete this file along with the know subsystem.

String? _hubOptionFromKnowCommand(final ArgResults knowCommand) {
  for (ArgResults? c = knowCommand; c != null; c = c.command) {
    if (!c.options.contains('hub')) continue;
    final h = c['hub']?.toString();
    if (h != null && h.isNotEmpty) return h;
  }
  return null;
}

Future<AeResult<Map<String, dynamic>>> handleKnowCommand(
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

/// Returns usage help for `ae know ...` subcommands. Returns null when the
/// key doesn't start with 'know'.
String? knowUsageHelpFor(final String key) {
  switch (key) {
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
    default:
      return null;
  }
}

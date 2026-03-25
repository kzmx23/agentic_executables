import 'dart:convert';
import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:path/path.dart' as path;

import 'adapter.dart';

/// MCP v3 thin adapter for Agentic Executables core services.
base class AgenticExecutablesMcpServer extends MCPServer with ToolsSupport {
  AgenticExecutablesMcpServer(
    super.channel, {
    final String? resourcesPath,
    final String? version,
  }) : super.fromStreamChannel(
          implementation: Implementation(
            name: 'agentic-executables-mcp',
            version: version ?? '3.0.0',
          ),
          instructions: '''
Agentic Executables MCP v3 (thin adapter over shared core).

TOOLS:
- ae_definition
- ae_instructions
- ae_generate
- ae_registry
- ae_verify
- ae_evaluate
- ae_hub
- ae_know
''',
        ) {
    _adapter =
        AeMcpAdapter(resourcesPath: resourcesPath ?? _defaultResourcesPath());

    registerTool(_toolDefinition(), _handleDefinition);
    registerTool(_toolInstructions(), _handleInstructions);
    registerTool(_toolGenerate(), _handleGenerate);
    registerTool(_toolRegistry(), _handleRegistry);
    registerTool(_toolVerify(), _handleVerify);
    registerTool(_toolEvaluate(), _handleEvaluate);
    registerTool(_toolHub(), _handleHub);
    registerTool(_toolKnow(), _handleKnow);
  }

  late final AeMcpAdapter _adapter;

  String _defaultResourcesPath() {
    final executable = Platform.resolvedExecutable;
    final execDir = path.dirname(executable);

    var resourcesDir = path.join(execDir, '..', 'resources');
    if (Directory(resourcesDir).existsSync()) {
      return path.normalize(resourcesDir);
    }

    resourcesDir = path.join(Directory.current.path, 'resources');
    if (Directory(resourcesDir).existsSync()) {
      return path.normalize(resourcesDir);
    }

    resourcesDir = path.join(
      path.dirname(Platform.script.toFilePath()),
      '..',
      '..',
      'resources',
    );
    return path.normalize(resourcesDir);
  }

  Tool _toolDefinition() => Tool(
        name: 'ae_definition',
        description: 'Get core AE definition and framework overview.',
        inputSchema: Schema.object(properties: {}),
      );

  Tool _toolInstructions() => Tool(
        name: 'ae_instructions',
        description:
            'Retrieve AE instructions for context (library/project) and action.',
        inputSchema: Schema.object(
          properties: {
            'context_type': Schema.string(
              enumValues: ['library', 'project'],
            ),
            'action': Schema.string(
              enumValues: [
                'bootstrap',
                'install',
                'uninstall',
                'update',
                'use'
              ],
            ),
            'know_name': Schema.string(),
          },
          required: ['context_type', 'action'],
        ),
      );

  Tool _toolGenerate() => Tool(
        name: 'ae_generate',
        description:
            'Generate AE files using auto|template engine selection (auto resolves to template in MCP).',
        inputSchema: Schema.object(
          properties: {
            'library_id': Schema.string(),
            'library_root': Schema.string(),
            'output_dir': Schema.string(),
            'engine': Schema.string(
              enumValues: ['auto', 'template'],
            ),
            'dry_run': Schema.bool(),
            'know_name': Schema.string(),
          },
          required: ['library_id', 'library_root'],
        ),
      );

  Tool _toolRegistry() => Tool(
        name: 'ae_registry',
        description:
            'Registry operations: submit_to_registry, get_from_registry, bootstrap_local_registry.',
        inputSchema: Schema.object(
          properties: {
            'operation': Schema.string(
              enumValues: [
                'submit_to_registry',
                'get_from_registry',
                'bootstrap_local_registry',
              ],
            ),
            'library_url': Schema.string(),
            'library_id': Schema.string(),
            'ae_use_files': Schema.string(),
            'action': Schema.string(
              enumValues: ['install', 'uninstall', 'update', 'use'],
            ),
            'ae_use_path': Schema.string(),
          },
          required: ['operation'],
        ),
      );

  Tool _toolVerify() => Tool(
        name: 'ae_verify',
        description:
            'Verify AE implementation using typed checklist input. Legacy string-encoded JSON payloads are rejected.',
        inputSchema: Schema.object(
          properties: {
            'context_type': Schema.string(
              enumValues: ['library', 'project'],
            ),
            'action': Schema.string(
              enumValues: [
                'bootstrap',
                'install',
                'uninstall',
                'update',
                'use'
              ],
            ),
            'files_modified': Schema.list(
              items: Schema.object(
                properties: {
                  'path': Schema.string(),
                  'loc': Schema.int(),
                  'sections': Schema.list(items: Schema.string()),
                },
                required: ['path', 'loc'],
                additionalProperties: false,
              ),
            ),
            'checklist_completed': Schema.object(
              additionalProperties: Schema.bool(),
            ),
          },
          required: ['context_type', 'action'],
        ),
      );

  Tool _toolEvaluate() => Tool(
        name: 'ae_evaluate',
        description:
            'Evaluate AE compliance using typed payload fields. Legacy string-encoded JSON payloads are rejected.',
        inputSchema: Schema.object(
          properties: {
            'context_type': Schema.string(
              enumValues: ['library', 'project'],
            ),
            'action': Schema.string(
              enumValues: [
                'bootstrap',
                'install',
                'uninstall',
                'update',
                'use'
              ],
            ),
            'files_created': Schema.list(
              items: Schema.object(
                properties: {
                  'path': Schema.string(),
                  'loc': Schema.int(),
                },
                required: ['path', 'loc'],
                additionalProperties: false,
              ),
            ),
            'sections_present': Schema.list(items: Schema.string()),
            'validation_steps_exists': Schema.bool(),
            'integration_points_defined': Schema.bool(),
            'reversibility_included': Schema.bool(),
            'has_meta_rules': Schema.bool(),
          },
          required: ['context_type', 'action'],
        ),
      );

  Tool _toolHub() => Tool(
        name: 'ae_hub',
        description: 'Hub management: init, status, pull, push.',
        inputSchema: Schema.object(
          properties: {
            'operation': Schema.string(
              enumValues: ['init', 'status', 'pull', 'push'],
            ),
            'path': Schema.string(),
            'project': Schema.bool(),
            'hub_path': Schema.string(),
            'remote': Schema.string(),
            'library_id': Schema.string(),
            'type': Schema.string(
              enumValues: ['know', 'use', 'packages'],
            ),
          },
          required: ['operation'],
        ),
      );

  Tool _toolKnow() => Tool(
        name: 'ae_know',
        description:
            'Knowledge extraction: build, list, show, remove, update, diff; matrix_init, matrix_scaffold, matrix_compare, plan.',
        inputSchema: Schema.object(
          properties: {
            'operation': Schema.string(
              enumValues: [
                'build',
                'list',
                'show',
                'remove',
                'update',
                'diff',
                'matrix_init',
                'matrix_scaffold',
                'matrix_compare',
                'plan',
              ],
            ),
            'name': Schema.string(),
            'url': Schema.string(),
            'local_path': Schema.string(
              description: 'Local file path (use instead of url/repo)',
            ),
            'repo': Schema.string(),
            'format': Schema.string(
              enumValues: ['auto', 'llms_txt', 'html', 'markdown', 'pdf'],
            ),
            'on_conflict': Schema.string(
              enumValues: ['reuse', 'update', 'fail', 'new_version'],
            ),
            'from_name': Schema.string(),
            'to_name': Schema.string(),
            'from_file': Schema.string(),
            'to_file': Schema.string(),
            'columns': Schema.list(
              items: Schema.string(),
              description: 'Matrix column ids (matrix_init)',
            ),
            'title': Schema.string(),
            'normative_kind': Schema.string(),
            'normative_ref': Schema.string(),
            'repo_path': Schema.string(),
            'out_file': Schema.string(),
            'hub_path': Schema.string(),
          },
          required: ['operation'],
        ),
      );

  Future<CallToolResult> _handleHub(final CallToolRequest request) async {
    final result = await _adapter.hub(request.arguments ?? {});
    return _result(result);
  }

  Future<CallToolResult> _handleKnow(final CallToolRequest request) async {
    final result = await _adapter.know(request.arguments ?? {});
    return _result(result);
  }

  Future<CallToolResult> _handleDefinition(
      final CallToolRequest request) async {
    final result = await _adapter.definition(request.arguments ?? {});
    return _result(result);
  }

  Future<CallToolResult> _handleInstructions(
    final CallToolRequest request,
  ) async {
    final result = await _adapter.instructions(request.arguments ?? {});
    return _result(result);
  }

  Future<CallToolResult> _handleGenerate(final CallToolRequest request) async {
    final result = await _adapter.generate(request.arguments ?? {});
    return _result(result);
  }

  Future<CallToolResult> _handleRegistry(final CallToolRequest request) async {
    final result = await _adapter.registry(request.arguments ?? {});
    return _result(result);
  }

  Future<CallToolResult> _handleVerify(final CallToolRequest request) async {
    final result = await _adapter.verify(request.arguments ?? {});
    return _result(result);
  }

  Future<CallToolResult> _handleEvaluate(final CallToolRequest request) async {
    final result = await _adapter.evaluate(request.arguments ?? {});
    return _result(result);
  }

  CallToolResult _result(final Map<String, dynamic> payload) => CallToolResult(
        content: [
          TextContent(text: jsonEncode(payload)),
        ],
      );
}

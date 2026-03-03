import 'dart:convert';
import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:path/path.dart' as path;

import 'adapter.dart';

/// MCP v2 thin adapter for Agentic Executables core services.
base class AgenticExecutablesMcpServer extends MCPServer with ToolsSupport {
  AgenticExecutablesMcpServer(
    super.channel, {
    final String? resourcesPath,
    final String? version,
  }) : super.fromStreamChannel(
          implementation: Implementation(
            name: 'agentic-executables-mcp',
            version: version ?? '2.0.0',
          ),
          instructions: '''
Agentic Executables MCP v2 (thin adapter over shared core).

TOOLS:
- ae_definition
- ae_instructions
- ae_generate
- ae_registry
- ae_verify
- ae_evaluate
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
          },
          required: ['context_type', 'action'],
        ),
      );

  Tool _toolGenerate() => Tool(
        name: 'ae_generate',
        description:
            'Generate AE files using auto|codex|template engine selection.',
        inputSchema: Schema.object(
          properties: {
            'library_id': Schema.string(),
            'library_root': Schema.string(),
            'output_dir': Schema.string(),
            'engine': Schema.string(
              enumValues: ['auto', 'codex', 'template'],
            ),
            'dry_run': Schema.boolean(),
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
            'Verify AE implementation using structured checklist input.',
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
            'files_modified': Schema.string(),
            'checklist_completed': Schema.string(),
          },
          required: ['context_type', 'action'],
        ),
      );

  Tool _toolEvaluate() => Tool(
        name: 'ae_evaluate',
        description: 'Evaluate AE compliance with objective metrics.',
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
            'files_created': Schema.string(),
            'sections_present': Schema.string(),
            'validation_steps_exists': Schema.string(),
            'integration_points_defined': Schema.string(),
            'reversibility_included': Schema.string(),
            'has_meta_rules': Schema.string(),
          },
          required: ['context_type', 'action'],
        ),
      );

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

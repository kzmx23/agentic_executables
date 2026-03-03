import 'dart:io';

import 'package:agentic_executables_mcp/src/server.dart';
import 'package:dart_mcp/stdio.dart';

Future<void> main(final List<String> args) async {
  stderr.writeln('Agentic Executables MCP Server v2 starting...');

  try {
    AgenticExecutablesMcpServer(
      stdioChannel(input: stdin, output: stdout),
      version: '2.0.0',
    );

    stderr.writeln('Server started successfully.');
  } catch (error, stack) {
    stderr.writeln('Error starting server: $error');
    stderr.writeln('Stack trace: $stack');
    exit(1);
  }
}

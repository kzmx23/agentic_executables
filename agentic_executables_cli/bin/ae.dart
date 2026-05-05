import 'dart:io';

import 'package:agentic_executables_cli/src/cli.dart';

Future<void> main(final List<String> args) async {
  final exit = await AeCli().run(args);
  exitCode = exit;
}

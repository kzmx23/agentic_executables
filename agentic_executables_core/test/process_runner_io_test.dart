import 'package:agentic_executables_core/agentic_executables_core.dart';
import 'package:test/test.dart';

void main() {
  group('ProcessRunnerIo', () {
    const runner = ProcessRunnerIo();

    test('echoes stdin to stdout via cat', () async {
      final result = await runner.run(
        executable: 'cat',
        arguments: const [],
        stdinInput: 'hello world',
      );
      expect(result.exitCode, 0);
      expect(result.stdout, 'hello world');
    });

    test('captures non-zero exit code', () async {
      final result = await runner.run(
        executable: 'sh',
        arguments: const ['-c', 'exit 7'],
      );
      expect(result.exitCode, 7);
    });

    test('captures stderr separately', () async {
      final result = await runner.run(
        executable: 'sh',
        arguments: const ['-c', 'echo err 1>&2'],
      );
      expect(result.stdout, '');
      expect(result.stderr.trim(), 'err');
    });
  });
}

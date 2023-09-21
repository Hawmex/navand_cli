import 'package:navand_cli/src/command_runner.dart';

Future<void> main(final List<String> args) async {
  return await CommandRunner().run(args);
}

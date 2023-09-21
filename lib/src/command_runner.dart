import 'dart:io' as io;

import 'package:args/args.dart' as args;
import 'package:args/command_runner.dart' as args_command_runner;

import 'commands/build.dart';
import 'commands/create.dart';
import 'commands/serve.dart';
import 'version.dart';

final class CommandRunner extends args_command_runner.CommandRunner<void> {
  CommandRunner() : super('navand', 'Manage your Navand app development.') {
    argParser.addFlag(
      'version',
      help: 'Print Navand\'s CLI version.',
      negatable: false,
    );

    addCommand(CreateCommand());
    addCommand(ServeCommand());
    addCommand(BuildCommand());
  }

  @override
  Future<void> run(final Iterable<String> args) async {
    try {
      return await super.run(args);
    } on args_command_runner.UsageException catch (e) {
      print('${e.message}\n\n${e.usage}');
      io.exit(1);
    } catch (e, st) {
      print('\n$e\n\n$st');
      io.exit(1);
    }
  }

  @override
  Future<void> runCommand(final args.ArgResults topLevelResults) async {
    final shouldPrintVersion = topLevelResults['version'] as bool;

    if (shouldPrintVersion) {
      print('Navand\'s CLI version: $version');
      io.exit(0);
    }

    return await super.runCommand(topLevelResults);
  }
}

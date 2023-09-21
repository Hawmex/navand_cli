import 'dart:io' as io;

import 'package:args/command_runner.dart' as args_command_runner;

abstract base class CommandBase extends args_command_runner.Command<void> {
  final _activeProcesses = <io.Process>{};

  late final verbose = argResults!['verbose'] as bool;

  CommandBase() {
    argParser.addFlag(
      'verbose',
      abbr: 'v',
      help: 'Enable verbose logging.',
      negatable: false,
    );
  }

  @override
  String get invocation => 'navand';

  @override
  Future<void> run() async {
    io.ProcessSignal.sigint
        .watch()
        .listen((final signal) async => await _shutDown());
  }

  void addProcess(final io.Process process) {
    _activeProcesses.add(process);
  }

  Future<void> willShutDown() async {}

  Future<void> _shutDown() async {
    for (final process in _activeProcesses) {
      process.kill();
    }

    await willShutDown();

    io.exit(1);
  }
}

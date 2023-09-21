// ignore_for_file: implementation_imports

import 'dart:async';

import 'package:dwds/data/build_result.dart' as dwds_build_result;
import 'package:dwds/dwds.dart' as dwds;
import 'package:webdev/src/command/configuration.dart' as webdev_configuration;
import 'package:webdev/src/serve/dev_workflow.dart' as webdev_dev_workflow;

import '../command_base.dart';
import '../logger.dart';

final class ServeCommand extends CommandBase {
  webdev_dev_workflow.DevWorkflow? _workflow;

  late final _address = argResults!['address'] as String;
  late final _port = int.parse(argResults!['port'] as String);

  ServeCommand() {
    argParser.addOption(
      'address',
      abbr: 'a',
      defaultsTo: 'localhost',
      help: 'The server\'s address.',
    );

    argParser.addOption(
      'port',
      abbr: 'p',
      defaultsTo: '8080',
      help: 'The server\'s port.',
    );
  }

  @override
  String get name => 'serve';

  @override
  String get description => 'Start your application in development mode.';

  @override
  String get invocation => '${super.invocation} serve';

  @override
  Future<void> run() async {
    await super.run();

    configureWebdevLogWriter(verbose: verbose);

    await logTask(
      task: () async {
        _workflow = await webdev_dev_workflow.DevWorkflow.start(
          webdev_configuration.Configuration(
            hostname: _address,
            reload: dwds.ReloadConfiguration.hotRestart,
          ),
          ['--delete-conflicting-outputs', '--verbose'],
          {'web': _port},
        );
      },
      message: 'Starting the dev workflow and serving `web` on '
          'http://$_address:$_port',
      source: LogSource.navand,
      showProgress: !verbose,
    );

    Completer<void>? buildCompleter;

    await _workflow!.serverManager.servers.first.buildResults.forEach(
      (final buildResult) async {
        switch (buildResult.status) {
          case dwds_build_result.BuildStatus.started:
            final action = buildCompleter == null ? 'Building' : 'Rebuilding';

            buildCompleter = Completer();

            await logTask(
              task: () async => await buildCompleter!.future,
              message: '$action the application',
              source: LogSource.navand,
              showProgress: !verbose,
            );

            break;
          case dwds_build_result.BuildStatus.succeeded:
            buildCompleter!.complete();
            break;
          case dwds_build_result.BuildStatus.failed:
            buildCompleter!.completeError('Could not build the application.');
        }
      },
    );
  }

  @override
  Future<void> willShutDown() async {
    await super.willShutDown();
    await _workflow?.shutDown();
  }
}

// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:io' as io;

import 'package:build_daemon/client.dart' as build_client;
import 'package:build_daemon/data/build_status.dart' as build_status;
import 'package:build_daemon/data/build_target.dart' as build_target;
import 'package:collection/collection.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart' as shelf_static;
import 'package:webdev/src/daemon_client.dart' as daemon_client;

import '../command_base.dart';
import '../logger.dart';

final class BuildCommand extends CommandBase {
  build_client.BuildDaemonClient? _client;
  io.HttpServer? _server;

  late final _noServe = argResults!['no-serve'] as bool;
  late final _address = argResults!['address'] as String;
  late final _port = int.parse(argResults!['port'] as String);

  BuildCommand() : super() {
    argParser.addFlag(
      'no-serve',
      negatable: false,
      abbr: 'n',
      help: 'Don\'t serve the production-ready output.',
    );

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
  String get name => 'build';

  @override
  String get description =>
      'Compile your application for production use and serve it locally.';

  @override
  String get invocation => '${super.invocation} build';

  @override
  Future<void> run() async {
    await super.run();

    await logTask(
      task: () async {
        _client = await daemon_client.connectClient(
          io.Directory.current.path,
          ['--release', '--delete-conflicting-outputs', '--verbose'],
          (final serverLog) => handleServerLog(serverLog, verbose: verbose),
        );
      },
      message: 'Connecting to the build daemon',
      source: LogSource.navand,
      showProgress: !verbose,
    );

    _client!.registerBuildTarget(
      build_target.DefaultBuildTarget(
        (final build) => build
          ..target = 'web'
          ..outputLocation = build_target.OutputLocation(
            (final build) => build
              ..output = 'build'
              ..useSymlinks = false
              ..hoist = true,
          ).toBuilder(),
      ),
    );

    _client!.startBuild();

    bool gotBuildStart = false;

    await logTask(
      task: () async {
        await for (final result in _client!.buildResults) {
          final targetResult = result.results.firstWhereOrNull(
            (final buildResult) => buildResult.target == 'web',
          );

          if (targetResult == null) continue;

          gotBuildStart = gotBuildStart ||
              targetResult.status == build_status.BuildStatus.started;

          if (!gotBuildStart) continue;
          if (targetResult.status == build_status.BuildStatus.started) continue;

          if (targetResult.status == build_status.BuildStatus.failed) {
            throw targetResult.error!;
          }

          break;
        }
      },
      message: 'Building the application',
      source: LogSource.navand,
      showProgress: !verbose,
    );

    await logTask(
      task: () async => await _client!.close(),
      message: 'Disconnecting from the build daemon',
      source: LogSource.navand,
    );

    if (_noServe) io.exit(0);

    await logTask(
      task: () async {
        final staticHandler = shelf_static.createStaticHandler(
          'build',
          defaultDocument: 'index.html',
        );

        FutureOr<shelf.Response> notFoundHandler(final shelf.Request req) {
          final indexRequest = shelf.Request(
            'GET',
            req.requestedUri.replace(path: '/'),
            context: req.context,
            encoding: req.encoding,
            headers: req.headers,
            protocolVersion: req.protocolVersion,
          );

          return staticHandler(indexRequest);
        }

        final cascade = shelf.Cascade().add(staticHandler).add(notFoundHandler);

        _server = await shelf_io.serve(cascade.handler, _address, _port);
      },
      message: 'Serving `build` on http://$_address:$_port',
      source: LogSource.navand,
    );
  }

  @override
  Future<void> willShutDown() async {
    await super.willShutDown();
    await _server?.close(force: true);
  }
}

// ignore_for_file: implementation_imports

import 'dart:async';
import 'dart:io' as io;

import 'package:build_daemon/data/server_log.dart' as build_daemon_server_log;
import 'package:io/ansi.dart' as ansi;
import 'package:logging/logging.dart' as logging;
import 'package:webdev/src/logging.dart' as webdev_logging;

enum LogSource {
  navand('NAVAND', ansi.lightCyan),
  builder('BUILDER', ansi.lightMagenta);

  final String name;
  final ansi.AnsiCode color;

  const LogSource(this.name, this.color);
}

enum _LogStatus {
  inProgress,
  hasError,
  done,
}

const _clearLine = '\u001b[2K';
const _carriageReturn = '\r';
const _invisibleCursor = '\u001b[?25l';

Future<void> logTask({
  required final Future<void> Function() task,
  required final String message,
  required final LogSource source,
  final bool endWithLineBreak = true,
  final bool showProgress = true,
}) async {
  const progressIndicatorFrames = {
    '⠋',
    '⠙',
    '⠹',
    '⠸',
    '⠼',
    '⠴',
    '⠦',
    '⠧',
    '⠇',
    '⠏',
  };

  final stopwatch = Stopwatch();
  final wrappedSource = source.color.wrap('[${source.name}] ');
  final wrappedMessage = message.trim();

  String getElapsedTime() {
    final elapsedTime =
        (stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1);

    return ansi.darkGray.wrap('(${elapsedTime}s)')!;
  }

  _LogStatus status = _LogStatus.inProgress;

  Object? error;
  StackTrace? stackTrace;

  io.stdout.writeAll([_invisibleCursor, _clearLine, _carriageReturn]);
  stopwatch.start();

  task().then((final _) {
    stopwatch.stop();
    status = _LogStatus.done;
  }).catchError((final Object? e, final StackTrace st) {
    stopwatch.stop();
    status = _LogStatus.hasError;
    error = e;
    stackTrace = st;
  });

  int progressIndicatorFrameIndex = 0;

  do {
    if (showProgress) {
      final progressIndicatorFrame = progressIndicatorFrames.elementAt(
        progressIndicatorFrameIndex % progressIndicatorFrames.length,
      );

      io.stdout.writeAll([
        _carriageReturn,
        ansi.green.wrap('$progressIndicatorFrame '),
        wrappedSource,
        '$wrappedMessage... ',
        getElapsedTime(),
      ]);

      progressIndicatorFrameIndex++;
    }

    await Future<void>.delayed(const Duration(milliseconds: 40));
  } while (status == _LogStatus.inProgress);

  if (status == _LogStatus.hasError) {
    io.stdout.writeAll([
      _clearLine,
      _carriageReturn,
      ansi.lightRed.wrap('x '),
      wrappedSource,
      '$wrappedMessage. ',
      getElapsedTime(),
      '\n',
    ]);

    Error.throwWithStackTrace(error!, stackTrace!);
  }

  if (status == _LogStatus.done) {
    io.stdout.writeAll([
      _clearLine,
      _carriageReturn,
      ansi.lightGreen.wrap('✓ '),
      wrappedSource,
      '$wrappedMessage. ',
      getElapsedTime(),
      if (endWithLineBreak) '\n',
    ]);
  }
}

void _customLogWriter({
  required final bool verbose,
  required final String message,
  required final dynamic level,
  required final String? error,
}) {
  if (!verbose) return;

  final buffer = StringBuffer(message);

  if (error != null) buffer.write(error);

  final log = buffer.toString().trim();

  if (log.isEmpty || RegExp(r'^(-){1,}$').hasMatch(log)) return;

  final prefix = LogSource.builder.color.wrap('[${LogSource.builder.name}] ');

  final isError = level is logging.Level
      ? level >= logging.Level.SEVERE
      : (level as build_daemon_server_log.Level) >=
          build_daemon_server_log.Level.SEVERE;

  final secondPrefix = isError ? ansi.lightRed.wrap('[ERROR] ') : '';

  for (final line in log.split('\n')) {
    io.stdout.writeAll([
      prefix,
      secondPrefix,
      isError ? ansi.lightRed.wrap(line) : line,
      '\n',
    ]);
  }
}

void handleServerLog(
  final build_daemon_server_log.ServerLog serverLog, {
  required final bool verbose,
}) {
  _customLogWriter(
    verbose: verbose,
    message: serverLog.message,
    level: serverLog.level,
    error: serverLog.error,
  );
}

void configureWebdevLogWriter({required final bool verbose}) {
  webdev_logging.configureLogWriter(
    true,
    customLogWriter: (
      final level,
      final message, {
      final error,
      final loggerName,
      final stackTrace,
    }) {
      _customLogWriter(
        verbose: verbose,
        message: message,
        level: level,
        error: error,
      );
    },
  );
}

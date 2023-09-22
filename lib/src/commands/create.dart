import 'dart:convert' as convert;
import 'dart:io' as io;

import '../command_base.dart';
import '../logger.dart';
import '../utils/dependency.dart';
import '../utils/file.dart';

final class CreateCommand extends CommandBase {
  final _dependencies = const {
    Dependency('navand'),
  };

  final _devDependencies = const {
    Dependency('lints', dev: true),
    Dependency('build_runner', dev: true),
    Dependency('build_web_compilers', dev: true),
  };

  late final _files = {
    const File(
      path: './.gitignore',
      body: '''
.dart_tool/
build/
''',
    ),
    File(
      path: './README.md',
      body: '''
# $_appName

A [Navand](https://pub.dev/documentation/navand) App.

## Serve Your App

```
navand serve
```
''',
    ),
    File(
      path: './pubspec.yaml',
      body: '''
name: $_appName
description: >
  A Navand app.
publish_to: none
environment:
  sdk: ^3.1.0
''',
    ),
    const File(
      path: './analysis_options.yaml',
      body: '''
include: package:lints/recommended.yaml

linter:
  rules:
    prefer_const_constructors: true
    prefer_const_declarations: true
    prefer_final_locals: true
    prefer_final_in_for_each: true
    prefer_final_parameters: true
    prefer_relative_imports: true
    avoid_print: true
    comment_references: true

analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
''',
    ),
    File(
      path: './web/index.html',
      body: '''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />

    <title>$_appName</title>

    <link
      rel="shortcut icon"
      href="https://raw.githubusercontent.com/Hawmex/Hawmex/main/assets/icon.svg"
      type="image/x-icon"
    />

    <link rel="stylesheet" href="/styles.css" />

    <script src="/main.dart.js" defer></script>
  </head>

  <body>
    <noscript>You need to enable JavaScript to run this app!</noscript>
  </body>
</html>
''',
    ),
    File(
      path: './web/main.dart',
      body: '''
import 'package:navand/navand.dart';
import 'package:$_appName/app.dart';

void main() => runApp(const App());
''',
    ),
    const File(
      path: './web/styles.css',
      body: '''
*,
*::before,
*::after {
  margin: 0px;
  padding: 0px;
  -webkit-tap-highlight-color: transparent;
  box-sizing: border-box;
}
''',
    ),
    const File(
      path: './lib/app.dart',
      body: '''
import 'package:navand/navand.dart';

import 'widgets/greeting.dart';
import 'widgets/logo.dart';

final class App extends StatelessWidget {
  const App({super.key, super.ref});

  @override
  Widget build(final BuildContext context) {
    return const DomWidget(
      'div',
      style: Style({
        'display': 'flex',
        'flex-flow': 'column',
        'justify-content': 'center',
        'text-align': 'center',
        'align-items': 'center',
        'gap': '16px',
        'padding': '16px',
        'width': '100%',
        'min-height': '100vh',
        'background': '#0d1117',
        'color': '#ffffff',
        'font-family': 'system-ui',
        'user-select': 'none',
      }),
      children: [
        Logo(),
        Greeting(),
      ],
    );
  }
}
''',
    ),
    const File(
      path: './lib/widgets/greeting.dart',
      body: '''
import 'package:navand/navand.dart';

final class Greeting extends StatelessWidget {
  const Greeting({super.key, super.ref});

  @override
  Widget build(final BuildContext context) {
    return const Fragment(
      [
        DomWidget(
          'span',
          style: Style({
            'font-size': '24px',
            'font-weight': 'bold',
            'color': '#00e690',
          }),
          children: [
            Text('Welcome to Navand!'),
          ],
        ),
        DomWidget(
          'div',
          children: [
            Text('To get started, edit '),
            DomWidget(
              'span',
              style: Style({
                'font-family': 'monospace',
                'background': '#212121',
                'border-radius': '4px',
                'padding': '4px',
              }),
              children: [
                Text('web/main.dart'),
              ],
            ),
            Text(' and save to reload.'),
          ],
        )
      ],
    );
  }
}
''',
    ),
    const File(
      path: './lib/widgets/logo.dart',
      body: '''
import 'package:navand/navand.dart';

final class Logo extends StatelessWidget {
  const Logo({super.key, super.ref});

  @override
  Widget build(final BuildContext context) {
    return const DomWidget(
      'img',
      attributes: {
        'src':
            'https://raw.githubusercontent.com/Hawmex/Hawmex/main/assets/icon.svg'
      },
      style: Style({'width': '128px', 'height': '128px'}),
      animation: Animation(
        keyframes: [
          Keyframe(offset: 0, style: Style({'transform': 'translateY(0px)'})),
          Keyframe(offset: 1, style: Style({'transform': 'translateY(8px)'})),
        ],
        duration: Duration(seconds: 1),
        easing: Easing(0.2, 0, 0.4, 1),
        direction: AnimationDirection.alternate,
        iterations: double.infinity,
      ),
    );
  }
}
''',
    ),
  };

  bool _createdDirectory = false;
  io.Directory? _directory;

  late final _appName = argResults!.rest.first;

  @override
  String get name => 'create';

  @override
  String get description => 'Set up a new Navand application.';

  @override
  String get invocation => '${super.invocation} create <app_name>';

  @override
  Future<void> run() async {
    await super.run();

    if (argResults!.rest.isEmpty) {
      usageException('Please specify <app_name>.');
    }

    final regexForAppName = RegExp(r'^([a-z]){1}([a-z]|[0-9]|_){0,}$');

    if (!regexForAppName.hasMatch(_appName)) {
      usageException(
        '<app_name> can only include lowercase letters, digits, and '
        'underscores.\nIt can only start with a lowercase letter.',
      );
    }

    await logTask(
      task: () async {
        try {
          await _createDirectory();
          await _createFiles();
          await _installDependencies();
        } catch (e, st) {
          await _deleteDirectory();

          Error.throwWithStackTrace(e, st);
        }
      },
      message: 'Setting up $_appName',
      source: LogSource.navand,
      showProgress: false,
    );

    print(
      'Run the following commands:\n'
      '\tcd $_appName\n'
      '\tnavand serve',
    );

    io.exit(0);
  }

  Future<void> _deleteDirectory() async {
    if (_createdDirectory) {
      await logTask(
        task: () async => await _directory!.delete(recursive: true),
        message: 'Deleting $_appName directory',
        source: LogSource.navand,
      );
    }
  }

  Future<void> _createDirectory() async {
    await logTask(
      task: () async {
        _directory = io.Directory('./$_appName').absolute;

        if (await _directory!.exists()) {
          throw Exception('Directory "$_appName" already exists.');
        }

        await _directory!.create();

        _createdDirectory = true;

        io.Directory.current = _directory;
      },
      message: 'Creating $_appName directory',
      source: LogSource.navand,
    );
  }

  Future<void> _createFiles() async {
    await logTask(
      task: () async {
        for (final file in _files) {
          await logTask(
            task: () async => await file.create(),
            message: 'Creating ${file.path}',
            source: LogSource.navand,
            endWithLineBreak: verbose,
          );
        }
      },
      message: 'Creating files',
      source: LogSource.navand,
      showProgress: false,
    );
  }

  Future<void> _installDependencies() async {
    await logTask(
      task: () async {
        for (final dependency in _dependencies) {
          await logTask(
            task: () async {
              final process = await dependency.install();

              addProcess(process);

              if (await process.exitCode > 0) {
                throw convert.utf8.decode(await process.stderr.first);
              }
            },
            message: 'Installing ${dependency.name}',
            source: LogSource.navand,
            endWithLineBreak: verbose,
          );
        }
      },
      message: 'Installing dependencies',
      source: LogSource.navand,
      showProgress: false,
    );

    await logTask(
      task: () async {
        for (final devDependency in _devDependencies) {
          await logTask(
            task: () async {
              final process = await devDependency.install();

              addProcess(process);

              if (await process.exitCode > 0) {
                throw convert.utf8.decode(await process.stderr.first);
              }
            },
            message: 'Installing ${devDependency.name}',
            source: LogSource.navand,
            endWithLineBreak: verbose,
          );
        }
      },
      message: 'Installing dev dependencies',
      source: LogSource.navand,
      showProgress: false,
    );
  }
}

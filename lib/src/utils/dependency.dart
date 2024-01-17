import 'dart:io' as io;

final class Dependency {
  final String name;
  final bool dev;

  const Dependency(this.name, {this.dev = false});

  Future<io.Process> install() async {
    final process = await io.Process.start(
      'dart',
      ['pub', 'add', if (dev) '-d', name],
    );

    // TODO(@Hawmex): Why does this solve the problem of getting stuck at "Installing build_runner..."?
    process.stdout.forEach((final element) {});

    return process;
  }
}

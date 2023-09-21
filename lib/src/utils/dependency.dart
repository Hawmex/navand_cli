import 'dart:io' as io;

final class Dependency {
  final String name;
  final bool dev;

  const Dependency(this.name, {this.dev = false});

  Future<io.Process> install() async {
    return await io.Process.start(
      'dart',
      ['pub', 'add', if (dev) '-d', name],
    );
  }
}

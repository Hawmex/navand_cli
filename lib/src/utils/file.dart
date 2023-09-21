import 'dart:io' as io;

final class File {
  final String path;
  final String body;

  const File({required this.path, required this.body});

  Future<void> create() async {
    final file = io.File(path);

    await file.create(recursive: true);
    await file.writeAsString(body);
  }
}

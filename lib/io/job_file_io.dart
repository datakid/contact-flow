import 'dart:io';
import 'dart:typed_data';

Future<int?> jobFileLength(String path) async {
  try {
    return await File(path).length();
  } catch (_) {
    return null;
  }
}

Uint8List? takeJobFile(String path) {
  final file = File(path);
  try {
    return file.readAsBytesSync();
  } catch (_) {
    return null;
  } finally {
    try {
      file.deleteSync();
    } catch (_) {}
  }
}

Future<void> dropJobFile(String path) async {
  try {
    await File(path).delete();
  } catch (_) {}
}

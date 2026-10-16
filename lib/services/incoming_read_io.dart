import 'dart:io';
import 'dart:typed_data';

Future<Uint8List?> takeFileBytes(String path) async {
  final file = File(path);
  try {
    return await file.readAsBytes();
  } catch (_) {
    return null;
  } finally {
    try {
      await file.delete();
    } catch (_) {}
  }
}

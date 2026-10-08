import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<String?> saveBytes(Uint8List bytes, String name, String mime) async {
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : null;
  try {
    return await FilePicker.saveFile(
      fileName: name,
      bytes: bytes,
      type: ext == null ? FileType.any : FileType.custom,
      allowedExtensions: ext == null ? null : [ext],
    );
  } catch (_) {
    return FilePicker.saveFile(fileName: name, bytes: bytes);
  }
}

Future<bool> shareBytes(Uint8List bytes, String name, String mime) async {
  final base = await getTemporaryDirectory();
  final dir = Directory('${base.path}/share');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  final f = File('${dir.path}/$name');
  await f.writeAsBytes(bytes, flush: true);
  final r = await SharePlus.instance.share(
    ShareParams(
      files: [XFile(f.path, mimeType: mime, name: name)],
      subject: name,
    ),
  );
  return r.status != ShareResultStatus.unavailable;
}

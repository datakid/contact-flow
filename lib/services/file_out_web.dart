import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<String?> saveBytes(Uint8List bytes, String name, String mime) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = name
    ..style.display = 'none';
  web.document.body?.append(a);
  a.click();
  a.remove();
  Future.delayed(
    const Duration(seconds: 2),
    () => web.URL.revokeObjectURL(url),
  );
  return name;
}

Future<bool> shareBytes(Uint8List bytes, String name, String mime) async {
  await saveBytes(bytes, name, mime);
  return true;
}

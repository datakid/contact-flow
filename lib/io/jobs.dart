import 'package:flutter/foundation.dart';

import '../models/person.dart';
import 'codec.dart';

/// Background-isolate jobs.
///
/// IMPORTANT: everything passed to [compute] must be a top-level (or static)
/// function plus a plain message. Closures created inside async methods
/// capture the async frame (including its `_AsyncCompleter`), which cannot be
/// sent to another isolate and crashes with
/// "Illegal argument in isolate message".
class EncodeJob {
  final List<Person> people;
  final Format format;
  final ExportOptions options;
  final List<String>? headers;
  const EncodeJob(this.people, this.format, this.options, this.headers);
}

class DecodeJob {
  final String name;
  final Uint8List bytes;
  const DecodeJob(this.name, this.bytes);
}

Uint8List runEncode(EncodeJob j) =>
    Codec.encode(j.people, j.format, j.options, headers: j.headers);

ImportResult runDecode(DecodeJob j) => Codec.decode(j.name, j.bytes);

/// Small books are faster on the main isolate (no copy cost); big ones go to
/// a background isolate so the UI stays smooth.
Future<Uint8List> encodeInBackground(EncodeJob j) async {
  if (kIsWeb || j.people.length < 400) return runEncode(j);
  return compute(runEncode, j);
}

Future<ImportResult> decodeInBackground(DecodeJob j) async {
  if (kIsWeb || j.bytes.length < 64 * 1024) return runDecode(j);
  return compute(runDecode, j);
}

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/person.dart';
import 'cancel_token.dart';
import 'codec.dart';
import 'isolate_run.dart';
import 'job_file_stub.dart' if (dart.library.io) 'job_file_io.dart';

class EncodeJob {
  final List<Person> people;
  final Format format;
  final ExportOptions options;
  final List<String>? headers;
  final Map<String, List<String>>? tags;
  const EncodeJob(
    this.people,
    this.format,
    this.options,
    this.headers, [
    this.tags,
  ]);
}

class DecodeJob {
  final String name;
  final Uint8List bytes;
  final String? path;
  const DecodeJob(this.name, this.bytes) : path = null;
  DecodeJob.file(this.name, String this.path) : bytes = Uint8List(0);
}

Uint8List runEncode(EncodeJob j) => Codec.encode(
  j.people,
  j.format,
  j.options,
  headers: j.headers,
  tags: j.tags,
);

ImportResult runDecode(DecodeJob j) {
  final path = j.path;
  if (path == null) return Codec.decode(j.name, j.bytes);
  final bytes = takeJobFile(path);
  if (bytes == null) return ImportResult.failed(j.name);
  return Codec.decode(j.name, bytes);
}

Future<Uint8List> encodeInBackground(EncodeJob j) async {
  if (kIsWeb || j.people.length < 400) return runEncode(j);
  return compute(runEncode, j);
}

const maxImportBytes = 64 * 1024 * 1024;

@visibleForTesting
bool decodeInIsolate = true;

Future<ImportResult> decodeInBackground(
  DecodeJob j, {
  CancelToken? cancel,
  Duration timeout = const Duration(seconds: 20),
}) async {
  final path = j.path;
  if (path != null) {
    final size = await jobFileLength(path);
    if (size == null) return ImportResult.failed(j.name);
    if (size > maxImportBytes) {
      await dropJobFile(path);
      return ImportResult.problem(j.name, ImportIssue.tooLarge);
    }
  } else if (j.bytes.length > maxImportBytes) {
    return ImportResult.problem(j.name, ImportIssue.tooLarge);
  }
  try {
    if (kIsWeb || !decodeInIsolate) {
      if (cancel != null && cancel.cancelled) throw const CancelledException();
      return runDecode(j);
    }
    return await runIsolated(runDecode, j, timeout: timeout, token: cancel);
  } on TimeoutException {
    return ImportResult.problem(j.name, ImportIssue.timedOut);
  } on CancelledException {
    return ImportResult.problem(j.name, ImportIssue.cancelled);
  } catch (_) {
    return ImportResult.failed(j.name);
  }
}

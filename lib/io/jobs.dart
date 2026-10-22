import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/person.dart';
import 'cancel_token.dart';
import 'codec.dart';
import 'isolate_run.dart';

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
  const DecodeJob(this.name, this.bytes);
}

Uint8List runEncode(EncodeJob j) =>
    Codec.encode(j.people, j.format, j.options, headers: j.headers, tags: j.tags);

ImportResult runDecode(DecodeJob j) => Codec.decode(j.name, j.bytes);

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
  if (j.bytes.length > maxImportBytes) {
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

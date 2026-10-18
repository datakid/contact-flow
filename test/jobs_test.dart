import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:contact_flow/io/cancel_token.dart';
import 'package:contact_flow/io/codec.dart';
import 'package:contact_flow/io/isolate_run.dart';
import 'package:contact_flow/io/jobs.dart';
import 'package:flutter_test/flutter_test.dart';

int double2(int x) => x * 2;

int spin(int ms) {
  final sw = Stopwatch()..start();
  while (sw.elapsedMilliseconds < ms) {}
  return ms;
}

int boom(int x) => throw StateError('bad input $x');

void main() {
  setUp(() => decodeInIsolate = true);
  tearDown(() => decodeInIsolate = false);

  test('runIsolated returns the result', () async {
    expect(await runIsolated(double2, 21), 42);
  });

  test('runIsolated reports an exception from the worker', () async {
    await expectLater(runIsolated(boom, 1), throwsA(isA<StateError>()));
  });

  test('runIsolated stops a job that runs too long', () async {
    final sw = Stopwatch()..start();
    await expectLater(
      runIsolated(spin, 60000, timeout: const Duration(milliseconds: 300)),
      throwsA(isA<TimeoutException>()),
    );
    expect(sw.elapsedMilliseconds, lessThan(5000));
  });

  test('runIsolated can be cancelled', () async {
    final token = CancelToken();
    final f = runIsolated(spin, 60000, token: token);
    Timer(const Duration(milliseconds: 200), token.cancel);
    await expectLater(f, throwsA(isA<CancelledException>()));
  });

  test('decodeInBackground decodes in a worker', () async {
    final bytes = Uint8List.fromList(
      utf8.encode('Name,Phone\nAnn,0551234567\nBob,0559876543\n'),
    );
    final r = await decodeInBackground(DecodeJob('x.csv', bytes));
    expect(r.people.length, 2);
  });

  test('decodeInBackground turns a timeout into an issue', () async {
    final bytes = Uint8List.fromList(utf8.encode('Name,Phone\nAnn,055\n'));
    final r = await decodeInBackground(
      DecodeJob('slow.csv', bytes),
      timeout: Duration.zero,
    );
    expect(r.issue, ImportIssue.timedOut);
    expect(r.fileName, 'slow.csv');
  });

  test('decodeInBackground turns a cancel into an issue', () async {
    final token = CancelToken()..cancel();
    final bytes = Uint8List.fromList(utf8.encode('Name,Phone\nAnn,055\n'));
    final r = await decodeInBackground(
      DecodeJob('x.csv', bytes),
      cancel: token,
    );
    expect(r.issue, ImportIssue.cancelled);
  });

  test('a file over the size limit is refused without decoding', () async {
    final big = Uint8List(maxImportBytes + 1);
    final r = await decodeInBackground(DecodeJob('big.csv', big));
    expect(r.issue, ImportIssue.tooLarge);
  });
}

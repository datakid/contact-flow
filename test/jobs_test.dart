import 'dart:async';
import 'dart:convert';
import 'dart:io';
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

  group('files read inside the job', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('jobfile'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('a file is decoded and removed', () async {
      final f = File('${dir.path}/in.csv')
        ..writeAsBytesSync(utf8.encode('Name,Phone\nAnn,0551234567\n'));
      final r = await decodeInBackground(DecodeJob.file('in.csv', f.path));
      expect(r.people.single.name, 'Ann');
      expect(f.existsSync(), isFalse);
    });

    test('the same works in a real isolate', () async {
      decodeInIsolate = true;
      final f = File('${dir.path}/in.csv')
        ..writeAsBytesSync(utf8.encode('Name,Phone\nBob,0551234567\n'));
      final r = await decodeInBackground(DecodeJob.file('in.csv', f.path));
      expect(r.people.single.name, 'Bob');
      expect(f.existsSync(), isFalse);
    });

    test('a missing file is a failure, not a crash', () async {
      final r = await decodeInBackground(
        DecodeJob.file('x.csv', '${dir.path}/missing.csv'),
      );
      expect(r.people, isEmpty);
      expect(r.issue, ImportIssue.unreadable);
    });

    test('a file over the limit is refused without being read', () async {
      final f = File('${dir.path}/big.bin');
      final raf = f.openSync(mode: FileMode.write)
        ..truncateSync(maxImportBytes + 1);
      raf.closeSync();
      final r = await decodeInBackground(DecodeJob.file('big.bin', f.path));
      expect(r.issue, ImportIssue.tooLarge);
      expect(f.existsSync(), isFalse);
    });
  });
}

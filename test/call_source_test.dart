import 'package:contact_flow/calls/call_models.dart';
import 'package:contact_flow/calls/call_source.dart';
import 'package:contact_flow/services/edition.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('contactflow/calls');

  List<Map<String, Object?>> rows(int from, int count) => [
    for (var i = 0; i < count; i++)
      {
        'number': '+96650${(from - i).toString().padLeft(7, '0')}',
        'date': from - i,
        'duration': 5,
        'type': 1,
        'name': '',
        'presentation': 1,
      },
  ];

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test('readAll pages by date until a short page', () async {
    final seen = <Object?>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'read');
          final before = (call.arguments as Map)['before'];
          seen.add(before);
          if (before == null) return rows(4500, 2000);
          if (before == 2501) return rows(2500, 2000);
          return rows(500, 500);
        });
    final progress = <int>[];
    final all = await ChannelCallSource().readAll(onPage: progress.add);
    expect(all.length, 4500);
    expect(seen, [null, 2501, 501]);
    expect(progress, [2000, 4000, 4500]);
    expect(all.first.dateMs, 4500);
    expect(all.last.dateMs, 1);
  });

  test('an empty log gives an empty list', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => <Object?>[]);
    expect(await ChannelCallSource().readAll(), isEmpty);
  });

  test('permission calls are forwarded', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return call.method == 'hasPermission' ? false : true;
        });
    final s = ChannelCallSource();
    expect(await s.hasPermission(), isFalse);
    expect(await s.request(), isTrue);
  });

  test('the fake source returns newest first and honours denial', () async {
    final fake = FakeCallSource([
      const CallRecord(number: '1', dateMs: 1),
      const CallRecord(number: '2', dateMs: 3),
      const CallRecord(number: '3', dateMs: 2),
    ]);
    expect((await fake.readAll()).map((c) => c.dateMs), [3, 2, 1]);
    fake.granted = false;
    await expectLater(fake.readAll(), throwsStateError);
  });

  group('edition check', () {
    test('matching builds pass', () {
      expect(Edition.mismatch('lite', calls: false), isNull);
      expect(Edition.mismatch('full', calls: true), isNull);
    });

    test('a full app with calls off is flagged', () {
      expect(Edition.mismatch('full', calls: false), 'full');
    });

    test('a lite app with calls on is flagged', () {
      expect(Edition.mismatch('lite', calls: true), 'lite');
    });

    test('no native answer (tests, web) is never a mismatch', () {
      expect(Edition.mismatch(null), isNull);
      expect(Edition.mismatch(''), isNull);
    });

    test('names follow the define', () {
      expect(Edition.dartName(calls: true), 'full');
      expect(Edition.dartName(calls: false), 'lite');
    });
  });
}

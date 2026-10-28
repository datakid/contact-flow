import 'package:contact_flow/calls/call_filter.dart';
import 'package:contact_flow/calls/call_grouper.dart';
import 'package:contact_flow/calls/call_models.dart';
import 'package:contact_flow/calls/call_naming.dart';
import 'package:contact_flow/calls/ignore_book.dart';
import 'package:contact_flow/calls/saved_numbers.dart';
import 'package:contact_flow/l10n.dart';
import 'package:contact_flow/models/person.dart';
import 'package:contact_flow/phone/phone_key.dart';
import 'package:contact_flow/tags/tag_store.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 10, 20, 12);
int daysAgo(int d) => now.subtract(Duration(days: d)).millisecondsSinceEpoch;

CallRecord call(
  String number, {
  int days = 1,
  int secs = 0,
  CallType type = CallType.incoming,
  String name = '',
  int presentation = 1,
}) => CallRecord(
  number: number,
  dateMs: daysAgo(days),
  durationSec: secs,
  type: type,
  cachedName: name,
  presentation: presentation,
);

List<CallGroup> group(
  List<CallRecord> calls, {
  List<Person> saved = const [],
  Set<String> ignored = const {},
  bool showHidden = false,
}) => CallGrouper.group(
  calls,
  saved: SavedNumbers.of(saved),
  ignored: ignored,
  showHidden: showHidden,
);

void main() {
  setUp(() => PhoneKey.useRegion('SA'));
  tearDown(() => PhoneKey.useRegion(''));

  group('records', () {
    test('Android call types map to ours', () {
      expect(CallRecord.typeFromAndroid(1), CallType.incoming);
      expect(CallRecord.typeFromAndroid(2), CallType.outgoing);
      expect(CallRecord.typeFromAndroid(3), CallType.missed);
      expect(CallRecord.typeFromAndroid(4), CallType.voicemail);
      expect(CallRecord.typeFromAndroid(5), CallType.rejected);
      expect(CallRecord.typeFromAndroid(6), CallType.blocked);
      expect(CallRecord.typeFromAndroid(99), CallType.other);
    });

    test('a channel map becomes a record', () {
      final r = CallRecord.fromMap({
        'number': '+966501234567',
        'date': 5,
        'duration': 7,
        'type': 3,
        'name': 'X',
        'presentation': 1,
      });
      expect(r.number, '+966501234567');
      expect(r.dateMs, 5);
      expect(r.durationSec, 7);
      expect(r.type, CallType.missed);
      expect(r.cachedName, 'X');
    });

    test('private and unknown presentations are hidden numbers', () {
      expect(call('123', presentation: 2).hiddenNumber, isTrue);
      expect(call('123', presentation: 3).hiddenNumber, isTrue);
      expect(call('').hiddenNumber, isTrue);
      expect(call('+966501234567').hiddenNumber, isFalse);
    });
  });

  group('grouping', () {
    test('the same number in different formats is one group', () {
      final g = group([call('+966501234567'), call('0501234567', days: 2)]);
      expect(g.length, 1);
      expect(g.single.count, 2);
    });

    test('the same national number in another country is separate', () {
      final g = group([call('+966501234567'), call('+971501234567')]);
      expect(g.length, 2);
    });

    test('saved contacts are left out', () {
      final saved = [
        Person(name: 'Ann', phones: [const PhoneEntry('+966501234567')]),
      ];
      final g = group([
        call('0501234567'),
        call('+966559876543'),
      ], saved: saved);
      expect(g.single.number, '+966559876543');
    });

    test('a saved number in another country does not hide the caller', () {
      final saved = [
        Person(name: 'Ann', phones: [const PhoneEntry('+971501234567')]),
      ];
      expect(group([call('+966501234567')], saved: saved).length, 1);
    });

    test('hidden numbers are dropped by default and shown on request', () {
      final calls = [
        call('', presentation: 2),
        call('+966501234567', presentation: 3),
        call('+966559876543'),
      ];
      expect(group(calls).length, 1);
      expect(group(calls, showHidden: true).length, 3);
    });

    test('short codes are hidden by default and shown on request', () {
      final calls = [call('1234'), call('+966559876543')];
      expect(group(calls).length, 1);
      final all = group(calls, showHidden: true);
      expect(all.length, 2);
      expect(all.map((g) => g.number), contains('1234'));
    });

    test('ignored numbers are left out', () {
      final key = group([call('+966501234567')]).single.key;
      expect(group([call('0501234567')], ignored: {key}), isEmpty);
    });

    test('counts, talk time, last call and name are summed', () {
      final g = group([
        call('+966501234567', days: 5, secs: 30, type: CallType.outgoing),
        call('0501234567', days: 2, secs: 0, type: CallType.missed),
        call('+966 50 123 4567', days: 9, secs: 60, name: 'Ann'),
        call('+966501234567', days: 3, type: CallType.rejected),
      ]).single;
      expect(g.count, 4);
      expect(g.outgoing, 1);
      expect(g.missed, 2);
      expect(g.incoming, 1);
      expect(g.talkSec, 90);
      expect(g.lastMs, daysAgo(2));
      expect(g.number, '0501234567');
      expect(g.cachedName, 'Ann');
    });

    test('newest group first', () {
      final g = group([
        call('+966501234567', days: 10),
        call('+966559876543', days: 1),
        call('+966551111111', days: 5),
      ]);
      expect(g.map((x) => x.lastMs), [daysAgo(1), daysAgo(5), daysAgo(10)]);
    });
  });

  group('filters', () {
    final groups = group([
      call('+966501234567', days: 1, secs: 40),
      call('+966501234567', days: 2, secs: 5),
      call('+966559876543', days: 40, secs: 100, type: CallType.outgoing),
      call('+966551111111', days: 3, type: CallType.missed),
      call('+966551111111', days: 4, type: CallType.missed),
      call('+966552222222', days: 6, type: CallType.outgoing),
    ]);

    List<String> numbers(CallFilter f) =>
        f.apply(groups, now).map((g) => g.number).toList()..sort();

    test('an empty filter keeps everything', () {
      expect(const CallFilter().isEmpty, isTrue);
      expect(numbers(const CallFilter()).length, 4);
    });

    test('called twice or more', () {
      expect(numbers(const CallFilter(minCalls: 2)), [
        '+966501234567',
        '+966551111111',
      ]);
    });

    test('talked more than 30 seconds', () {
      expect(numbers(const CallFilter(minTalkSec: 31)), [
        '+966501234567',
        '+966559876543',
      ]);
    });

    test('last 30 days', () {
      expect(numbers(const CallFilter(lastDays: 30)).length, 3);
    });

    test('missed only', () {
      expect(numbers(const CallFilter(missedOnly: true)), ['+966551111111']);
    });

    test('outgoing only', () {
      expect(numbers(const CallFilter(outgoingOnly: true)), [
        '+966552222222',
        '+966559876543',
      ]);
    });

    test('filters combine', () {
      expect(numbers(const CallFilter(minCalls: 2, missedOnly: true)), [
        '+966551111111',
      ]);
    });

    test('a number pattern filters the groups', () {
      expect(numbers(const CallFilter(pattern: '*11')), ['+966551111111']);
      expect(numbers(const CallFilter(pattern: '*67, *43')), [
        '+966501234567',
        '+966559876543',
      ]);
    });
  });

  group('selection', () {
    test('everything starts unselected', () {
      final s = CallSelection();
      expect(s.included, isEmpty);
      expect(s.excluded, isEmpty);
    });

    test('include and exclude replace each other', () {
      final s = CallSelection()..include('a');
      s.exclude('a');
      expect(s.isIncluded('a'), isFalse);
      expect(s.isExcluded('a'), isTrue);
      s.include('a');
      expect(s.isExcluded('a'), isFalse);
      expect(s.isIncluded('a'), isTrue);
    });

    test('select all shown skips excluded keys', () {
      final s = CallSelection()..exclude('b');
      s.includeAll(['a', 'b', 'c']);
      expect(s.included, {'a', 'c'});
    });

    test('invert flips only shown, non-excluded keys', () {
      final s = CallSelection()
        ..include('a')
        ..exclude('c');
      s.invert(['a', 'b', 'c']);
      expect(s.included, {'b'});
      expect(s.excluded, {'c'});
    });

    test('a range selects between two rows in either direction', () {
      final s = CallSelection();
      s.includeRange(['a', 'b', 'c', 'd', 'e'], 3, 1);
      expect(s.included, {'b', 'c', 'd'});
    });

    test('toggle includes and then clears', () {
      final s = CallSelection()..toggle('a');
      expect(s.isIncluded('a'), isTrue);
      s.toggle('a');
      expect(s.isIncluded('a'), isFalse);
    });

    test('chosen returns the included groups only', () {
      final all = group([call('+966501234567'), call('+966559876543')]);
      final s = CallSelection()..include(all.first.key);
      expect(s.chosen(all).single.key, all.first.key);
    });

    test('the counter reads in English and Arabic', () {
      final s = CallSelection();
      for (var i = 0; i < 12; i++) {
        s.include('i$i');
      }
      for (var i = 0; i < 3; i++) {
        s.exclude('e$i');
      }
      expect(s.counterText(L('en')), '12 selected · 3 excluded');
      expect(s.counterText(L('ar')), 'تم تحديد 12 · مستبعد: 3');
    });

    test('the Arabic counter uses dual forms', () {
      final s = CallSelection()
        ..include('a')
        ..include('b')
        ..exclude('x')
        ..exclude('y');
      expect(s.counterText(L('ar')), 'تم تحديد اثنتين · مستبعدان');
    });
  });

  group('naming', () {
    test('last four digits', () {
      expect(CallNaming.last4('+966 50 123 4567'), '4567');
      expect(CallNaming.last4('123'), '123');
    });

    test('templates fill tag, last4 and a running number', () {
      expect(
        CallNaming.render(
          '{tag} {last4}',
          index: 0,
          number: '+966501234567',
          tag: 'Work',
        ),
        'Work 4567',
      );
      expect(
        CallNaming.render('Caller {n}', index: 4, number: '1'),
        'Caller 5',
      );
      expect(
        CallNaming.render('Caller {n}', index: 0, number: '1', start: 10),
        'Caller 10',
      );
    });

    test(
      'an empty tag leaves no double space and a blank template is blank',
      () {
        expect(
          CallNaming.render('{tag} {last4}', index: 0, number: '+966501234567'),
          '4567',
        );
        expect(CallNaming.render('', index: 0, number: '1'), '');
      },
    );

    test('a draft is a contact with one number', () {
      final p = CallNaming.draft('Work 4567', '+966501234567');
      expect(p.name, 'Work 4567');
      expect(p.phones.single.number, '+966501234567');
    });
  });

  group('ignore list', () {
    test('adding keeps one entry per number across formats', () async {
      final b = IgnoreBook(MemoryTagStore());
      final first = await b.add(['+966501234567', '0501234567', '12']);
      expect(first.length, 1);
      expect(b.has(first.single), isTrue);
    });

    test('it survives a reload', () async {
      final store = MemoryTagStore();
      final a = IgnoreBook(store);
      final added = await a.add(['+966501234567']);
      final b = IgnoreBook(store);
      await b.load();
      expect(b.keys, added.toSet());
    });

    test('removing and adding back restores the entry', () async {
      final b = IgnoreBook(MemoryTagStore());
      final added = await b.add(['+966501234567']);
      final raw = b.entries.single.value;
      await b.remove(added);
      expect(b.keys, isEmpty);
      await b.addKeys({added.single: raw});
      expect(b.keys, added.toSet());
    });

    test('grouping honours the ignore list', () async {
      final b = IgnoreBook(MemoryTagStore());
      await b.add(['+966501234567']);
      expect(group([call('0501234567')], ignored: b.keys), isEmpty);
    });
  });
}

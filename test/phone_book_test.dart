import 'package:contact_flow/data/contact_source.dart';
import 'package:contact_flow/data/journal.dart';
import 'package:contact_flow/data/sample.dart';
import 'package:contact_flow/domain/planner.dart';
import 'package:contact_flow/io/codec.dart';
import 'package:contact_flow/models/person.dart';
import 'package:contact_flow/state/phone_book.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('permission states map through the notifier', () async {
    for (final a in Access.values) {
      final b = PhoneBook(FakeSource(access: a), Journal(MemoryJournalStore()));
      await b.checkAccess();
      expect(b.access, a);
      expect(b.granted, a == Access.granted);
    }
  });

  test('request access loads the phone book', () async {
    final b = PhoneBook(
      FakeSource(seed: Sample.phoneBook(), access: Access.notAsked),
      Journal(MemoryJournalStore()),
    );
    expect(b.people, isEmpty);
    await b.requestAccess();
    expect(b.granted, isTrue);
    expect(b.people.length, Sample.phoneBook().length);
  });

  test('apply then undo through the notifier restores the list', () async {
    final b = demoPhoneBook(Sample.phoneBook());
    await b.checkAccess();
    final before = b.people.length;
    final victims = b.people.take(3).toList();
    final r = await b.apply(Planner.delete(victims));
    expect(r!.ok, 3);
    expect(b.people.length, before - 3);
    expect(b.journal.entries, hasLength(1));
    final original = b.journal.entries.first;
    await b.undo(original);
    expect(b.people.length, before);
    expect(b.journal.byId(original.id)!.canUndo, isFalse);
    expect(b.journal.entries, hasLength(2));
  });

  test('export with contact_id round-trips into phone ids', () {
    final people = [
      Person(name: 'A', phones: [const PhoneEntry('+971501234567')])
        ..phoneId = '42',
      Person(name: 'B', phones: [const PhoneEntry('+971501234568')]),
    ];
    const o = ExportOptions(contactId: true);
    final rows = Codec.table(people, o);
    expect(rows.first.last, 'contact_id');
    expect(rows[1].last, '42');
    expect(rows[2].last, '');
    final back = Codec.decode('x.csv', Codec.encode(people, Format.csv, o));
    expect(back.people.first.phoneId, '42');
    expect(back.people.last.phoneId, isNull);
    final plain = Codec.table(people, const ExportOptions());
    expect(plain.first.contains('contact_id'), isFalse);
  });
}

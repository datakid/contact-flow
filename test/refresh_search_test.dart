import 'package:contact_flow/data/contact_source.dart';
import 'package:contact_flow/data/journal.dart';
import 'package:contact_flow/data/sample.dart';
import 'package:contact_flow/models/person.dart';
import 'package:contact_flow/state/phone_book.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> settle() =>
    Future<void>.delayed(const Duration(milliseconds: 250));

void main() {
  late FakeSource source;
  late PhoneBook book;

  setUp(() async {
    source = FakeSource(seed: Sample.phoneBook());
    book = PhoneBook(source, Journal(MemoryJournalStore()));
    await book.checkAccess();
  });

  test('a refresh with nothing changed does not rebuild the search index', () async {
    book.setQuery('a');
    await settle();
    final before = book.indexBuilds;
    expect(before, 1);
    await book.refresh(quiet: true);
    await book.refresh(quiet: true);
    expect(book.indexBuilds, before);
    expect(book.hits, isNotEmpty);
  });

  test('a refresh after a change rebuilds the index once', () async {
    book.setQuery('a');
    await settle();
    final before = book.indexBuilds;
    final first = book.people.first;
    await source.update(
      first.copy()..name = '${first.name} changed',
    );
    await book.refresh(quiet: true);
    expect(book.indexBuilds, before + 1);
    expect(book.people.any((p) => p.name.endsWith('changed')), isTrue);
  });

  test('a refresh of 10k contacts while searching stays cheap', () async {
    final big = FakeSource(
      seed: [
        for (var i = 0; i < 10000; i++)
          Person(name: 'Contact $i', phones: [PhoneEntry('055${i.toString().padLeft(7, '0')}')]),
      ],
    );
    final b = PhoneBook(big, Journal(MemoryJournalStore()));
    await b.checkAccess();
    b.setQuery('contact 99');
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final builds = b.indexBuilds;
    final sw = Stopwatch()..start();
    await b.refresh(quiet: true);
    sw.stop();
    expect(b.indexBuilds, builds);
    expect(sw.elapsedMilliseconds, lessThan(1500));
  });
}

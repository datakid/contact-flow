import 'package:contact_flow/data/journal.dart';
import 'package:contact_flow/models/person.dart';
import 'package:contact_flow/services/library_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('writes throw after the store failed to open', () async {
    final store = LibraryStore();
    await expectLater(store.open(), throwsA(anything));
    expect(store.failed, isTrue);
    expect(() => store.putAll([Person(name: 'A')]), throwsStateError);
    expect(() => store.deleteAll(['x']), throwsStateError);
    expect(() => store.clear(), throwsStateError);
  });

  test('a store that was never opened still ignores writes quietly', () async {
    final store = LibraryStore();
    await store.putAll([Person(name: 'A')]);
    expect(store.failed, isFalse);
  });

  test('a corrupt journal row is quarantined, not dropped silently', () async {
    final store = MemoryJournalStore();
    store.data['bad'] = '{broken';
    final journal = Journal(store);
    await journal.load();
    expect(journal.entries, isEmpty);
    expect(store.bad, ['{broken']);
    expect(store.data, isEmpty);
  });
}

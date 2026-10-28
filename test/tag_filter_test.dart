import 'package:contact_flow/models/person.dart';
import 'package:contact_flow/state/app_state.dart';
import 'package:contact_flow/tags/tag_book.dart';
import 'package:contact_flow/tags/tag_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(AppState, TagBook)> setup() async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState();
    await s.init(openStore: false);
    final book = TagBook(MemoryTagStore());
    await book.load();
    final vip = await book.create('VIP');
    await book.assign([vip.id], ['+966501234567']);
    s.tagMatcher = book.personHasTag;
    s.replacePeople([
      Person(name: 'Ann', phones: [const PhoneEntry('+966501234567')]),
      Person(name: 'Bob', phones: [const PhoneEntry('+966559876543')]),
    ]);
    return (s, book);
  }

  test('the tag filter keeps only contacts with a tagged number', () async {
    final (s, _) = await setup();
    s.setTagFilter('VIP');
    expect(s.visible.map((p) => p.name), ['Ann']);
    expect(s.filtering, isTrue);
  });

  test('clearing filters removes the tag filter', () async {
    final (s, _) = await setup();
    s.setTagFilter('VIP');
    s.clearFilters();
    expect(s.tagFilter, isNull);
    expect(s.visible.length, 2);
  });

  test('a tag nobody has gives an empty list', () async {
    final (s, book) = await setup();
    await book.create('Nobody');
    s.setTagFilter('Nobody');
    expect(s.visible, isEmpty);
  });

  test(
    'without a matcher the filter shows nothing rather than everyone',
    () async {
      final (s, _) = await setup();
      s.tagMatcher = null;
      s.setTagFilter('VIP');
      expect(s.visible, isEmpty);
    },
  );

  test('the tag filter combines with a search', () async {
    final (s, _) = await setup();
    s.setTagFilter('VIP');
    s.setQuery('bob');
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(s.visible, isEmpty);
    s.setQuery('ann');
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(s.visible.map((p) => p.name), ['Ann']);
  });
}

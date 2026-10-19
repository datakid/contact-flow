import 'package:contact_flow/models/person.dart';
import 'package:contact_flow/phone/phone_key.dart';
import 'package:contact_flow/search/number_pattern.dart';
import 'package:contact_flow/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<List<String>> run(AppState s, String q) async {
  s.setQuery(q);
  await Future<void>.delayed(const Duration(milliseconds: 150));
  return s.hits.map((h) => h.person.name).toList();
}

Future<(AppState, List<Person>)> setup() async {
  SharedPreferences.setMockInitialValues({});
  final s = AppState();
  await s.init(openStore: false);
  final people = [
    Person(name: 'Ann', phones: [const PhoneEntry('0551234567')]),
    Person(name: 'Bob', phones: [const PhoneEntry('0559876543')]),
    Person(
      name: 'Cy',
      phones: [const PhoneEntry('0212345636')],
      groups: ['Work'],
    ),
    Person(name: 'Dee', phones: [const PhoneEntry('+971501234567')]),
    Person(name: 'Eli'),
  ];
  s.replacePeople(people);
  return (s, people);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => PhoneKey.useRegion(''));

  test('a number ending is found with a leading star', () async {
    final (s, _) = await setup();
    expect(await run(s, '*67'), ['Ann', 'Dee']);
  });

  test('a number start is found with a trailing star', () async {
    final (s, _) = await setup();
    expect(await run(s, '055*'), ['Ann', 'Bob']);
  });

  test('start and end together', () async {
    final (s, _) = await setup();
    expect(await run(s, '02*36'), ['Cy']);
  });

  test('question mark is one digit', () async {
    final (s, _) = await setup();
    expect(await run(s, '05?9*'), ['Bob']);
  });

  test('a tag finds contacts in a group of that name', () async {
    final (s, _) = await setup();
    expect(await run(s, '#work'), ['Cy']);
    expect(await run(s, '02* #work'), ['Cy']);
    expect(await run(s, '055* #work'), isEmpty);
  });

  test('comma is OR', () async {
    final (s, _) = await setup();
    expect(await run(s, '*67, *43'), ['Ann', 'Bob', 'Dee']);
  });

  test('a name and a pattern must both match', () async {
    final (s, _) = await setup();
    expect(await run(s, 'ann *67'), ['Ann']);
    expect(await run(s, 'bob *67'), isEmpty);
  });

  test('digit chips restrict plain digits', () async {
    final (s, _) = await setup();
    s.setDigitMode(DigitMode.ends);
    expect(await run(s, '67'), ['Ann', 'Dee']);
    s.setDigitMode(DigitMode.starts);
    expect(await run(s, '055'), ['Ann', 'Bob']);
    s.setDigitMode(DigitMode.contains);
    expect(await run(s, '98'), ['Bob']);
  });

  test('plain digits in the default mode still use the fuzzy path', () async {
    final (s, _) = await setup();
    final names = await run(s, '67');
    expect(names.toSet(), {'Ann', 'Dee'});
  });

  test('editing a number is picked up by the next search', () async {
    final (s, people) = await setup();
    expect(await run(s, '*67'), ['Ann', 'Dee']);
    people.first.phones = [const PhoneEntry('0500000001')];
    expect(await run(s, '*67'), ['Dee']);
  });

  test('the region makes the E.164 form searchable', () async {
    final (s, _) = await setup();
    expect(await run(s, '+966551*'), isEmpty);
    await s.setRegion('SA');
    expect(await run(s, '+966551*'), ['Ann']);
  });

  test('hits carry the number that matched', () async {
    final (s, _) = await setup();
    await run(s, '02*36');
    expect(s.hits.single.matchedPhone, '0212345636');
    expect(s.hits.single.reason, 'phone');
  });
}

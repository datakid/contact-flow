import 'package:contact_flow/io/codec.dart';
import 'package:contact_flow/models/person.dart';
import 'package:contact_flow/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> appWith(List<Person> people) async {
  SharedPreferences.setMockInitialValues({});
  final s = AppState();
  await s.init(openStore: false);
  s.replacePeople(people);
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'an imported email-only row matches an existing contact by email',
    () async {
      final s = await appWith([
        Person(name: 'Ann', emails: ['Ann@Example.com'], added: DateTime(2020)),
      ]);
      final plan = s.plan([
        ImportResult(
          [
            Person(name: 'Ann', emails: ['ann@example.com']),
          ],
          Format.csv,
          '',
        ),
      ]);
      expect(plan.dupes.length, 1);
      expect(plan.fresh, isEmpty);
    },
  );

  test('rows with different emails and no numbers stay separate', () async {
    final s = await appWith([
      Person(name: 'Ann', emails: ['ann@example.com'], added: DateTime(2020)),
    ]);
    final plan = s.plan([
      ImportResult(
        [
          Person(name: 'Bob', emails: ['bob@example.com']),
        ],
        Format.csv,
        '',
      ),
    ]);
    expect(plan.dupes, isEmpty);
    expect(plan.fresh.length, 1);
  });

  test('dedupe plan is built without changing anything', () async {
    final s = await appWith([
      Person(name: 'Ann', emails: ['ann@example.com'], added: DateTime(2020)),
      Person(
        name: 'Ann',
        emails: ['ANN@example.com'],
        phones: [const PhoneEntry('0551234567')],
        added: DateTime(2021),
      ),
    ]);
    final plan = s.planDedupe();
    expect(plan.removed, 1);
    expect(s.people.length, 2);
    expect(s.people.first.phones, isEmpty);
  });

  test('applying the plan merges and undo restores both contacts', () async {
    final s = await appWith([
      Person(name: 'Ann', emails: ['ann@example.com'], added: DateTime(2020)),
      Person(
        name: 'Ann',
        emails: ['ANN@example.com'],
        phones: [const PhoneEntry('0551234567')],
        added: DateTime(2021),
      ),
    ]);
    final undo = await s.applyDedupe(s.planDedupe());
    expect(s.people.length, 1);
    expect(s.people.single.phones.length, 1);

    await s.undoDedupe(undo);
    expect(s.people.length, 2);
    final kept = s.people.firstWhere((p) => p.added == DateTime(2020));
    expect(kept.phones, isEmpty);
  });

  test('contacts with nothing in common are not planned', () async {
    final s = await appWith([
      Person(name: 'Ann', phones: [const PhoneEntry('0551234567')]),
      Person(name: 'Bob', phones: [const PhoneEntry('0559876543')]),
    ]);
    expect(s.planDedupe().isEmpty, isTrue);
  });

  test(
    'the same national number in two countries is not a duplicate',
    () async {
      final s = await appWith([
        Person(name: 'Ann', phones: [const PhoneEntry('+966501234567')]),
        Person(name: 'Ann', phones: [const PhoneEntry('+971501234567')]),
      ]);
      expect(s.planDedupe().isEmpty, isTrue);
    },
  );

  test('a local number and an international one are duplicates', () async {
    final s = await appWith([
      Person(name: 'Ann', phones: [const PhoneEntry('0501234567')]),
      Person(name: 'Ann', phones: [const PhoneEntry('+966501234567')]),
    ]);
    expect(s.planDedupe().removed, 1);
  });
}

import 'package:contact_flow/models/person.dart';
import 'package:contact_flow/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hitFor finds the hit for the same person and nothing else', () async {
    SharedPreferences.setMockInitialValues({});
    final s = AppState();
    await s.init(openStore: false);
    final a = Person(
      name: 'Ahmed Saleh',
      phones: [const PhoneEntry('0551234536')],
    );
    final b = Person(
      name: 'Omar Nasser',
      phones: [const PhoneEntry('0559876543')],
    );
    s.replacePeople([a, b]);

    s.setQuery('ahmed');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(s.hitFor(a)?.person, same(a));
    expect(s.hitFor(b), isNull);

    s.setQuery('');
    expect(s.hitFor(a), isNull);
  });
}

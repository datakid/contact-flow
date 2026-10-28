import 'package:contact_flow/domain/phone_dupes.dart';
import 'package:contact_flow/models/person.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final phoneOnly = Person(
    name: 'Ann',
    phones: [const PhoneEntry('+966501234567')],
  );
  final emailOnly = Person(name: 'Bob', emails: ['Bob@Example.com']);
  final other = Person(name: 'Cy', phones: [const PhoneEntry('0559876543')]);

  test('nothing is on the phone the first time', () {
    final (fresh, already) = PhoneDupes.split([phoneOnly, emailOnly], const []);
    expect(fresh.length, 2);
    expect(already, isEmpty);
  });

  test('saving the same list again finds every contact on the phone', () {
    final onPhone = [phoneOnly.copy(), emailOnly.copy()];
    final (fresh, already) = PhoneDupes.split([phoneOnly, emailOnly], onPhone);
    expect(fresh, isEmpty);
    expect(already.length, 2);
  });

  test('a different number or email is still new', () {
    final onPhone = [phoneOnly.copy(), emailOnly.copy()];
    final (fresh, already) = PhoneDupes.split([other], onPhone);
    expect(fresh, [other]);
    expect(already, isEmpty);
  });

  test('emails match without regard to case', () {
    final onPhone = [
      Person(name: 'Bob', emails: ['bob@example.com']),
    ];
    final (_, already) = PhoneDupes.split([emailOnly], onPhone);
    expect(already.length, 1);
  });

  test('the same national number in another country is new', () {
    final onPhone = [
      Person(name: 'Ann', phones: [const PhoneEntry('+971501234567')]),
    ];
    final (fresh, already) = PhoneDupes.split([phoneOnly], onPhone);
    expect(fresh.length, 1);
    expect(already, isEmpty);
  });
}

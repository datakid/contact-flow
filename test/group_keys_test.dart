import 'package:contact_flow/data/phone_source.dart';
import 'package:contact_flow/models/person.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the same group name in two accounts gets two keys', () {
    const google = AccountRef('me@gmail.com', 'com.google');
    const other = AccountRef('you@gmail.com', 'com.google');
    expect(PhoneSource.groupKey(google), isNot(PhoneSource.groupKey(other)));
    expect(PhoneSource.groupKey(google), isNot(PhoneSource.groupKey(null)));
  });

  test('device-only contacts share the empty key', () {
    expect(PhoneSource.groupKey(null), '');
    expect(PhoneSource.groupKey(AccountRef.device), '');
  });

  test('system groups are recognised', () {
    for (final n in [
      'My Contacts',
      'Starred in Android',
      'ICE',
      'System Group: My Contacts',
    ]) {
      expect(PhoneSource.isSystemGroup(n), isTrue, reason: n);
    }
  });

  test('user groups are kept', () {
    for (final n in ['Family', 'Work', 'My Contacts Backup']) {
      expect(PhoneSource.isSystemGroup(n), isFalse, reason: n);
    }
  });
}

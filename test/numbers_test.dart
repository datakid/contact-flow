import 'dart:io';

import 'package:contact_flow/io/codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads simple numbers file', () {
    final r = Codec.decode(
      'contacts.numbers',
      File('test/contacts.numbers').readAsBytesSync(),
    );
    final names = r.people.map((p) => p.name).toList();
    expect(
      names,
      containsAll([
        'Amelia Hart',
        'محمد عبد الله',
        '王伟',
        'José Álvarez',
        'No Phone Person',
        'Li Na',
      ]),
    );
    final amelia = r.people.firstWhere((p) => p.name == 'Amelia Hart');
    expect(amelia.org, 'Hart Studio');
    expect(amelia.emails, ['amelia@hart.studio']);
  });

  test('reads multi sheet numbers with numeric phones', () {
    final r = Codec.decode(
      'hard.numbers',
      File('test/hard.numbers').readAsBytesSync(),
    );
    final m = {
      for (final p in r.people) p.name: p.phones.map((x) => x.number).join('/'),
    };
    expect(m['فاطمة'], '966551234567');
    expect(m['王伟'], '13800138000');
    expect(m['John Doe'], '555-123-4567');
    expect(m['Jane Roe'], '4155550101');
    expect(m['محمد عبد الله'], '+966 50 123 4567');
  });
}

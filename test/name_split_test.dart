import 'package:contact_flow/batch/batch_ops.dart';
import 'package:contact_flow/data/phone_source.dart';
import 'package:contact_flow/domain/names.dart';
import 'package:contact_flow/io/vcard.dart';
import 'package:contact_flow/models/person.dart';
import 'package:flutter_test/flutter_test.dart';

const clearNames = <String, (String, String)>{
  'John Smith': ('John', 'Smith'),
  'Mary Jane Watson': ('Mary Jane', 'Watson'),
  'José Álvarez': ('José', 'Álvarez'),
  'Al Pacino': ('Al', 'Pacino'),
  'Abdullah Hassan': ('Abdullah', 'Hassan'),
  'Madonna': ('Madonna', ''),
  '王伟': ('伟', '王'),
  '欧阳娜娜': ('阳娜娜', '欧'),
  '李': ('李', ''),
};

const unclearNames = [
  'محمد عبد الله',
  'أبو بكر الصديق',
  'عبد الرحمن بن عوف',
  'آل سعود',
  'فاطمة',
  'Mohammed bin Salman',
  'Abdullah ibn Omar',
  'Ahmed Al-Harbi',
  'Omar El Sayed',
  'Abu Bakr',
  'Khalid Abdul Aziz',
  'Sara Mohammed Al Harbi',
];

void main() {
  group('NameSplit', () {
    clearNames.forEach((name, parts) {
      test('splits $name', () {
        final s = NameSplit.of(name);
        expect((s.first, s.last), parts);
        expect(s.clear, isTrue);
      });
    });

    for (final name in unclearNames) {
      test('keeps $name whole', () {
        final s = NameSplit.of(name);
        expect(s.clear, isFalse);
        expect(s.first, name);
        expect(s.last, '');
      });
    }

    test('empty name', () {
      final s = NameSplit.of('  ');
      expect((s.first, s.last), ('', ''));
    });
  });

  group('every caller agrees', () {
    for (final name in [...clearNames.keys, ...unclearNames]) {
      test('callers for $name', () {
        final s = NameSplit.of(name);
        final parts = NameParts.of(name);
        expect((parts.first, parts.last), (s.first, s.last));
        final (family, given) = VCard.splitName(name);
        expect((family, given), (s.last, s.first));
        final phone = PhoneSource.nameFor(Person(name: name));
        expect(phone.first ?? '', s.first);
        expect(phone.last ?? '', s.last);
      });
    }
  });

  test('vCard writes an Arabic compound name as given name only', () {
    final text = VCard.write([Person(name: 'محمد عبد الله')]);
    expect(text, contains('N:;محمد عبد الله;;;'));
  });

  test('vCard still writes family and given for a Latin name', () {
    final text = VCard.write([Person(name: 'John Smith')]);
    expect(text, contains('N:Smith;John;;;'));
  });

  group('SwapName', () {
    test('swaps a clear name', () {
      final p = Person(name: 'John Smith');
      const SwapName().apply(p, 0);
      expect(p.name, 'Smith John');
    });

    test('leaves Arabic and particle names alone and reports them', () {
      for (final name in ['محمد عبد الله', 'Mohammed bin Salman']) {
        final p = Person(name: name);
        const SwapName().apply(p, 0);
        expect(p.name, name);
        expect(const SwapName().skips(p), isTrue);
      }
    });

    test('does not report single words or clear names as skipped', () {
      expect(const SwapName().skips(Person(name: 'Madonna')), isFalse);
      expect(const SwapName().skips(Person(name: 'John Smith')), isFalse);
      expect(const SwapName().skips(Person(name: '王伟')), isFalse);
    });

    test('a Chinese name without spaces is not touched', () {
      final p = Person(name: '王伟');
      const SwapName().apply(p, 0);
      expect(p.name, '王伟');
    });
  });

  group('TemplateName', () {
    test('first and last for a clear name', () {
      final p = Person(name: 'Mary Jane Watson');
      expect(const TemplateName('{last}, {first}').render(p, 0), 'Watson, Mary');
    });

    test('an unclear name goes whole into first and last is empty', () {
      final p = Person(name: 'محمد عبد الله');
      expect(
        const TemplateName('Dr {first}{last}').render(p, 0),
        'Dr محمد عبد الله',
      );
    });
  });
}

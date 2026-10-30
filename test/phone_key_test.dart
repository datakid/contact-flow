import 'package:contact_flow/models/person.dart';
import 'package:contact_flow/phone/phone_key.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_numbers_parser/metadata.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

const regions = [
  IsoCode.SA,
  IsoCode.AE,
  IsoCode.BH,
  IsoCode.KW,
  IsoCode.QA,
  IsoCode.EG,
  IsoCode.JO,
  IsoCode.CN,
  IsoCode.FR,
  IsoCode.ES,
  IsoCode.US,
  IsoCode.GB,
];

String mobile(IsoCode r) => metadataExamplesByIsoCode[r]!.mobile;
String cc(IsoCode r) => metadataByIsoCode[r]!.countryCode;
String trunk(IsoCode r) => metadataByIsoCode[r]!.nationalPrefix ?? '';

String indic(String s) => s.replaceAllMapped(
  RegExp(r'[0-9]'),
  (m) => String.fromCharCode(0x0660 + int.parse(m[0]!)),
);

void main() {
  tearDown(() => PhoneKey.useRegion(''));

  for (final r in regions) {
    group('${r.name} mobile ${mobile(r)}', () {
      final e164 = '+${cc(r)}${mobile(r)}';

      setUp(() => PhoneKey.useRegion(r.name));

      test('plus form', () {
        final i = PhoneKey.info('+${cc(r)} ${mobile(r)}');
        expect(i.explicit, isTrue);
        expect(i.e164, e164);
      });

      test('double-zero form', () {
        final i = PhoneKey.info('00${cc(r)}${mobile(r)}');
        expect(i.explicit, isTrue);
        expect(i.e164, e164);
      });

      test('local form with the region', () {
        final i = PhoneKey.info('${trunk(r) == '0' ? '0' : ''}${mobile(r)}');
        expect(i.explicit, isFalse);
        expect(i.e164, e164);
      });

      test('every form has the same key', () {
        final k = PhoneKey.key(e164);
        expect(PhoneKey.key('00${cc(r)}${mobile(r)}'), k);
        expect(PhoneKey.key(mobile(r)), k);
        expect(PhoneKey.compatible(e164, mobile(r)), isTrue);
      });

      test('Arabic-Indic digits give the same key', () {
        expect(PhoneKey.key(indic(e164)), PhoneKey.key(e164));
      });
    });
  }

  group('different countries', () {
    test('the same national number in SA and AE never matches', () {
      PhoneKey.useRegion('SA');
      const sa = '+966 50 123 4567';
      const ae = '+971 50 123 4567';
      expect(PhoneKey.key(sa), PhoneKey.key(ae));
      expect(PhoneKey.compatible(sa, ae), isFalse);
    });

    test('a local number matches either country by its national part', () {
      PhoneKey.useRegion('SA');
      expect(PhoneKey.compatible('0501234567', '+966501234567'), isTrue);
      expect(PhoneKey.compatible('0501234567', '+971501234567'), isTrue);
    });

    test('two explicit numbers of the same country match', () {
      expect(PhoneKey.compatible('+966 50 123 4567', '00966501234567'), isTrue);
    });
  });

  group('Bahrain 8-digit numbers', () {
    setUp(() => PhoneKey.useRegion('BH'));

    test('with and without +973 have the same key', () {
      expect(PhoneKey.key('3600 1234'), PhoneKey.key('+973 3600 1234'));
      expect(PhoneKey.compatible('36001234', '+97336001234'), isTrue);
    });
  });

  group('extensions and junk', () {
    setUp(() => PhoneKey.useRegion('SA'));

    test('x12 is not part of the number', () {
      expect(
        PhoneKey.key('+966 50 123 4567 x12'),
        PhoneKey.key('+966 50 123 4567'),
      );
      expect(PhoneKey.extension('+966 50 123 4567 x12'), '12');
    });

    test('#12 and ext. 12 are extensions too', () {
      expect(PhoneKey.extension('0501234567 #12'), '12');
      expect(PhoneKey.extension('0501234567 ext. 12'), '12');
      expect(PhoneKey.key('0501234567 #12'), PhoneKey.key('0501234567'));
    });

    test('too short and text are empty', () {
      expect(PhoneKey.key('1234'), '');
      expect(PhoneKey.key('abc'), '');
      expect(PhoneKey.key(''), '');
    });

    test('an unreadable number still gets the old last-9 key', () {
      expect(PhoneKey.info('12345678901234').parsed, isNull);
      expect(PhoneKey.key('12345678901234'), '678901234');
    });
  });

  group('formats', () {
    setUp(() => PhoneKey.useRegion('SA'));

    test('Saudi national format keeps the trunk zero', () {
      expect(PhoneKey.national('+966501234567'), '050 123 4567');
    });

    test('Spanish national format has no zero', () {
      final n = PhoneKey.national('+34${mobile(IsoCode.ES)}')!;
      expect(n, startsWith(mobile(IsoCode.ES).substring(0, 3)));
    });

    test('French national format starts with zero', () {
      expect(PhoneKey.national('+33${mobile(IsoCode.FR)}'), startsWith('0'));
    });

    test('Chinese mobile national format has no zero', () {
      final n = PhoneKey.national('+86${mobile(IsoCode.CN)}')!;
      expect(n, startsWith(mobile(IsoCode.CN).substring(0, 3)));
    });

    test('US national format has no leading zero or one', () {
      final n = PhoneKey.national('+1${mobile(IsoCode.US)}')!;
      expect(n, isNot(startsWith('0')));
      expect(n, contains(mobile(IsoCode.US).substring(0, 3)));
    });

    test('Italian fixed line does not gain a second zero', () {
      final nsn = metadataExamplesByIsoCode[IsoCode.IT]!.fixedLine;
      final n = PhoneKey.national('+39$nsn')!;
      expect(n, isNot(startsWith('00')));
    });

    test('international format keeps the country code', () {
      expect(PhoneKey.international('+966501234567'), startsWith('+966 '));
    });

    test('unparsed numbers have no formatted form', () {
      expect(PhoneKey.national('12345678901234'), isNull);
      expect(PhoneKey.international('12345678901234'), isNull);
    });
  });

  group('regions', () {
    test('a unique calling code maps to one region', () {
      expect(PhoneKey.uniqueRegionForCode('+966'), IsoCode.SA);
      expect(PhoneKey.uniqueRegionForCode('971'), IsoCode.AE);
    });

    test('shared calling codes are ambiguous', () {
      expect(PhoneKey.uniqueRegionForCode('+1'), isNull);
      expect(PhoneKey.uniqueRegionForCode('+7'), isNull);
      expect(PhoneKey.uniqueRegionForCode('+44'), isNull);
      expect(PhoneKey.regionsForCode('+1'), contains(IsoCode.US));
    });

    test('parseRegion is case-insensitive and tolerant', () {
      expect(PhoneKey.parseRegion('sa'), IsoCode.SA);
      expect(PhoneKey.parseRegion(' ae '), IsoCode.AE);
      expect(PhoneKey.parseRegion('zz'), isNull);
      expect(PhoneKey.parseRegion(null), isNull);
    });
  });

  group('no regressions against the old last-9 key', () {
    String old(String s) {
      final d = Phones.digits(s);
      if (d.length < 5) return '';
      return d.length > 9 ? d.substring(d.length - 9) : d;
    }

    const pairs = [
      ('0501234567', '+966501234567'),
      ('050 123 4567', '966501234567'),
      ('+971 50 123 4567', '0501234567'),
      ('(415) 555-0100', '+1 415 555 0100'),
      ('+44 20 7946 0000', '020 7946 0000'),
      ('00966501234567', '+966 50 123 4567'),
    ];

    for (final (a, b) in pairs) {
      test('$a vs $b', () {
        PhoneKey.useRegion('SA');
        final matchedBefore = old(a) == old(b);
        final matchesNow =
            PhoneKey.key(a) == PhoneKey.key(b) && PhoneKey.compatible(a, b);
        final ia = PhoneKey.info(a);
        final ib = PhoneKey.info(b);
        final provablyDifferent =
            ia.explicit && ib.explicit && ia.e164 != ib.e164;
        if (matchedBefore && !provablyDifferent) {
          expect(matchesNow, isTrue, reason: 'regressed: $a vs $b');
        }
      });
    }
  });
}

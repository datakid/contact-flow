import '../models/person.dart';

enum InternationalStatus { ok, needsCountry, invalid }

class InternationalNumber {
  final InternationalStatus status;
  final String e164;
  const InternationalNumber._(this.status, this.e164);

  static const invalid = InternationalNumber._(InternationalStatus.invalid, '');
  static const needsCountry = InternationalNumber._(
    InternationalStatus.needsCountry,
    '',
  );

  bool get ok => status == InternationalStatus.ok;
  String get digits => e164.isEmpty ? '' : e164.substring(1);

  static String countryDigits(String raw) =>
      Phones.digits(raw).replaceFirst(RegExp(r'^0+'), '');

  static InternationalNumber of(String number, {String country = ''}) {
    final a = Phones.asciiDigits(number).trim();
    final d = Phones.digits(a);
    if (d.length < 5 || d.length > 17) return invalid;
    if (a.startsWith('+')) return _checked(d);
    if (d.startsWith('00') && d.length > 9) return _checked(d.substring(2));
    final cc = countryDigits(country);
    if (cc.isEmpty) return needsCountry;
    if (d.startsWith(cc) && d.length >= cc.length + 8 && !d.startsWith('0')) {
      return _checked(d);
    }
    final local = d.startsWith('0') ? d.substring(1) : d;
    return _checked('$cc$local');
  }

  static InternationalNumber _checked(String digits) {
    if (digits.length < 7 || digits.length > 15 || digits.startsWith('0')) {
      return invalid;
    }
    return InternationalNumber._(InternationalStatus.ok, '+$digits');
  }
}

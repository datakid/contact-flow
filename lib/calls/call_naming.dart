import '../models/person.dart';

class CallNaming {
  static String last4(String number) {
    final d = Phones.digits(number);
    return d.length <= 4 ? d : d.substring(d.length - 4);
  }

  static String render(
    String template, {
    required int index,
    required String number,
    String tag = '',
    int start = 1,
  }) {
    return template
        .replaceAll('{tag}', tag)
        .replaceAll('{last4}', last4(number))
        .replaceAll('{n}', '${start + index}')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static Person draft(String name, String number, {String label = 'mobile'}) =>
      Person(name: name, phones: [PhoneEntry(number, label)], source: 'calls');
}

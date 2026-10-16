import 'package:contact_flow/models/person.dart';
import 'package:contact_flow/search/fuzzy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final people = [
    Person(name: 'Ahmed Saleh', phones: [const PhoneEntry('0551234536')]),
    Person(name: 'Omar Nasser', phones: [const PhoneEntry('0559876543')]),
    Person(
      name: 'Layla Farouk',
      phones: [const PhoneEntry('+966 50 111 2236')],
    ),
  ];
  final idx = FuzzyIndex()..build(people);

  List<String> names(String q) =>
      idx.search(q).map((h) => h.person.name).toList()..sort();

  test('two ASCII digits match numbers', () {
    expect(names('36'), ['Ahmed Saleh', 'Layla Farouk']);
  });

  test('two Arabic-Indic digits match numbers', () {
    expect(names('٣٦'), ['Ahmed Saleh', 'Layla Farouk']);
  });

  test('two full-width digits match numbers', () {
    expect(names('３６'), ['Ahmed Saleh', 'Layla Farouk']);
  });

  test('two-digit hit reports the number it matched', () {
    final hit = idx
        .search('36')
        .firstWhere((h) => h.person.name == 'Ahmed Saleh');
    expect(hit.reason, 'phone');
    expect(hit.matchedPhone, '0551234536');
  });

  test('name plus two digits narrows by number', () {
    expect(names('ahmed 36'), ['Ahmed Saleh']);
    expect(names('omar 36'), isEmpty);
  });

  test('name plus two digits works with Arabic-Indic digits', () {
    expect(names('ahmed ٣٦'), ['Ahmed Saleh']);
  });

  test('three digits still behave as before', () {
    expect(names('536'), ['Ahmed Saleh']);
    expect(names('٢٢٣٦'), ['Layla Farouk']);
  });
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:contact_flow/io/codec.dart';
import 'package:contact_flow/models/person.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final people = [
    Person(
      name: 'محمد عبد الله',
      phones: [
        const PhoneEntry('+966 50 123 4567'),
        const PhoneEntry('+966 11 222 3333', 'work'),
      ],
      emails: ['m@x.sa'],
    ),
    Person(
      name: '王伟',
      phones: [const PhoneEntry('+86 138 0013 8000')],
      org: '华为, 深圳',
    ),
    Person(
      name: 'José "Pepe" Álvarez',
      phones: [const PhoneEntry('+34 612 345 678')],
      note: 'line1\nline2',
    ),
  ];
  for (final f in Format.values) {
    test('roundtrip ${f.name}', () {
      final bytes = Codec.encode(
        people,
        f,
        const ExportOptions(includeNote: true),
      );
      final r = Codec.decode('contacts.${f.exportExt}', bytes);
      // ignore: avoid_print
      print(
        '${f.name}: ${r.people.length} ${r.detail} :: ${r.people.map((p) => '${p.name}|${p.phones.map((x) => x.number).join('/')}|${p.emails.join()}|${p.org}').join(' ;; ')}',
      );
      expect(r.people.length, 3);
      expect(r.people.first.phones.length, 2);
    });
  }
  test('foreign csv', () {
    const csv =
        'Nom;Prénom;Téléphone mobile;Courriel\nDupont;Marie;06 12 34 56 78;marie@ex.fr\nالخطيب;أحمد;٠٥٠١٢٣٤٥٦٧;\n';
    final r = Codec.decode('x.csv', Uint8List.fromList(utf8.encode(csv)));
    // ignore: avoid_print
    print(
      r.people
          .map((p) => '${p.name}|${p.phones.map((x) => x.number)}|${p.emails}')
          .toList(),
    );
    const g =
        'Name,Given Name,Family Name,Phone 1 - Type,Phone 1 - Value,Phone 2 - Type,Phone 2 - Value\nJohn Doe,John,Doe,Mobile,+1 555 123 4567 ::: +1 555 999 0000,Work,+1 555 222 3333\n';
    final r2 = Codec.decode('google.csv', Uint8List.fromList(utf8.encode(g)));
    // ignore: avoid_print
    print(
      r2.people
          .map(
            (p) => '${p.name}|${p.phones.map((x) => '${x.number}:${x.label}')}',
          )
          .toList(),
    );
    const t =
        'John 555-123-4567\n+44 20 7946 0958 Alice\n李雷：13800138000\nfoo bar\n0501234567, 0559876543';
    final r3 = Codec.decode('n.txt', Uint8List.fromList(utf8.encode(t)));
    // ignore: avoid_print
    print(
      r3.people
          .map((p) => '${p.name}|${p.phones.map((x) => x.number)}')
          .toList(),
    );
    const v =
        'BEGIN:VCARD\nVERSION:2.1\nN;CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE:=E7=8E=8B;=E4=BC=9F;;;\nTEL;CELL:13800138000\nEND:VCARD\nBEGIN:VCARD\nVERSION:3.0\nitem1.TEL;type=pref:+1 (555) 000-1111\nFN:Bob\n Smith\nEND:VCARD\n';
    final r4 = Codec.decode('a.vcf', Uint8List.fromList(utf8.encode(v)));
    // ignore: avoid_print
    print(
      r4.people
          .map(
            (p) => '${p.name}|${p.phones.map((x) => '${x.number}:${x.label}')}',
          )
          .toList(),
    );
  });
}

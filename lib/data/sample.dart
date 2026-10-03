import '../models/person.dart';

class Sample {
  static const _raw = [
    ['Amelia Hart', '+44 7700 900461', 'amelia@hart.studio', 'Hart Studio'],
    ['محمد عبد الله', '+966 50 123 4567', '', 'أرامكو'],
    ['王伟', '+86 138 0013 8000', 'wang.wei@example.cn', '华为'],
    ['José Álvarez', '+34 612 345 678', 'jose@alvarez.es', ''],
    [
      'Léa Fontaine',
      '+33 6 12 34 56 78',
      'lea.fontaine@mail.fr',
      'Atelier Fontaine',
    ],
    ['فاطمة الزهراء', '+971 55 765 4321', 'fatima@zahra.ae', ''],
    ['李小龙', '+86 139 1234 5678', '', '嘉禾'],
    ['Jonathan Smith', '+1 415 555 0101', 'jon@smith.co', 'Northwind'],
    ['Sofía Ramírez', '+52 55 1234 5678', 'sofia@ramirez.mx', ''],
    ['أحمد الخطيب', '+20 100 123 4567', '', 'مكتب الخطيب'],
    ['陈静', '+86 186 6666 1234', 'chen.jing@example.cn', ''],
    [
      'Hiroshi Tanaka',
      '+81 90 1234 5678',
      'hiroshi@tanaka.jp',
      'Tanaka Design',
    ],
    ['Priya Raman', '+91 98765 43210', 'priya@raman.in', ''],
    ['Oliver Bennett', '+44 20 7946 0958', '', 'Bennett & Co'],
    ['Noor Haddad', '+961 3 123 456', 'noor@haddad.lb', ''],
    ['张晓明', '+86 135 7777 8888', '', '腾讯'],
    ['Mohammed Ali', '+44 7700 900123', 'mo@ali.uk', ''],
    ['Isabella Rossi', '+39 347 123 4567', 'isa@rossi.it', 'Rossi Vini'],
    ['Lukas Müller', '+49 151 23456789', 'lukas@mueller.de', ''],
    ['يوسف المصري', '+20 122 987 6543', '', ''],
    ['Chloé Martin', '+33 7 98 76 54 32', 'chloe@martin.fr', ''],
    ['刘洋', '+86 158 0000 1111', 'liu.yang@example.cn', ''],
    ['Ethan Clarke', '+1 212 555 0199', 'ethan@clarke.nyc', 'Clarke Partners'],
    ['Mariana Costa', '+55 11 91234 5678', 'mariana@costa.br', ''],
    ['سارة القحطاني', '+966 55 555 0101', 'sara@q.sa', ''],
    ['Ava Thompson', '+1 646 555 0142', 'ava@thompson.me', ''],
    ['Kwame Mensah', '+233 24 123 4567', 'kwame@mensah.gh', ''],
    ['黄丽', '+86 137 2468 1357', '', ''],
    ['Daniel Kim', '+82 10 1234 5678', 'dan@kim.kr', 'Kim & Lee'],
    ['Elena Petrova', '+7 912 345 67 89', 'elena@petrova.ru', ''],
  ];

  static List<Person> people() {
    final now = DateTime.now();
    var i = 0;
    return _raw.map((r) {
      i++;
      return Person(
        name: r[0],
        phones: [PhoneEntry(r[1])],
        emails: r[2].isEmpty ? [] : [r[2]],
        org: r[3],
        source: 'sample',
        added: now.subtract(Duration(minutes: i * 7)),
      );
    }).toList();
  }
}

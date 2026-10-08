import '../models/person.dart';
import '../search/fold.dart';

enum Col {
  name,
  first,
  middle,
  last,
  phone,
  email,
  org,
  title,
  note,
  label,
  contactId,
  alias,
  ignore,
}

class TableMapping {
  final List<Col> columns;
  final List<String> headers;
  final bool hasHeader;
  const TableMapping(this.columns, this.headers, this.hasHeader);

  String describe() {
    final found = <String>{};
    for (final c in columns) {
      if (c == Col.phone) found.add('phone');
      if (c == Col.email) found.add('email');
      if (c == Col.name || c == Col.first || c == Col.last) found.add('name');
      if (c == Col.org) found.add('company');
      if (c == Col.note) found.add('note');
      if (c == Col.alias) found.add('alias');
    }
    return found.join(' · ');
  }
}

class Tabular {
  static const _labelKeys = [
    'type',
    'label',
    'kind',
    'نوع',
    '类型',
    '类别',
    'tipo',
  ];
  static const _ignoreKeys = [
    'phonetic',
    'yomi',
    'prefix',
    'suffix',
    'file as',
    'photo',
    'birthday',
    'group',
    'website',
    'address',
    'street',
    'city',
    'url',
    'id',
  ];
  static const _emailKeys = [
    'email',
    'e-mail',
    'e mail',
    'mail',
    'بريد',
    'ايميل',
    'إيميل',
    '邮箱',
    '邮件',
    '電郵',
    'correo',
    'courriel',
    'почта',
  ];
  static const _phoneKeys = [
    'phone',
    'mobile',
    'tel',
    'cell',
    'number',
    'numero',
    'whatsapp',
    'fax',
    'pager',
    'handy',
    'hatf',
    'هاتف',
    'جوال',
    'رقم',
    'موبايل',
    'تلفون',
    'تليفون',
    '电话',
    '手机',
    '号码',
    '電話',
    '手機',
    '號碼',
    'телефон',
    'номер',
    'telefono',
    'telefone',
    'telefon',
    'movil',
    'portable',
    'celular',
  ];
  static const _orgKeys = [
    'company',
    'organization',
    'organisation',
    'org',
    'employer',
    'business name',
    'شركة',
    'الشركة',
    'مؤسسة',
    '公司',
    '单位',
    '組織',
    'empresa',
    'societe',
    'entreprise',
    'firma',
    'компания',
  ];
  static const _noteKeys = [
    'note',
    'comment',
    'remark',
    'memo',
    'ملاحظ',
    'تعليق',
    '备注',
    '備註',
    'nota',
    'remarque',
    'notiz',
  ];
  static const _firstKeys = [
    'first',
    'given',
    'prenom',
    'vorname',
    'nombre de pila',
    'الاسم الاول',
    'الاول',
  ];
  static const _lastKeys = [
    'last',
    'family',
    'surname',
    'apellido',
    'nachname',
    'nom de famille',
    'العائلة',
    'اللقب',
    'cognome',
    'фамилия',
  ];
  static const _middleKeys = ['middle', 'الاوسط'];
  static const _aliasKeys = [
    'alias',
    'nick',
    'aka',
    'also known',
    'known as',
    'other name',
    'كنيه',
    'مستعار',
    'بديل',
    'اسم اخر',
    'يعرف ب',
    '昵称',
    '别名',
    '暱稱',
    '別名',
    'apodo',
    'surnom',
    'spitzname',
    'псевдоним',
  ];
  static const _nameKeys = [
    'name',
    'nombre',
    'nom',
    'nome',
    'الاسم',
    'اسم',
    '姓名',
    '名字',
    '名称',
    '联系人',
    '聯絡人',
    'contact',
    'fullname',
    'display',
    'имя',
    'isim',
    'person',
  ];

  static bool _has(String h, List<String> keys) {
    for (final k in keys) {
      if (k.length <= 3 && RegExp(r'^[a-z]+$').hasMatch(k)) {
        if (RegExp('(^|[^a-z])$k([^a-z]|\$)').hasMatch(h)) return true;
      } else if (h.contains(k)) {
        return true;
      }
    }
    return false;
  }

  static Col classifyHeader(String raw) {
    final h = Fold.basic(raw).replaceAll(RegExp(r'[_\.]+'), ' ').trim();
    if (h.isEmpty) return Col.ignore;
    if (h == '姓') return Col.last;
    if (h == '名') return Col.first;
    if (h == 'contact id' || h == 'contactid') return Col.contactId;
    if (_has(h, _aliasKeys) && !_has(h, _phoneKeys)) return Col.alias;
    if (h == 'job title' || h == 'title' || h == 'المسمى الوظيفي') {
      return Col.title;
    }
    if (_has(h, _labelKeys)) return Col.label;
    if (_has(h, _ignoreKeys) && !_has(h, _phoneKeys)) return Col.ignore;
    if (_has(h, _emailKeys)) return Col.email;
    if (_has(h, _phoneKeys)) return Col.phone;
    if (_has(h, _orgKeys)) return Col.org;
    if (_has(h, _noteKeys)) return Col.note;
    if (_has(h, _firstKeys)) return Col.first;
    if (_has(h, _lastKeys)) return Col.last;
    if (_has(h, _middleKeys)) return Col.middle;
    if (_has(h, _nameKeys)) return Col.name;
    return Col.ignore;
  }

  static bool isHeaderWord(String s) {
    final c = classifyHeader(s);
    return c != Col.ignore && !Phones.looksLikePhone(s) && s.length < 40;
  }

  static bool _isEmail(String s) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s.trim());

  static List<String> splitMulti(String v) {
    final t = v.trim();
    if (t.isEmpty) return const [];
    final parts = t
        .split(RegExp(r'\s*(?::::|;|\||\n|,(?!\d{3}\b)|\s/\s)\s*'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length > 1 && parts.every((p) => Phones.digits(p).length >= 5)) {
      return parts;
    }
    return [t];
  }

  static String _labelFor(String header, String labelValue) {
    final src = Fold.basic('$labelValue $header');
    if (RegExp(
      r'mobile|cell|iphone|جوال|موبايل|手机|móvil|movil|portable|handy',
    ).hasMatch(src)) {
      return 'mobile';
    }
    if (RegExp(
      r'work|business|office|عمل|工作|单位|bureau|trabajo',
    ).hasMatch(src)) {
      return 'work';
    }
    if (RegExp(r'home|منزل|بيت|家|casa|maison|domicile').hasMatch(src)) {
      return 'home';
    }
    if (RegExp(r'fax|فاكس|传真').hasMatch(src)) return 'fax';
    if (RegExp(r'main|principal|رئيسي').hasMatch(src)) return 'main';
    if (RegExp(r'other|اخرى|其他|autre|otro').hasMatch(src)) return 'other';
    return 'mobile';
  }

  static TableMapping detect(List<List<String>> rows) {
    final width = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    if (rows.isEmpty || width == 0) return const TableMapping([], [], false);
    final first = rows.first;
    final cls = List<Col>.generate(
      width,
      (i) => i < first.length ? classifyHeader(first[i]) : Col.ignore,
    );
    final headerHits = cls.where((c) => c != Col.ignore).length;
    final firstHasPhone = first.any(Phones.looksLikePhone);
    if (headerHits > 0 && !firstHasPhone) {
      for (var i = 0; i < width; i++) {
        if (cls[i] == Col.label &&
            (i + 1 >= width ||
                (cls[i + 1] != Col.phone && cls[i + 1] != Col.email))) {
          cls[i] = Col.ignore;
        }
      }
      if (!cls.contains(Col.phone)) {
        final inferred = _inferByContent(rows.skip(1).toList(), width);
        for (var i = 0; i < width; i++) {
          if (inferred[i] == Col.phone && cls[i] == Col.ignore) {
            cls[i] = Col.phone;
          }
        }
      }
      if (!cls.any((c) => c == Col.name || c == Col.first || c == Col.last)) {
        final inferred = _inferByContent(rows.skip(1).toList(), width);
        final n = inferred.indexOf(Col.name);
        if (n >= 0 && cls[n] == Col.ignore) cls[n] = Col.name;
      }
      return TableMapping(cls, [
        ...first,
        ...List.filled(width - first.length, ''),
      ], true);
    }
    return TableMapping(
      _inferByContent(rows, width),
      List.filled(width, ''),
      false,
    );
  }

  static List<Col> _inferByContent(List<List<String>> rows, int width) {
    final sample = rows.take(200).toList();
    final out = List<Col>.filled(width, Col.ignore);
    final stats = List.generate(width, (_) => [0, 0, 0, 0]);
    for (final r in sample) {
      for (var i = 0; i < width && i < r.length; i++) {
        final v = r[i].trim();
        if (v.isEmpty) continue;
        stats[i][3]++;
        if (splitMulti(v).every(Phones.looksLikePhone)) {
          stats[i][0]++;
        } else if (_isEmail(v)) {
          stats[i][1]++;
        } else if (RegExp(r'\p{L}', unicode: true).hasMatch(v)) {
          stats[i][2]++;
        }
      }
    }
    var nameSet = false;
    for (var i = 0; i < width; i++) {
      final s = stats[i];
      if (s[3] == 0) continue;
      if (s[0] / s[3] >= 0.5) {
        out[i] = Col.phone;
      } else if (s[1] / s[3] >= 0.5) {
        out[i] = Col.email;
      } else if (s[2] / s[3] >= 0.5 && !nameSet) {
        out[i] = Col.name;
        nameSet = true;
      }
    }
    return out;
  }

  static List<Person> toPeople(
    List<List<String>> rows,
    TableMapping m,
    String source,
  ) {
    final out = <Person>[];
    final body = m.hasHeader ? rows.skip(1) : rows;
    for (final r in body) {
      String cell(int i) => i < r.length ? r[i].trim() : '';
      var name = '', first = '', middle = '', last = '', org = '', note = '';
      var title = '', contactId = '';
      final aliases = <String>[];
      final phones = <PhoneEntry>[];
      final emails = <String>[];
      for (var i = 0; i < m.columns.length; i++) {
        final v = cell(i);
        if (v.isEmpty) continue;
        switch (m.columns[i]) {
          case Col.name:
            name = name.isEmpty ? v : '$name $v';
          case Col.first:
            first = v;
          case Col.middle:
            middle = v;
          case Col.last:
            last = v;
          case Col.org:
            org = org.isEmpty ? v : org;
          case Col.title:
            title = title.isEmpty ? v : title;
          case Col.contactId:
            contactId = v;
          case Col.alias:
            aliases.addAll(Aliases.parse(v));
          case Col.note:
            note = note.isEmpty ? v : '$note\n$v';
          case Col.email:
            for (final e in v.split(RegExp(r'\s*(?::::|;|,|\s)\s*'))) {
              if (_isEmail(e)) emails.add(e.trim());
            }
          case Col.phone:
            final lbl = i > 0 && m.columns[i - 1] == Col.label
                ? cell(i - 1)
                : '';
            for (final p in splitMulti(v)) {
              if (Phones.digits(p).length >= 3) {
                phones.add(PhoneEntry(p, _labelFor(m.headers[i], lbl)));
              }
            }
          case Col.label:
          case Col.ignore:
            break;
        }
      }
      if (name.isEmpty) {
        name = joinName(first, middle, last);
      } else if (first.isNotEmpty && last.isEmpty && !name.contains(first)) {
        name = joinName(first, middle, name);
      }
      if (phones.isEmpty && emails.isEmpty) continue;
      out.add(
        Person(
          name: name,
          phones: phones,
          emails: emails,
          org: org,
          jobTitle: title,
          note: note,
          source: source,
          phoneId: contactId.isEmpty ? null : contactId,
          aliases: Aliases.clean(aliases, name: name),
        ),
      );
    }
    return out;
  }

  static String joinName(String first, String middle, String last) {
    if (first.isEmpty && last.isEmpty) return middle;
    if (Fold.hasCjk(last) || Fold.hasCjk(first)) return '$last$middle$first';
    return [first, middle, last].where((e) => e.isNotEmpty).join(' ');
  }
}

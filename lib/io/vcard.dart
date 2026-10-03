import 'dart:convert';

import '../models/person.dart';
import '../search/fold.dart';

class VCard {
  static List<Person> parse(String text, String source) {
    final lines = _unfold(text);
    final out = <Person>[];
    _Card? cur;
    for (final line in lines) {
      final colon = _colonIndex(line);
      if (colon < 0) continue;
      final head = line.substring(0, colon);
      final value = line.substring(colon + 1);
      final parts = head.split(';');
      var prop = parts.first.toUpperCase();
      final dot = prop.lastIndexOf('.');
      if (dot >= 0) prop = prop.substring(dot + 1);
      final params = parts.skip(1).map((e) => e.toUpperCase()).toList();
      if (prop == 'BEGIN' && value.trim().toUpperCase() == 'VCARD') {
        cur = _Card();
        continue;
      }
      if (prop == 'END' && value.trim().toUpperCase() == 'VCARD') {
        final p = cur?.build(source);
        if (p != null) out.add(p);
        cur = null;
        continue;
      }
      if (cur == null) continue;
      final v = _decode(value, params, parts.skip(1).toList());
      switch (prop) {
        case 'FN':
          cur.fn = _unescape(v);
        case 'N':
          cur.n = _splitEscaped(v).map(_unescape).toList();
        case 'TEL':
          var num = _unescape(v).trim();
          if (num.toLowerCase().startsWith('tel:')) num = num.substring(4);
          if (num.isNotEmpty) cur.phones.add(PhoneEntry(num, _label(params)));
        case 'EMAIL':
          final e = _unescape(v).trim();
          if (e.isNotEmpty) cur.emails.add(e);
        case 'ORG':
          cur.org = _splitEscaped(
            v,
          ).map(_unescape).where((e) => e.isNotEmpty).join(' · ');
        case 'NOTE':
          cur.note = _unescape(v);
        case 'NICKNAME':
          cur.nick = _unescape(v);
      }
    }
    return out;
  }

  static int _colonIndex(String line) {
    var inQuote = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') inQuote = !inQuote;
      if (c == ':' && !inQuote) return i;
    }
    return -1;
  }

  static List<String> _unfold(String text) {
    final raw = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');
    final out = <String>[];
    var qpContinue = false;
    for (final l in raw) {
      if (out.isNotEmpty && qpContinue) {
        final last = out.removeLast();
        out.add(last.substring(0, last.length - 1) + l);
      } else if (out.isNotEmpty && (l.startsWith(' ') || l.startsWith('\t'))) {
        out[out.length - 1] = out.last + l.substring(1);
      } else {
        out.add(l);
      }
      final cur = out.last;
      qpContinue =
          cur.toUpperCase().contains('QUOTED-PRINTABLE') && cur.endsWith('=');
    }
    return out;
  }

  static String _decode(
    String value,
    List<String> params,
    List<String> rawParams,
  ) {
    final qp = params.any((p) => p.contains('QUOTED-PRINTABLE'));
    final b64 = params.any(
      (p) => p == 'ENCODING=B' || p == 'ENCODING=BASE64' || p == 'BASE64',
    );
    String? charset;
    for (final p in rawParams) {
      final m = RegExp(r'charset=([^;]+)', caseSensitive: false).firstMatch(p);
      if (m != null) charset = m.group(1)!.toLowerCase();
    }
    List<int>? bytes;
    if (qp) {
      bytes = <int>[];
      for (var i = 0; i < value.length; i++) {
        final c = value[i];
        if (c == '=' && i + 2 < value.length + 0 && i + 2 <= value.length - 1) {
          final h = int.tryParse(value.substring(i + 1, i + 3), radix: 16);
          if (h != null) {
            bytes.add(h);
            i += 2;
            continue;
          }
        }
        bytes.addAll(utf8.encode(c));
      }
    } else if (b64) {
      try {
        bytes = base64.decode(value.trim());
      } catch (_) {}
    }
    if (bytes == null) return value;
    if (charset != null &&
        (charset.contains('8859') || charset.contains('latin'))) {
      return latin1.decode(bytes, allowInvalid: true);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  static List<String> _splitEscaped(String v) {
    final out = <String>[];
    final b = StringBuffer();
    for (var i = 0; i < v.length; i++) {
      final c = v[i];
      if (c == '\\' && i + 1 < v.length) {
        b
          ..write(c)
          ..write(v[i + 1]);
        i++;
      } else if (c == ';') {
        out.add(b.toString());
        b.clear();
      } else {
        b.write(c);
      }
    }
    out.add(b.toString());
    return out;
  }

  static String _unescape(String v) => v
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\N', '\n')
      .replaceAll(r'\,', ',')
      .replaceAll(r'\;', ';')
      .replaceAll(r'\:', ':')
      .replaceAll(r'\\', '\\')
      .trim();

  static String _label(List<String> params) {
    final s = params.join(';');
    if (s.contains('CELL') || s.contains('MOBILE') || s.contains('IPHONE')) {
      return 'mobile';
    }
    if (s.contains('FAX')) return 'fax';
    if (s.contains('WORK')) return 'work';
    if (s.contains('HOME')) return 'home';
    if (s.contains('MAIN') || s.contains('PREF')) return 'main';
    if (s.contains('PAGER')) return 'pager';
    if (s.contains('OTHER') || s.contains('VOICE')) return 'other';
    return 'mobile';
  }

  static String _esc(String s) => s
      .replaceAll('\\', '\\\\')
      .replaceAll('\n', '\\n')
      .replaceAll(',', '\\,')
      .replaceAll(';', '\\;');

  static String _fold(String line) {
    final bytes = utf8.encode(line);
    if (bytes.length <= 75) return line;
    final out = StringBuffer();
    var count = 0;
    var first = true;
    for (final r in line.runes) {
      final ch = String.fromCharCode(r);
      final l = utf8.encode(ch).length;
      final limit = first ? 75 : 74;
      if (count + l > limit) {
        out.write('\r\n ');
        count = 0;
        first = false;
      }
      out.write(ch);
      count += l;
    }
    return out.toString();
  }

  static (String, String) splitName(String full) {
    final t = full.trim();
    if (t.isEmpty) return ('', '');
    if (Fold.hasCjk(t) && !t.contains(' ')) {
      final runes = t.runes.toList();
      if (runes.length <= 1) return ('', t);
      return (
        String.fromCharCode(runes.first),
        String.fromCharCodes(runes.skip(1)),
      );
    }
    final parts = t.split(RegExp(r'\s+'));
    if (parts.length == 1) return ('', t);
    return (parts.last, parts.sublist(0, parts.length - 1).join(' '));
  }

  static String write(List<Person> people, {String Function(String)? number}) {
    final b = StringBuffer();
    for (final p in people) {
      final (family, given) = splitName(p.name.isEmpty ? '' : p.name);
      final lines = <String>[
        'BEGIN:VCARD',
        'VERSION:3.0',
        'FN:${_esc(p.displayName)}',
        'N:${_esc(family)};${_esc(given)};;;',
        for (final ph in p.phones)
          'TEL;TYPE=${_typeFor(ph.label)}:${number == null ? ph.number : number(ph.number)}',
        for (final e in p.emails) 'EMAIL;TYPE=INTERNET:${_esc(e)}',
        if (p.org.isNotEmpty) 'ORG:${_esc(p.org)}',
        if (p.note.isNotEmpty) 'NOTE:${_esc(p.note)}',
        'END:VCARD',
      ];
      for (final l in lines) {
        b
          ..write(_fold(l))
          ..write('\r\n');
      }
    }
    return b.toString();
  }

  static String _typeFor(String label) => switch (label) {
    'work' => 'WORK,VOICE',
    'home' => 'HOME,VOICE',
    'fax' => 'FAX',
    'main' => 'MAIN',
    'pager' => 'PAGER',
    'other' => 'OTHER',
    _ => 'CELL',
  };
}

class _Card {
  String fn = '';
  List<String> n = [];
  String nick = '';
  String org = '';
  String note = '';
  final phones = <PhoneEntry>[];
  final emails = <String>[];

  Person? build(String source) {
    var name = fn;
    if (name.isEmpty && n.isNotEmpty) {
      final family = n.isNotEmpty ? n[0] : '';
      final given = n.length > 1 ? n[1] : '';
      final middle = n.length > 2 ? n[2] : '';
      if (Fold.hasCjk(family) || Fold.hasCjk(given)) {
        name = '$family$middle$given';
      } else {
        name = [given, middle, family].where((e) => e.isNotEmpty).join(' ');
      }
    }
    if (name.isEmpty) name = nick;
    if (phones.isEmpty && emails.isEmpty && name.isEmpty) return null;
    return Person(
      name: name,
      phones: phones,
      emails: emails,
      org: org,
      note: note,
      source: source,
    );
  }
}

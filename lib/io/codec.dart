import 'dart:convert';
import 'dart:typed_data';

import '../models/person.dart';
import 'numbers.dart';
import 'tabular.dart';
import 'text_decode.dart';
import 'vcard.dart';
import 'xlsx.dart';

enum Format { csv, vcf, xlsx, txt, json, numbers }

extension FormatX on Format {
  String get ext => switch (this) {
    Format.csv => 'csv',
    Format.vcf => 'vcf',
    Format.xlsx => 'xlsx',
    Format.txt => 'txt',
    Format.json => 'json',
    Format.numbers => 'numbers',
  };

  String get title => switch (this) {
    Format.csv => 'CSV',
    Format.vcf => 'vCard',
    Format.xlsx => 'Excel',
    Format.txt => 'Text',
    Format.json => 'JSON',
    Format.numbers => 'Numbers',
  };

  String get mime => switch (this) {
    Format.csv => 'text/csv',
    Format.vcf => 'text/vcard',
    Format.xlsx =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    Format.txt => 'text/plain',
    Format.json => 'application/json',
    Format.numbers =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  };

  String get exportExt => this == Format.numbers ? 'xlsx' : ext;
}

enum PhoneStyle { original, e164, digits }

class ExportOptions {
  final bool header;
  final bool includeEmail;
  final bool includeOrg;
  final bool includeNote;
  final bool allNumbers;
  final PhoneStyle phoneStyle;
  final bool txtWithNames;
  final bool rtl;

  const ExportOptions({
    this.header = true,
    this.includeEmail = true,
    this.includeOrg = true,
    this.includeNote = false,
    this.allNumbers = true,
    this.phoneStyle = PhoneStyle.original,
    this.txtWithNames = true,
    this.rtl = false,
  });

  ExportOptions copyWith({
    bool? header,
    bool? includeEmail,
    bool? includeOrg,
    bool? includeNote,
    bool? allNumbers,
    PhoneStyle? phoneStyle,
    bool? txtWithNames,
    bool? rtl,
  }) => ExportOptions(
    header: header ?? this.header,
    includeEmail: includeEmail ?? this.includeEmail,
    includeOrg: includeOrg ?? this.includeOrg,
    includeNote: includeNote ?? this.includeNote,
    allNumbers: allNumbers ?? this.allNumbers,
    phoneStyle: phoneStyle ?? this.phoneStyle,
    txtWithNames: txtWithNames ?? this.txtWithNames,
    rtl: rtl ?? this.rtl,
  );
}

class ImportResult {
  final List<Person> people;
  final Format format;
  final String detail;
  const ImportResult(this.people, this.format, this.detail);
}

class Codec {
  static Format? formatFor(String fileName, Uint8List bytes) {
    final n = fileName.toLowerCase();
    for (final f in Format.values) {
      if (n.endsWith('.${f.ext}')) return f;
    }
    if (n.endsWith('.vcard')) return Format.vcf;
    if (n.endsWith('.tsv') || n.endsWith('.tab')) return Format.csv;
    if (bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
      return Format.xlsx;
    }
    final head = TextDecode.bytes(
      Uint8List.sublistView(
        bytes,
        0,
        bytes.length < 2048 ? bytes.length : 2048,
      ),
    ).trimLeft();
    if (head.toUpperCase().startsWith('BEGIN:VCARD')) return Format.vcf;
    if (head.startsWith('[') || head.startsWith('{')) return Format.json;
    if (head.contains(',') || head.contains(';') || head.contains('\t')) {
      return Format.csv;
    }
    return Format.txt;
  }

  static ImportResult decode(String fileName, Uint8List bytes) {
    var f = formatFor(fileName, bytes) ?? Format.txt;
    final src = fileName;
    switch (f) {
      case Format.vcf:
        final people = VCard.parse(TextDecode.bytes(bytes), src);
        return ImportResult(people, f, '');
      case Format.xlsx:
        try {
          final rows = Xlsx.read(bytes);
          final m = Tabular.detect(rows);
          return ImportResult(Tabular.toPeople(rows, m, src), f, m.describe());
        } catch (_) {
          final people = NumbersFile.read(bytes, src);
          if (people.isNotEmpty) {
            return ImportResult(people, Format.numbers, '');
          }
          rethrow;
        }
      case Format.numbers:
        try {
          final rows = Xlsx.read(bytes);
          if (rows.isNotEmpty) {
            final m = Tabular.detect(rows);
            final p = Tabular.toPeople(rows, m, src);
            if (p.isNotEmpty) return ImportResult(p, f, m.describe());
          }
        } catch (_) {}
        return ImportResult(NumbersFile.read(bytes, src), f, '');
      case Format.json:
        final text = TextDecode.bytes(bytes);
        try {
          return ImportResult(_fromJson(jsonDecode(text), src), f, '');
        } catch (_) {
          f = Format.txt;
          return ImportResult(_fromTxt(text, src), f, '');
        }
      case Format.csv:
        final text = TextDecode.bytes(bytes);
        final rows = parseDelimited(text);
        final m = Tabular.detect(rows);
        return ImportResult(Tabular.toPeople(rows, m, src), f, m.describe());
      case Format.txt:
        final text = TextDecode.bytes(bytes);
        if (text.trimLeft().toUpperCase().startsWith('BEGIN:VCARD')) {
          return ImportResult(VCard.parse(text, src), Format.vcf, '');
        }
        return ImportResult(_fromTxt(text, src), f, '');
    }
  }

  static String sniffDelimiter(String text) {
    final sample = text.split('\n').take(20).join('\n');
    const cands = [',', ';', '\t', '|'];
    var best = ',';
    var bestScore = -1.0;
    for (final d in cands) {
      final counts = sample
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .map((l) => _countOutsideQuotes(l, d))
          .toList();
      if (counts.isEmpty) continue;
      final avg = counts.reduce((a, b) => a + b) / counts.length;
      if (avg == 0) continue;
      final consistent =
          counts.where((c) => c == counts.first).length / counts.length;
      final s = avg * consistent;
      if (s > bestScore) {
        bestScore = s;
        best = d;
      }
    }
    return best;
  }

  static int _countOutsideQuotes(String line, String d) {
    var q = false, n = 0;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') q = !q;
      if (!q && c == d) n++;
    }
    return n;
  }

  static List<List<String>> parseDelimited(String text, [String? delimiter]) {
    final d = delimiter ?? sniffDelimiter(text);
    final rows = <List<String>>[];
    var row = <String>[];
    final cell = StringBuffer();
    var q = false;
    var i = 0;
    final s = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    while (i < s.length) {
      final c = s[i];
      if (q) {
        if (c == '"') {
          if (i + 1 < s.length && s[i + 1] == '"') {
            cell.write('"');
            i++;
          } else {
            q = false;
          }
        } else {
          cell.write(c);
        }
      } else {
        if (c == '"' && cell.isEmpty) {
          q = true;
        } else if (c == d) {
          row.add(cell.toString());
          cell.clear();
        } else if (c == '\n') {
          row.add(cell.toString());
          cell.clear();
          if (row.any((e) => e.trim().isNotEmpty)) rows.add(row);
          row = <String>[];
        } else {
          cell.write(c);
        }
      }
      i++;
    }
    row.add(cell.toString());
    if (row.any((e) => e.trim().isNotEmpty)) rows.add(row);
    return rows;
  }

  static List<Person> _fromTxt(String text, String src) {
    final out = <Person>[];
    for (final rawLine in text.replaceAll('\r', '\n').split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final nums = Phones.extract(line);
      if (nums.isEmpty) continue;
      var rest = line;
      for (final n in nums) {
        rest = rest.replaceFirst(n, ' ');
      }
      final emails = RegExp(
        r'[^\s@,;<>]+@[^\s@,;<>]+\.[^\s@,;<>]+',
      ).allMatches(rest).map((m) => m.group(0)!).toList();
      for (final e in emails) {
        rest = rest.replaceFirst(e, ' ');
      }
      final name = rest
          .replaceAll(RegExp(r'[\t,;:|<>\-–—=•·：，；、()（）\[\]]+'), ' ')
          .replaceAll(
            RegExp(
              r'\b(tel|phone|mobile|cell|fax|ph|mob|hp)\b\.?',
              caseSensitive: false,
            ),
            ' ',
          )
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (out.isNotEmpty && name.isNotEmpty && out.last.name == name) {
        out.last.absorb(
          Person(
            name: name,
            phones: nums.map((n) => PhoneEntry(n)).toList(),
            emails: emails,
          ),
        );
        continue;
      }
      out.add(
        Person(
          name: name,
          phones: nums.map((n) => PhoneEntry(n)).toList(),
          emails: emails,
          source: src,
        ),
      );
    }
    return out;
  }

  static List<Person> _fromJson(dynamic data, String src) {
    final list = <Map>[];
    void collect(dynamic d, int depth) {
      if (depth > 4) return;
      if (d is List) {
        for (final x in d) {
          if (x is Map) {
            list.add(x);
          } else if (x is String && Phones.looksLikePhone(x)) {
            list.add({'phone': x});
          }
        }
      } else if (d is Map) {
        final keys = d.keys.map((k) => '$k'.toLowerCase()).toList();
        final looksPerson = keys.any(
          (k) =>
              k.contains('phone') ||
              k.contains('tel') ||
              k.contains('number') ||
              k.contains('mobile'),
        );
        if (looksPerson) {
          list.add(d);
          return;
        }
        for (final v in d.values) {
          collect(v, depth + 1);
        }
      }
    }

    collect(data, 0);
    final out = <Person>[];
    for (final m in list) {
      final flat = <String, dynamic>{};
      void flatten(Map mm, String prefix) {
        mm.forEach((k, v) {
          final key = prefix.isEmpty ? '$k' : '$prefix $k';
          if (v is Map) {
            flatten(v, key);
          } else {
            flat[key] = v;
          }
        });
      }

      flatten(m, '');
      var name = '', first = '', last = '', org = '', note = '';
      final phones = <PhoneEntry>[];
      final emails = <String>[];
      void addPhoneValue(dynamic v, String label) {
        if (v is String || v is num) {
          for (final p in Tabular.splitMulti('$v')) {
            if (Phones.digits(p).length >= 3) phones.add(PhoneEntry(p, label));
          }
        } else if (v is List) {
          for (final x in v) {
            if (x is Map) {
              final n = x['number'] ?? x['value'] ?? x['phone'] ?? x['tel'];
              final l = '${x['label'] ?? x['type'] ?? label}';
              if (n != null) addPhoneValue(n, l.toLowerCase());
            } else {
              addPhoneValue(x, label);
            }
          }
        }
      }

      flat.forEach((k, v) {
        if (v == null) return;
        final col = Tabular.classifyHeader(k);
        switch (col) {
          case Col.phone:
            addPhoneValue(
              v,
              k.toLowerCase().contains('work')
                  ? 'work'
                  : (k.toLowerCase().contains('home') ? 'home' : 'mobile'),
            );
          case Col.email:
            if (v is List) {
              for (final e in v) {
                final s = e is Map
                    ? '${e['address'] ?? e['value'] ?? e['email'] ?? ''}'
                    : '$e';
                if (s.contains('@')) emails.add(s);
              }
            } else if ('$v'.contains('@')) {
              emails.add('$v');
            }
          case Col.name:
            if (v is String && name.isEmpty) name = v;
          case Col.first:
            first = '$v';
          case Col.last:
            last = '$v';
          case Col.org:
            org = '$v';
          case Col.note:
            note = '$v';
          default:
            if (v is List && k.toLowerCase().contains('phone')) {
              addPhoneValue(v, 'mobile');
            }
        }
      });
      if (name.isEmpty) name = Tabular.joinName(first, '', last);
      if (phones.isEmpty && emails.isEmpty) continue;
      out.add(
        Person(
          name: name,
          phones: phones,
          emails: emails,
          org: org,
          note: note,
          source: src,
        ),
      );
    }
    return out;
  }

  static String formatNumber(String n, PhoneStyle s) => switch (s) {
    PhoneStyle.original => n.trim(),
    PhoneStyle.e164 => Phones.clean(n),
    PhoneStyle.digits => Phones.digits(n),
  };

  static List<List<String>> table(
    List<Person> people,
    ExportOptions o, {
    List<String>? headers,
  }) {
    final maxPhones = o.allNumbers
        ? people.fold<int>(
            1,
            (m, p) => p.phones.length > m ? p.phones.length : m,
          )
        : 1;
    final maxEmails = o.includeEmail
        ? people
              .fold<int>(1, (m, p) => p.emails.length > m ? p.emails.length : m)
              .clamp(1, 3)
        : 0;
    final h = <String>[
      headers?[0] ?? 'Name',
      for (var i = 0; i < maxPhones; i++)
        maxPhones == 1
            ? (headers?[1] ?? 'Phone')
            : '${headers?[1] ?? 'Phone'} ${i + 1}',
      for (var i = 0; i < maxEmails; i++)
        maxEmails == 1
            ? (headers?[2] ?? 'Email')
            : '${headers?[2] ?? 'Email'} ${i + 1}',
      if (o.includeOrg) headers?[3] ?? 'Company',
      if (o.includeNote) headers?[4] ?? 'Note',
    ];
    final rows = <List<String>>[if (o.header) h];
    for (final p in people) {
      rows.add([
        p.name.isNotEmpty
            ? p.name
            : (p.org.isNotEmpty && !o.includeOrg ? p.org : ''),
        for (var i = 0; i < maxPhones; i++)
          i < p.phones.length
              ? formatNumber(p.phones[i].number, o.phoneStyle)
              : '',
        for (var i = 0; i < maxEmails; i++)
          i < p.emails.length ? p.emails[i] : '',
        if (o.includeOrg) p.org,
        if (o.includeNote) p.note,
      ]);
    }
    return rows;
  }

  static String _csvCell(String v) {
    var s = v;
    if (RegExp(r'^[=+\-@]').hasMatch(s) &&
        !RegExp(r'^\+?[\d\s\-\(\)\.]+$').hasMatch(s)) {
      s = "'$s";
    }
    if (s.contains(',') ||
        s.contains('"') ||
        s.contains('\n') ||
        s.contains('\r')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  static Uint8List encode(
    List<Person> people,
    Format f,
    ExportOptions o, {
    List<String>? headers,
  }) {
    switch (f) {
      case Format.csv:
        final rows = table(people, o, headers: headers);
        final s = rows.map((r) => r.map(_csvCell).join(',')).join('\r\n');
        return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode('$s\r\n')]);
      case Format.vcf:
        final trimmed = people
            .map(
              (p) => Person(
                id: p.id,
                name: p.name,
                phones: o.allNumbers ? p.phones : p.phones.take(1).toList(),
                emails: o.includeEmail ? p.emails : [],
                org: o.includeOrg ? p.org : '',
                note: o.includeNote ? p.note : '',
              ),
            )
            .toList();
        return Uint8List.fromList(
          utf8.encode(
            VCard.write(trimmed, number: (n) => formatNumber(n, o.phoneStyle)),
          ),
        );
      case Format.xlsx:
      case Format.numbers:
        return Xlsx.write(table(people, o, headers: headers), rtl: o.rtl);
      case Format.txt:
        final b = StringBuffer();
        for (final p in people) {
          final nums = (o.allNumbers ? p.phones : p.phones.take(1)).map(
            (x) => formatNumber(x.number, o.phoneStyle),
          );
          if (o.txtWithNames) {
            for (final n in nums) {
              b.writeln(p.name.isEmpty ? n : '${p.displayName}\t$n');
            }
          } else {
            for (final n in nums) {
              b.writeln(n);
            }
          }
        }
        return Uint8List.fromList(utf8.encode(b.toString()));
      case Format.json:
        final list = people
            .map(
              (p) => {
                'name': p.name,
                'phones': (o.allNumbers ? p.phones : p.phones.take(1))
                    .map(
                      (x) => {
                        'number': formatNumber(x.number, o.phoneStyle),
                        'label': x.label,
                      },
                    )
                    .toList(),
                if (o.includeEmail) 'emails': p.emails,
                if (o.includeOrg && p.org.isNotEmpty) 'company': p.org,
                if (o.includeNote && p.note.isNotEmpty) 'note': p.note,
              },
            )
            .toList();
        return Uint8List.fromList(
          utf8.encode(
            const JsonEncoder.withIndent('  ').convert({
              'generator': 'Contact Flow',
              'exported_at': DateTime.now().toUtc().toIso8601String(),
              'count': list.length,
              'contacts': list,
            }),
          ),
        );
    }
  }
}

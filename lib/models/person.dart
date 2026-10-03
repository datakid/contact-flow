import 'dart:math';

class PhoneEntry {
  final String number;
  final String label;

  const PhoneEntry(this.number, [this.label = 'mobile']);

  String get digits => Phones.digits(number);

  Map<String, dynamic> toJson() => {'number': number, 'label': label};

  factory PhoneEntry.fromJson(Map m) =>
      PhoneEntry('${m['number'] ?? ''}', '${m['label'] ?? 'mobile'}');
}

class Person {
  final String id;
  String name;
  List<PhoneEntry> phones;
  List<String> emails;
  String org;
  String note;
  String source;
  final DateTime added;

  Person({
    String? id,
    required this.name,
    List<PhoneEntry>? phones,
    List<String>? emails,
    this.org = '',
    this.note = '',
    this.source = '',
    DateTime? added,
  }) : id = id ?? _newId(),
       phones = phones ?? [],
       emails = emails ?? [],
       added = added ?? DateTime.now();

  static final _rand = Random();
  static int _seq = 0;
  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${(_seq++).toRadixString(36)}${_rand.nextInt(1 << 20).toRadixString(36)}';

  String get displayName {
    if (name.trim().isNotEmpty) return name.trim();
    if (org.trim().isNotEmpty) return org.trim();
    if (phones.isNotEmpty) return phones.first.number;
    if (emails.isNotEmpty) return emails.first;
    return '—';
  }

  bool get hasName => name.trim().isNotEmpty || org.trim().isNotEmpty;

  String get primaryNumber => phones.isEmpty ? '' : phones.first.number;

  Set<String> get phoneKeys => phones
      .map((p) => Phones.key(p.number))
      .where((k) => k.isNotEmpty)
      .toSet();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phones': phones.map((p) => p.toJson()).toList(),
    'emails': emails,
    'org': org,
    'note': note,
    'source': source,
    'added': added.millisecondsSinceEpoch,
  };

  factory Person.fromJson(Map m) => Person(
    id: m['id'] as String?,
    name: '${m['name'] ?? ''}',
    phones: ((m['phones'] as List?) ?? [])
        .whereType<Map>()
        .map(PhoneEntry.fromJson)
        .toList(),
    emails: ((m['emails'] as List?) ?? []).map((e) => '$e').toList(),
    org: '${m['org'] ?? ''}',
    note: '${m['note'] ?? ''}',
    source: '${m['source'] ?? ''}',
    added: m['added'] is int
        ? DateTime.fromMillisecondsSinceEpoch(m['added'] as int)
        : null,
  );

  void absorb(Person other) {
    if (!hasName && other.hasName) name = other.name;
    final keys = phoneKeys;
    for (final p in other.phones) {
      final k = Phones.key(p.number);
      if (k.isNotEmpty && !keys.contains(k)) {
        phones.add(p);
        keys.add(k);
      }
    }
    final mails = emails.map((e) => e.toLowerCase()).toSet();
    for (final e in other.emails) {
      if (mails.add(e.toLowerCase())) emails.add(e);
    }
    if (org.isEmpty) org = other.org;
    if (note.isEmpty) note = other.note;
  }
}

class Phones {
  static const _digitBlocks = [0x0660, 0x06F0, 0xFF10, 0x0966];

  static String asciiDigits(String s) {
    final b = StringBuffer();
    for (final r in s.runes) {
      var mapped = false;
      for (final base in _digitBlocks) {
        if (r >= base && r <= base + 9) {
          b.writeCharCode(0x30 + r - base);
          mapped = true;
          break;
        }
      }
      if (!mapped) {
        if (r == 0xFF0B) {
          b.write('+');
        } else {
          b.writeCharCode(r);
        }
      }
    }
    return b.toString();
  }

  static String digits(String s) =>
      asciiDigits(s).replaceAll(RegExp(r'[^0-9]'), '');

  static String clean(String s) {
    final a = asciiDigits(s).trim();
    final d = a.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.isEmpty) return '';
    if (a.startsWith('+')) return '+$d';
    if (d.startsWith('00') && d.length > 9) return '+${d.substring(2)}';
    return d;
  }

  static String key(String s) {
    final d = digits(s);
    if (d.length < 5) return '';
    return d.length > 9 ? d.substring(d.length - 9) : d;
  }

  static bool looksLikePhone(String s) {
    final t = asciiDigits(s).trim();
    if (t.isEmpty || t.length > 32) return false;
    if (!RegExp(
      r'^[+(]?[0-9][0-9\s\-\.\(\)/]*(?:\s*(?:x|ext\.?|#)\s*\d+)?$',
      caseSensitive: false,
    ).hasMatch(t)) {
      return false;
    }
    final d = t.replaceAll(RegExp(r'[^0-9]'), '');
    return d.length >= 5 && d.length <= 17;
  }

  static final finder = RegExp(
    r'(?:\+|00)?[0-9٠-٩۰-۹０-９(][0-9٠-٩۰-۹０-９\s\-\.\(\)/]{3,}[0-9٠-٩۰-۹０-９]',
  );

  static List<String> extract(String text) {
    final out = <String>[];
    for (final m in finder.allMatches(text)) {
      final raw = m.group(0)!.trim();
      final d = digits(raw);
      if (d.length >= 5 && d.length <= 17) out.add(raw);
    }
    return out;
  }
}

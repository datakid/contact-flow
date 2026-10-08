import '../models/person.dart';

Person clonePerson(Person p) => p.copy();

bool samePerson(Person a, Person b) {
  if (a.name != b.name || a.org != b.org || a.note != b.note) return false;
  if (a.aliases.join('\u0000') != b.aliases.join('\u0000')) return false;
  if (a.phones.length != b.phones.length) return false;
  for (var i = 0; i < a.phones.length; i++) {
    if (a.phones[i].number != b.phones[i].number ||
        a.phones[i].label != b.phones[i].label) {
      return false;
    }
  }
  if (a.emails.length != b.emails.length) return false;
  for (var i = 0; i < a.emails.length; i++) {
    if (a.emails[i] != b.emails[i]) return false;
  }
  return true;
}

enum CaseMode { title, upper, lower }

enum NumFormat { e164, digits, spaced }

sealed class BatchOp {
  const BatchOp();
  void apply(Person p, int index);

  static List<(Person before, Person after)> run(
    BatchOp op,
    List<Person> people,
  ) {
    final out = <(Person, Person)>[];
    for (var i = 0; i < people.length; i++) {
      final before = people[i];
      final after = clonePerson(before);
      op.apply(after, i);
      if (!samePerson(before, after)) out.add((before, after));
    }
    return out;
  }
}

class ReplaceInName extends BatchOp {
  final String find;
  final String replace;
  final bool ignoreCase;
  const ReplaceInName(this.find, this.replace, {this.ignoreCase = true});
  @override
  void apply(Person p, int index) {
    if (find.isEmpty) return;
    p.name = _replaceAll(p.name, find, replace, ignoreCase);
    p.name = TextOps.squash(p.name);
  }
}

class AffixName extends BatchOp {
  final String prefix;
  final String suffix;
  const AffixName({this.prefix = '', this.suffix = ''});
  @override
  void apply(Person p, int index) {
    if (prefix.isEmpty && suffix.isEmpty) return;
    var n = p.name.trim();
    if (prefix.isNotEmpty && !n.startsWith(prefix)) n = '$prefix$n';
    if (suffix.isNotEmpty && !n.endsWith(suffix)) n = '$n$suffix';
    p.name = n;
  }
}

class CaseName extends BatchOp {
  final CaseMode mode;
  const CaseName(this.mode);
  @override
  void apply(Person p, int index) {
    p.name = switch (mode) {
      CaseMode.upper => p.name.toUpperCase(),
      CaseMode.lower => p.name.toLowerCase(),
      CaseMode.title => TextOps.title(p.name),
    };
  }
}

class CleanName extends BatchOp {
  const CleanName();
  @override
  void apply(Person p, int index) {
    var n = p.name.replaceAll(
      RegExp(r'[\u200B-\u200F\u202A-\u202E\uFEFF]'),
      '',
    );
    n = n.replaceAll(
      RegExp(r'^[^\p{L}\p{N}]+|[^\p{L}\p{N}.)]+$', unicode: true),
      '',
    );
    p.name = TextOps.squash(n);
  }
}

class AddAlias extends BatchOp {
  final String alias;
  const AddAlias(this.alias);
  @override
  void apply(Person p, int index) {
    final a = TextOps.squash(alias);
    if (a.isEmpty) return;
    p.aliases = Aliases.union([
      p.aliases,
      [a],
    ], name: p.name);
  }
}

class KeepNameAsAlias extends BatchOp {
  const KeepNameAsAlias();
  @override
  void apply(Person p, int index) {
    final n = TextOps.squash(p.name);
    if (n.isEmpty) return;
    final next = Aliases.union([
      p.aliases,
      [n],
    ]);
    if (next.length != p.aliases.length) p.aliases = next;
  }
}

class PromoteAlias extends BatchOp {
  const PromoteAlias();
  @override
  void apply(Person p, int index) {
    final list = p.cleanAliases;
    if (list.isEmpty) return;
    final old = p.name.trim();
    p.name = list.first;
    p.aliases = Aliases.clean([
      ...list.skip(1),
      if (old.isNotEmpty) old,
    ], name: p.name);
  }
}

class ClearAliases extends BatchOp {
  const ClearAliases();
  @override
  void apply(Person p, int index) {
    if (p.aliases.isNotEmpty) p.aliases = [];
  }
}

class SwapName extends BatchOp {
  const SwapName();
  @override
  void apply(Person p, int index) {
    final parts = TextOps.squash(p.name).split(' ');
    if (parts.length < 2) return;
    final last = parts.removeLast();
    p.name = '$last ${parts.join(' ')}';
  }
}

class TemplateName extends BatchOp {
  final String template;
  final int start;
  final int pad;
  final bool onlyEmpty;
  const TemplateName(
    this.template, {
    this.start = 1,
    this.pad = 0,
    this.onlyEmpty = false,
  });

  String render(Person p, int index) {
    final parts = TextOps.squash(p.name).split(' ');
    final first = parts.isEmpty ? '' : parts.first;
    final last = parts.length > 1 ? parts.last : '';
    final n = (start + index).toString().padLeft(pad, '0');
    return TextOps.squash(
      template
          .replaceAll('{name}', p.name.trim())
          .replaceAll('{first}', first)
          .replaceAll('{last}', last)
          .replaceAll('{company}', p.org.trim())
          .replaceAll(
            '{alias}',
            p.cleanAliases.isEmpty ? '' : p.cleanAliases.first,
          )
          .replaceAll('{n}', n),
    );
  }

  @override
  void apply(Person p, int index) {
    if (template.trim().isEmpty) return;
    if (onlyEmpty && p.name.trim().isNotEmpty) return;
    p.name = render(p, index);
  }
}

class ReplaceInNumbers extends BatchOp {
  final String find;
  final String replace;

  final bool prefixOnly;
  const ReplaceInNumbers(this.find, this.replace, {this.prefixOnly = true});

  @override
  void apply(Person p, int index) {
    if (find.trim().isEmpty) return;
    p.phones = [for (final e in p.phones) PhoneEntry(_one(e.number), e.label)];
  }

  String _one(String n) {
    if (!prefixOnly) return n.replaceAll(find, replace);
    final f = Phones.asciiDigits(find).replaceAll(RegExp(r'[\s\-.()/]'), '');
    final compact = Phones.asciiDigits(n).replaceAll(RegExp(r'[\s\-.()/]'), '');
    if (!compact.startsWith(f)) return n;
    return '$replace${compact.substring(f.length)}';
  }
}

class AddCountryCode extends BatchOp {
  final String code;
  const AddCountryCode(this.code);

  static String normalizeCode(String raw) =>
      Phones.digits(raw).replaceFirst(RegExp(r'^0+'), '');

  @override
  void apply(Person p, int index) {
    final cc = normalizeCode(code);
    if (cc.isEmpty) return;
    p.phones = [
      for (final e in p.phones) PhoneEntry(_one(e.number, cc), e.label),
    ];
  }

  static String _one(String n, String cc) {
    final a = Phones.asciiDigits(n).trim();
    if (a.startsWith('+')) return n;
    final d = Phones.digits(a);
    if (d.isEmpty) return n;
    if (d.startsWith('00') && d.length > 9) return '+${d.substring(2)}';
    if (d.startsWith(cc) && d.length > cc.length + 7) return '+$d';
    final local = d.startsWith('0') ? d.substring(1) : d;
    return '+$cc$local';
  }
}

class RemoveCountryCode extends BatchOp {
  final String code;
  final bool addTrunkZero;
  const RemoveCountryCode(this.code, {this.addTrunkZero = true});
  @override
  void apply(Person p, int index) {
    final cc = AddCountryCode.normalizeCode(code);
    if (cc.isEmpty) return;
    p.phones = [
      for (final e in p.phones) PhoneEntry(_one(e.number, cc), e.label),
    ];
  }

  String _one(String n, String cc) {
    final c = Phones.clean(n);
    if (!c.startsWith('+$cc')) return n;
    final rest = c.substring(cc.length + 1);
    return addTrunkZero ? '0$rest' : rest;
  }
}

class FormatNumbers extends BatchOp {
  final NumFormat format;
  const FormatNumbers(this.format);
  @override
  void apply(Person p, int index) {
    p.phones = [for (final e in p.phones) PhoneEntry(_one(e.number), e.label)];
  }

  String _one(String n) {
    final c = Phones.clean(n);
    if (c.isEmpty) return n;
    switch (format) {
      case NumFormat.e164:
        return c;
      case NumFormat.digits:
        return Phones.digits(c);
      case NumFormat.spaced:
        final plus = c.startsWith('+');
        final d = Phones.digits(c);
        final groups = <String>[];
        var i = d.length;
        final sizes = [4, 3, 3, 3, 3, 3];
        var k = 0;
        while (i > 0) {
          final size = k < sizes.length ? sizes[k] : 3;
          final s = i - size < 0 ? 0 : i - size;
          groups.insert(0, d.substring(s, i));
          i = s;
          k++;
        }
        return '${plus ? '+' : ''}${groups.join(' ')}';
    }
  }
}

class DedupeNumbers extends BatchOp {
  const DedupeNumbers();
  @override
  void apply(Person p, int index) {
    final seen = <String>{};
    p.phones = [
      for (final e in p.phones)
        if (seen.add(
          Phones.key(e.number).isEmpty ? e.number : Phones.key(e.number),
        ))
          e,
    ];
  }
}

class LabelNumbers extends BatchOp {
  final String label;
  const LabelNumbers(this.label);
  @override
  void apply(Person p, int index) {
    p.phones = [for (final e in p.phones) PhoneEntry(e.number, label)];
  }
}

class SetCompany extends BatchOp {
  final String value;
  final bool onlyEmpty;
  const SetCompany(this.value, {this.onlyEmpty = false});
  @override
  void apply(Person p, int index) {
    if (onlyEmpty && p.org.trim().isNotEmpty) return;
    p.org = value.trim();
  }
}

class SetNote extends BatchOp {
  final String value;
  final bool append;
  const SetNote(this.value, {this.append = true});
  @override
  void apply(Person p, int index) {
    final v = value.trim();
    if (append) {
      if (v.isEmpty || p.note.contains(v)) return;
      p.note = p.note.trim().isEmpty ? v : '${p.note.trim()}\n$v';
    } else {
      p.note = v;
    }
  }
}

class TextOps {
  static String squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  static String title(String s) {
    final b = StringBuffer();
    var start = true;
    for (final ch in s.characters()) {
      final isLetter = RegExp(r'\p{L}', unicode: true).hasMatch(ch);
      if (isLetter) {
        b.write(start ? ch.toUpperCase() : ch.toLowerCase());
        start = false;
      } else {
        b.write(ch);
        start = ch == ' ' || ch == '-' || ch == '\'' || ch == '.' || ch == '(';
      }
    }
    return b.toString();
  }
}

extension on String {
  Iterable<String> characters() => runes.map(String.fromCharCode);
}

String _replaceAll(String s, String find, String rep, bool ignoreCase) {
  if (!ignoreCase) return s.replaceAll(find, rep);
  return s.replaceAll(RegExp(RegExp.escape(find), caseSensitive: false), rep);
}

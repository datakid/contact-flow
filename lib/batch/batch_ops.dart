import 'package:phone_numbers_parser/phone_numbers_parser.dart' show IsoCode;

import '../domain/names.dart';
import '../models/person.dart';
import '../phone/phone_key.dart';

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

  bool skips(Person p) => false;

  String? get skipKey => null;

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
  String get skipKey => 'swapSkipped';

  @override
  bool skips(Person p) {
    final t = TextOps.squash(p.name);
    return t.contains(' ') && !NameSplit.of(t).clear;
  }

  @override
  void apply(Person p, int index) {
    final t = TextOps.squash(p.name);
    if (!t.contains(' ')) return;
    final n = NameSplit.of(t);
    if (!n.clear || n.first.isEmpty || n.last.isEmpty) return;
    p.name = '${n.last} ${n.first}';
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
    final name = TextOps.squash(p.name);
    final clear = NameSplit.of(name).clear;
    final parts = name.split(' ');
    final first = !clear ? name : (parts.isEmpty ? '' : parts.first);
    final last = !clear ? '' : (parts.length > 1 ? parts.last : '');
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

bool _hasUnreadableNumber(Person p) {
  for (final e in p.phones) {
    final i = PhoneKey.info(e.number);
    if (!i.isEmpty && i.parsed == null) return true;
  }
  return false;
}

String _withExtension(String body, String original) {
  final ext = PhoneKey.extension(original);
  return ext.isEmpty ? body : '$body x$ext';
}

class AddCountryCode extends BatchOp {
  final String code;
  const AddCountryCode(this.code);

  static String normalizeCode(String raw) =>
      Phones.digits(raw).replaceFirst(RegExp(r'^0+'), '');

  @override
  String get skipKey => 'numbersUnread';

  @override
  bool skips(Person p) =>
      _hasUnreadableNumber(p) &&
      PhoneKey.mainRegionForCode(normalizeCode(code)) != null;

  @override
  void apply(Person p, int index) {
    final region = PhoneKey.mainRegionForCode(normalizeCode(code));
    if (region == null) return;
    p.phones = [
      for (final e in p.phones) PhoneEntry(_one(e.number, region), e.label),
    ];
  }

  static String _one(String n, IsoCode region) {
    if (Phones.asciiDigits(n).trim().startsWith('+')) return n;
    final i = PhoneKey.infoIn(n, region);
    final e164 = i.e164;
    if (e164 == null) return n;
    return _withExtension(e164, n);
  }
}

class RemoveCountryCode extends BatchOp {
  final String code;
  final bool addTrunkZero;
  const RemoveCountryCode(this.code, {this.addTrunkZero = true});

  @override
  String get skipKey => 'numbersUnread';

  @override
  bool skips(Person p) => _hasUnreadableNumber(p);

  @override
  void apply(Person p, int index) {
    final cc = AddCountryCode.normalizeCode(code);
    if (cc.isEmpty) return;
    p.phones = [
      for (final e in p.phones) PhoneEntry(_one(e.number, cc), e.label),
    ];
  }

  String _one(String n, String cc) {
    final i = PhoneKey.info(n);
    final pn = i.parsed;
    if (!i.explicit || pn == null || pn.countryCode != cc) return n;
    final national = PhoneKey.national(n);
    return national == null ? n : _withExtension(national, n);
  }
}

class FormatNumbers extends BatchOp {
  final NumFormat format;
  const FormatNumbers(this.format);

  @override
  String? get skipKey => format == NumFormat.spaced ? 'numbersUnread' : null;

  @override
  bool skips(Person p) => format == NumFormat.spaced && _hasUnreadableNumber(p);

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
        final i = PhoneKey.info(n);
        final text = i.explicit
            ? PhoneKey.international(n)
            : PhoneKey.national(n);
        return text == null ? n : _withExtension(text, n);
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
  static final _spaces = RegExp(r'\s+');
  static final _letter = RegExp(r'\p{L}', unicode: true);

  static String squash(String s) => s.replaceAll(_spaces, ' ').trim();

  static String title(String s) {
    final b = StringBuffer();
    var start = true;
    for (final ch in s.characters()) {
      final isLetter = _letter.hasMatch(ch);
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

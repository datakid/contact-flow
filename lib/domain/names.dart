import '../search/fold.dart';

class NameSplit {
  final String first;
  final String last;
  final bool clear;
  const NameSplit(this.first, this.last, {this.clear = true});

  static const _strong = {
    'bin',
    'ibn',
    'bint',
    'abu',
    'abo',
    'abd',
    'abdul',
    'abdel',
    'abdal',
  };
  static const _weak = {'al', 'el', 'ul'};

  static bool _hasParticle(List<String> words) {
    for (var i = 0; i < words.length; i++) {
      final w = words[i].toLowerCase();
      if (_strong.contains(w)) return true;
      if (i == 0) continue;
      if (_weak.contains(w) || w.startsWith('al-') || w.startsWith('el-')) {
        return true;
      }
    }
    return false;
  }

  static NameSplit of(String full) {
    final t = full.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.isEmpty) return const NameSplit('', '');
    if (Fold.hasArabic(t)) return NameSplit(t, '', clear: false);
    if (Fold.hasCjk(t) && !t.contains(' ')) {
      final runes = t.runes.toList();
      if (runes.length == 1) return NameSplit(t, '');
      return NameSplit(
        String.fromCharCodes(runes.skip(1)),
        String.fromCharCode(runes.first),
      );
    }
    final parts = t.split(' ');
    if (parts.length == 1) return NameSplit(t, '');
    if (_hasParticle(parts)) return NameSplit(t, '', clear: false);
    final last = parts.removeLast();
    return NameSplit(parts.join(' '), last);
  }
}

class NameParts {
  final String first;
  final String last;
  const NameParts(this.first, this.last);

  static NameParts of(String full) {
    final s = NameSplit.of(full);
    return NameParts(s.first, s.last);
  }

  static String normalized(String full) => Fold.basic(full)
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim()
      .split(' ')
      .where((w) => w.isNotEmpty)
      .join(' ');
}

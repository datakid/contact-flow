import '../search/fold.dart';

class NameParts {
  final String first;
  final String last;
  const NameParts(this.first, this.last);

  static NameParts of(String full) {
    final t = full.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.isEmpty) return const NameParts('', '');
    if (Fold.hasCjk(t) && !t.contains(' ')) {
      final runes = t.runes.toList();
      if (runes.length == 1) return NameParts(t, '');
      return NameParts(
        String.fromCharCodes(runes.skip(1)),
        String.fromCharCode(runes.first),
      );
    }
    final parts = t.split(' ');
    if (parts.length == 1) return NameParts(t, '');
    final last = parts.removeLast();
    return NameParts(parts.join(' '), last);
  }

  static String normalized(String full) => Fold.basic(full)
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim()
      .split(' ')
      .where((w) => w.isNotEmpty)
      .join(' ');
}

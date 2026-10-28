import '../models/person.dart';
import '../tags/tag_models.dart';
import 'call_models.dart';
import 'saved_numbers.dart';

class CallGrouper {
  static const shortCodeDigits = 6;

  static bool isShortCode(String raw) =>
      Phones.digits(raw).length < shortCodeDigits;

  static List<CallGroup> group(
    Iterable<CallRecord> calls, {
    required SavedNumbers saved,
    Set<String> ignored = const {},
    bool showHidden = false,
  }) {
    final byRaw = <String, CallGroup>{};
    final hiddenKeys = <String>{};
    for (final c in calls) {
      if (c.hiddenNumber) {
        if (!showHidden) continue;
      }
      final digits = Phones.digits(c.number);
      final cheap = c.hiddenNumber ? 'hidden:${c.number}' : digits;
      if (cheap.isEmpty) continue;
      final g = byRaw[cheap] ??= CallGroup('', c.number);
      g.add(c);
      if (c.hiddenNumber) hiddenKeys.add(cheap);
    }
    final byKey = <String, CallGroup>{};
    byRaw.forEach((cheap, g) {
      final hidden = hiddenKeys.contains(cheap);
      var key = hidden ? cheap : TagKey.of(g.number);
      if (key.isEmpty) key = 's:${Phones.digits(g.number)}';
      if (!hidden) {
        if (!showHidden && isShortCode(g.number)) return;
        if (ignored.contains(key)) return;
        if (saved.has(g.number)) return;
      }
      final merged = byKey[key];
      if (merged == null) {
        byKey[key] = CallGroup(key, g.number)
          ..count = g.count
          ..incoming = g.incoming
          ..outgoing = g.outgoing
          ..missed = g.missed
          ..lastMs = g.lastMs
          ..talkSec = g.talkSec
          ..cachedName = g.cachedName
          ..calls.addAll(g.calls);
      } else {
        merged
          ..calls.addAll(g.calls)
          ..count += g.count
          ..incoming += g.incoming
          ..outgoing += g.outgoing
          ..missed += g.missed
          ..talkSec += g.talkSec;
        if (g.lastMs >= merged.lastMs) {
          merged
            ..lastMs = g.lastMs
            ..number = g.number;
        }
        if (merged.cachedName.isEmpty) merged.cachedName = g.cachedName;
      }
    });
    final out = byKey.values.toList()
      ..sort((a, b) => b.lastMs.compareTo(a.lastMs));
    return out;
  }
}

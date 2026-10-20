import '../l10n.dart';
import '../search/number_pattern.dart';
import 'call_models.dart';

class CallFilter {
  final int minCalls;
  final int minTalkSec;
  final int? lastDays;
  final bool missedOnly;
  final bool outgoingOnly;
  final String pattern;
  const CallFilter({
    this.minCalls = 0,
    this.minTalkSec = 0,
    this.lastDays,
    this.missedOnly = false,
    this.outgoingOnly = false,
    this.pattern = '',
  });

  bool get isEmpty =>
      minCalls <= 0 &&
      minTalkSec <= 0 &&
      lastDays == null &&
      !missedOnly &&
      !outgoingOnly &&
      pattern.trim().isEmpty;

  CallFilter copyWith({
    int? minCalls,
    int? minTalkSec,
    int? lastDays,
    bool clearLastDays = false,
    bool? missedOnly,
    bool? outgoingOnly,
    String? pattern,
  }) => CallFilter(
    minCalls: minCalls ?? this.minCalls,
    minTalkSec: minTalkSec ?? this.minTalkSec,
    lastDays: clearLastDays ? null : (lastDays ?? this.lastDays),
    missedOnly: missedOnly ?? this.missedOnly,
    outgoingOnly: outgoingOnly ?? this.outgoingOnly,
    pattern: pattern ?? this.pattern,
  );

  List<CallGroup> apply(
    Iterable<CallGroup> groups,
    DateTime now, {
    bool Function(CallGroup, String)? hasTag,
  }) {
    final q = pattern.trim().isEmpty ? null : NumberQuery.parse(pattern);
    final cutoff = lastDays == null
        ? null
        : now.subtract(Duration(days: lastDays!)).millisecondsSinceEpoch;
    final out = <CallGroup>[];
    for (final g in groups) {
      if (g.count < minCalls) continue;
      if (g.talkSec < minTalkSec) continue;
      if (cutoff != null && g.lastMs < cutoff) continue;
      if (missedOnly && g.missed != g.count) continue;
      if (outgoingOnly && g.outgoing != g.count) continue;
      if (q != null && q.isPattern) {
        final s = q.score(
          [PhoneForms.of(g.number)],
          hasTag: hasTag == null ? null : (t) => hasTag(g, t),
        );
        if (s == null) continue;
      }
      out.add(g);
    }
    return out;
  }
}

class CallSelection {
  final Set<String> included = {};
  final Set<String> excluded = {};

  void include(String key) {
    excluded.remove(key);
    included.add(key);
  }

  void exclude(String key) {
    included.remove(key);
    excluded.add(key);
  }

  void clear(String key) {
    included.remove(key);
    excluded.remove(key);
  }

  void toggle(String key) {
    if (included.contains(key)) {
      included.remove(key);
    } else {
      include(key);
    }
  }

  void includeAll(Iterable<String> shown) {
    for (final k in shown) {
      if (!excluded.contains(k)) included.add(k);
    }
  }

  void includeRange(List<String> shown, int from, int to) {
    final a = from < to ? from : to;
    final b = from < to ? to : from;
    for (var i = a; i <= b && i < shown.length; i++) {
      if (i >= 0) include(shown[i]);
    }
  }

  void invert(Iterable<String> shown) {
    for (final k in shown) {
      if (excluded.contains(k)) continue;
      if (included.contains(k)) {
        included.remove(k);
      } else {
        included.add(k);
      }
    }
  }

  void clearAll() {
    included.clear();
    excluded.clear();
  }

  String counterText(L l) =>
      '${l.n(included.length, 'selected_one', 'selected_many')} · '
      '${l.n(excluded.length, 'excluded_one', 'excluded_many')}';

  bool isIncluded(String key) => included.contains(key);

  bool isExcluded(String key) => excluded.contains(key);

  List<CallGroup> chosen(Iterable<CallGroup> all) => [
    for (final g in all)
      if (included.contains(g.key)) g,
  ];
}

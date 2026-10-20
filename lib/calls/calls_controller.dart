import 'package:flutter/foundation.dart';

import '../domain/phone_dupes.dart';
import '../models/person.dart';
import '../tags/tag_book.dart';
import 'call_filter.dart';
import 'call_grouper.dart';
import 'call_models.dart';
import 'call_naming.dart';
import 'call_source.dart';
import 'ignore_book.dart';
import 'saved_numbers.dart';

enum CallsPhase { idle, needPermission, loading, ready, error }

class CallSaveResult {
  final int saved;
  final int alreadyThere;
  const CallSaveResult(this.saved, this.alreadyThere);
}

class CallsController extends ChangeNotifier {
  final CallSource source;
  final List<Person> Function() contacts;
  final Future<void> Function() refreshContacts;
  final Future<void> Function(List<Person>) saveToPhone;
  final IgnoreBook ignore;
  final TagBook? tags;
  final DateTime Function() now;

  CallsController({
    required this.source,
    required this.contacts,
    required this.refreshContacts,
    required this.saveToPhone,
    required this.ignore,
    this.tags,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  CallsPhase phase = CallsPhase.idle;
  int progress = 0;
  Object? error;
  CallFilter filter = const CallFilter();
  bool showHidden = false;
  final CallSelection selection = CallSelection();

  List<CallRecord> _records = const [];
  List<CallGroup> _all = const [];
  List<CallGroup> _shown = const [];

  List<CallGroup> get all => _all;
  List<CallGroup> get shown => _shown;

  Future<void> start() async {
    try {
      if (await source.hasPermission()) {
        await load();
      } else {
        phase = CallsPhase.needPermission;
        notifyListeners();
      }
    } catch (e) {
      error = e;
      phase = CallsPhase.error;
      notifyListeners();
    }
  }

  Future<void> grant() async {
    try {
      if (await source.request()) {
        await load();
      } else {
        phase = CallsPhase.needPermission;
        notifyListeners();
      }
    } catch (e) {
      error = e;
      phase = CallsPhase.error;
      notifyListeners();
    }
  }

  Future<void> load() async {
    phase = CallsPhase.loading;
    progress = 0;
    error = null;
    notifyListeners();
    try {
      _records = await source.readAll(
        onPage: (n) {
          progress = n;
          notifyListeners();
        },
      );
      _regroup();
      phase = CallsPhase.ready;
    } catch (e) {
      error = e;
      phase = CallsPhase.error;
    }
    notifyListeners();
  }

  void _regroup() {
    _all = CallGrouper.group(
      _records,
      saved: SavedNumbers.of(contacts()),
      ignored: ignore.keys,
      showHidden: showHidden,
    );
    final keys = {for (final g in _all) g.key};
    selection.included.removeWhere((k) => !keys.contains(k));
    selection.excluded.removeWhere((k) => !keys.contains(k));
    _refilter();
  }

  void _refilter() {
    _shown = filter.apply(
      _all,
      now(),
      hasTag: tags == null
          ? null
          : (g, t) => tags!.tagsForNumber(g.number).any(
              (x) => x.name.toLowerCase() == t,
            ),
    );
  }

  void setFilter(CallFilter f) {
    filter = f;
    _refilter();
    notifyListeners();
  }

  void setShowHidden(bool v) {
    if (v == showHidden) return;
    showHidden = v;
    _regroup();
    notifyListeners();
  }

  void includeAllShown() {
    selection.includeAll(_shown.map((g) => g.key));
    notifyListeners();
  }

  void invertShown() {
    selection.invert(_shown.map((g) => g.key));
    notifyListeners();
  }

  void include(CallGroup g) {
    selection.include(g.key);
    notifyListeners();
  }

  void exclude(CallGroup g) {
    selection.exclude(g.key);
    notifyListeners();
  }

  void toggle(CallGroup g) {
    selection.toggle(g.key);
    notifyListeners();
  }

  void clearSelection() {
    selection.clearAll();
    notifyListeners();
  }

  Future<VoidCallback> ignoreNumbers(Iterable<CallGroup> groups) async {
    final added = <String, String>{};
    for (final g in groups) {
      added[g.key] = g.number;
    }
    await ignore.addKeys(added);
    _regroup();
    notifyListeners();
    return () {
      ignore.remove(added.keys).then((_) {
        _regroup();
        notifyListeners();
      });
    };
  }

  Future<int> tagChosen(Iterable<String> tagIds) async {
    final book = tags;
    if (book == null) return 0;
    final numbers = [for (final g in selection.chosen(_all)) g.number];
    return book.assign(tagIds, numbers);
  }

  List<Person> drafts(String template, {int start = 1}) {
    final chosen = selection.chosen(_all);
    return [
      for (var i = 0; i < chosen.length; i++)
        CallNaming.draft(
          _nameFor(chosen[i], template, i, start),
          chosen[i].number,
        ),
    ];
  }

  String _nameFor(CallGroup g, String template, int i, int start) {
    final tag = tags?.tagsForNumber(g.number).firstOrNull?.name ?? '';
    final name = CallNaming.render(
      template,
      index: i,
      number: g.number,
      tag: tag,
      start: start,
    );
    return name.isEmpty ? g.number : name;
  }

  Future<CallSaveResult> save(String template, {int start = 1}) async {
    final planned = drafts(template, start: start);
    await refreshContacts();
    final (fresh, already) = PhoneDupes.split(planned, contacts());
    if (fresh.isNotEmpty) await saveToPhone(fresh);
    final savedNumbers = {for (final p in fresh) p.phones.first.number};
    for (final g in selection.chosen(_all)) {
      if (savedNumbers.contains(g.number)) selection.clear(g.key);
    }
    _regroup();
    notifyListeners();
    return CallSaveResult(fresh.length, already.length);
  }
}

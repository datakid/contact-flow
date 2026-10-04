import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../io/codec.dart';
import '../models/person.dart';
import '../search/fold.dart';
import '../search/fuzzy.dart';
import '../services/library_store.dart';

enum SortMode { name, recent }

class ImportPlan {
  final List<Person> incoming;
  final List<Person> fresh;
  final List<(Person, Person)> dupes;
  final List<String> sources;
  final Map<Format, int> formats;
  const ImportPlan(
    this.incoming,
    this.fresh,
    this.dupes,
    this.sources,
    this.formats,
  );
}

class AppState extends ChangeNotifier {
  final _store = LibraryStore();
  final _index = FuzzyIndex();
  List<Person> _people = [];
  List<Person> _sorted = [];
  List<Hit> _hits = [];
  final Set<String> selected = {};
  String _query = '';
  SortMode sort = SortMode.name;
  ThemeMode themeMode = ThemeMode.system;
  String lang = 'en';
  bool ready = false;
  bool _dirtyIndex = true;
  List<Person>? _indexed;
  Timer? _debounce;
  ExportOptions exportOptions = const ExportOptions();
  Format lastFormat = Format.csv;

  List<Person> get people => _people;
  String get query => _query;
  bool get searching => _query.trim().isNotEmpty;
  bool get selecting => selected.isNotEmpty;
  int get phoneCount => _people.fold(0, (s, p) => s + p.phones.length);

  List<Person> get visible =>
      searching ? _hits.map((h) => h.person).toList() : _sorted;
  List<Hit> get hits => _hits;

  Hit? hitFor(Person p) {
    if (!searching) return null;
    for (final h in _hits) {
      if (identical(h.person, p)) return h;
    }
    return null;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    themeMode = ThemeMode.values[(prefs.getInt('theme') ?? 0).clamp(0, 2)];
    final sys = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    lang =
        prefs.getString('lang') ??
        (const ['en', 'ar', 'zh', 'es', 'fr'].contains(sys) ? sys : 'en');
    sort = SortMode.values[(prefs.getInt('sort') ?? 0).clamp(0, 1)];
    lastFormat = Format
        .values[(prefs.getInt('fmt') ?? 0).clamp(0, Format.values.length - 1)];
    try {
      await _store.open();
      _people = _store.load();
    } catch (_) {
      _people = [];
    }
    _resort();
    ready = true;
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode m) async {
    themeMode = m;
    notifyListeners();
    (await SharedPreferences.getInstance()).setInt('theme', m.index);
  }

  Future<void> setLang(String l) async {
    lang = l;
    _resort();
    notifyListeners();
    (await SharedPreferences.getInstance()).setString('lang', l);
  }

  Future<void> setSort(SortMode s) async {
    sort = s;
    _resort();
    notifyListeners();
    (await SharedPreferences.getInstance()).setInt('sort', s.index);
  }

  Future<void> rememberFormat(Format f) async {
    lastFormat = f;
    (await SharedPreferences.getInstance()).setInt('fmt', f.index);
  }

  static String sortKey(Person p) {
    final n = p.displayName;
    if (Fold.hasCjk(n)) {
      final py = Fold.pinyin(n);
      if (py.isNotEmpty) return py;
    }
    return Fold.basic(n);
  }

  final Map<String, String> _letterCache = {};

  String letterFor(Person p) =>
      _letterCache.putIfAbsent(p.id, () => groupLetter(p));

  static String groupLetter(Person p) {
    final n = p.displayName.trim();
    if (n.isEmpty) return '#';
    final r = n.runes.first;
    if (Fold.isArabic(r)) {
      return Fold.basic(String.fromCharCode(r)).toUpperCase();
    }
    if (Fold.isCjk(r)) {
      final py = Fold.pinyin(String.fromCharCode(r));
      return py.isEmpty ? '#' : py[0].toUpperCase();
    }
    final b = Fold.basic(String.fromCharCode(r));
    if (b.isEmpty) return '#';
    final c = b[0].toUpperCase();
    return RegExp(r'\p{L}', unicode: true).hasMatch(c) ? c : '#';
  }

  final Map<String, String> _keyCache = {};

  void _resort() {
    _sorted = [..._people];
    if (sort == SortMode.name) {
      String k(Person p) => _keyCache.putIfAbsent(p.id, () => sortKey(p));
      int bucket(Person p) {
        final n = p.displayName;
        if (n.isEmpty) return 3;
        final r = n.runes.first;
        if (Fold.isArabic(r)) return 1;
        if (!RegExp(r'\p{L}', unicode: true).hasMatch(String.fromCharCode(r))) {
          return 2;
        }
        return 0;
      }

      final arFirst = lang == 'ar';
      int rank(Person p) {
        final b = bucket(p);
        if (!arFirst) return b;
        return b == 1 ? 0 : (b == 0 ? 1 : b);
      }

      _sorted.sort((a, b) {
        final ba = rank(a), bb = rank(b);
        if (ba != bb) return ba.compareTo(bb);
        return k(a).compareTo(k(b));
      });
    } else {
      _sorted.sort((a, b) => b.added.compareTo(a.added));
    }
    if (!identical(_indexed, _people)) _dirtyIndex = true;
    if (searching) _runSearch();
  }

  void setQuery(String q) {
    _query = q;
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      _hits = [];
      notifyListeners();
      return;
    }
    final delay = _people.length > 3000 ? 140 : 40;
    _debounce = Timer(Duration(milliseconds: delay), () {
      _runSearch();
      notifyListeners();
    });
  }

  void _runSearch() {
    if (_dirtyIndex) {
      _index.build(_people);
      _indexed = _people;
      _dirtyIndex = false;
    }
    _hits = _index.search(_query);
  }

  void toggle(Person p) {
    if (!selected.remove(p.id)) selected.add(p.id);
    notifyListeners();
  }

  void selectAll(Iterable<Person> list) {
    selected.addAll(list.map((e) => e.id));
    notifyListeners();
  }

  void deselect(Iterable<Person> list) {
    selected.removeAll(list.map((e) => e.id));
    notifyListeners();
  }

  void clearSelection() {
    selected.clear();
    notifyListeners();
  }

  List<Person> get selectedPeople =>
      _sorted.where((p) => selected.contains(p.id)).toList();

  ImportPlan plan(List<ImportResult> results) {
    final incoming = <Person>[];
    final sources = <String>[];
    final formats = <Format, int>{};
    for (final r in results) {
      incoming.addAll(r.people);
      formats[r.format] = (formats[r.format] ?? 0) + r.people.length;
      if (r.people.isNotEmpty) sources.add(r.people.first.source);
    }
    final byKey = <String, Person>{};
    for (final p in _people) {
      for (final k in p.phoneKeys) {
        byKey.putIfAbsent(k, () => p);
      }
    }
    final fresh = <Person>[];
    final dupes = <(Person, Person)>[];
    final freshByKey = <String, Person>{};
    for (final p in incoming) {
      Person? existing;
      for (final k in p.phoneKeys) {
        existing = byKey[k];
        if (existing != null) break;
      }
      if (existing != null) {
        dupes.add((p, existing));
        continue;
      }
      Person? twin;
      for (final k in p.phoneKeys) {
        twin = freshByKey[k];
        if (twin != null) break;
      }
      if (twin != null &&
          (twin.displayName == p.displayName || !p.hasName || !twin.hasName)) {
        twin.absorb(p);
        continue;
      }
      fresh.add(p);
      for (final k in p.phoneKeys) {
        freshByKey.putIfAbsent(k, () => p);
      }
    }
    return ImportPlan(incoming, fresh, dupes, sources, formats);
  }

  Future<int> commit(ImportPlan plan, {bool merge = true}) async {
    final changed = <Person>[];
    if (merge) {
      for (final (incoming, existing) in plan.dupes) {
        existing.absorb(incoming);
        changed.add(existing);
      }
    } else {
      plan.fresh.addAll(plan.dupes.map((d) => d.$1));
    }
    final now = DateTime.now();
    var i = 0;
    final added = plan.fresh
        .map(
          (p) => Person(
            name: p.name,
            phones: p.phones,
            emails: p.emails,
            org: p.org,
            note: p.note,
            source: p.source,
            added: now.subtract(Duration(microseconds: i++)),
          ),
        )
        .toList();
    _people = [..._people, ...added];
    await _store.putAll([...added, ...changed]);
    _keyCache.clear();
    _letterCache.clear();
    _dirtyIndex = true;
    _resort();
    notifyListeners();
    return added.length;
  }

  Future<List<Person>> remove(Iterable<String> ids) async {
    final set = ids.toSet();
    final gone = _people.where((p) => set.contains(p.id)).toList();
    _people = _people.where((p) => !set.contains(p.id)).toList();
    selected.removeAll(set);
    await _store.deleteAll(set);
    _resort();
    notifyListeners();
    return gone;
  }

  Future<void> restore(List<Person> list) async {
    _people = [..._people, ...list];
    await _store.putAll(list);
    _resort();
    notifyListeners();
  }

  Future<void> update(Person p) async {
    await _store.putAll([p]);
    _dirtyIndex = true;
    _keyCache.remove(p.id);
    _letterCache.remove(p.id);
    _resort();
    notifyListeners();
  }

  /// Replaces contacts (matched by id) with edited copies in one write.
  /// Returns the previous versions (same ids) so the caller can offer undo
  /// by passing them straight back into [replaceMany].
  Future<List<Person>> replaceMany(List<Person> edited) async {
    if (edited.isEmpty) return const [];
    final byId = {for (final p in edited) p.id: p};
    final before = <Person>[];
    final next = <Person>[];
    for (final p in _people) {
      final e = byId[p.id];
      if (e != null) {
        before.add(p);
        next.add(e);
      } else {
        next.add(p);
      }
    }
    _people = next;
    for (final id in byId.keys) {
      _keyCache.remove(id);
      _letterCache.remove(id);
    }
    await _store.putAll(edited);
    _dirtyIndex = true;
    _resort();
    notifyListeners();
    return before;
  }

  Person? byId(String id) {
    for (final p in _people) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> clearAll() async {
    _people = [];
    selected.clear();
    await _store.clear();
    _resort();
    notifyListeners();
  }

  Future<int> dedupe() async {
    final byKey = <String, Person>{};
    final removed = <String>[];
    final changed = <Person>{};
    for (final p in [..._people]..sort((a, b) => a.added.compareTo(b.added))) {
      Person? keep;
      for (final k in p.phoneKeys) {
        keep = byKey[k];
        if (keep != null) break;
      }
      if (keep != null && keep.id != p.id) {
        keep.absorb(p);
        changed.add(keep);
        removed.add(p.id);
        for (final k in p.phoneKeys) {
          byKey.putIfAbsent(k, () => keep!);
        }
      } else {
        for (final k in p.phoneKeys) {
          byKey.putIfAbsent(k, () => p);
        }
      }
    }
    if (removed.isEmpty) return 0;
    final set = removed.toSet();
    _people = _people.where((p) => !set.contains(p.id)).toList();
    selected.removeAll(set);
    await _store.deleteAll(set);
    await _store.putAll(changed);
    _dirtyIndex = true;
    _resort();
    notifyListeners();
    return removed.length;
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../io/codec.dart';
import '../models/person.dart';
import '../services/library_store.dart';
import 'contact_list.dart';

export 'contact_list.dart' show SortMode, ListFilter;

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

class AppState extends ContactList {
  final LibraryStore _store;
  ThemeMode themeMode = ThemeMode.system;
  String lang = 'en';
  String country = '';
  bool ready = false;
  ExportOptions exportOptions = const ExportOptions();
  Format lastFormat = Format.csv;
  bool includeContactId = true;
  int tab = -1;

  AppState({LibraryStore? store}) : _store = store ?? LibraryStore();

  LibraryStore get store => _store;

  List<Person> get _people => people;

  Future<void> init({bool openStore = true}) async {
    final prefs = await SharedPreferences.getInstance();
    themeMode = ThemeMode.values[(prefs.getInt('theme') ?? 0).clamp(0, 2)];
    final sys = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    lang =
        prefs.getString('lang') ??
        (const ['en', 'ar', 'zh', 'es', 'fr'].contains(sys) ? sys : 'en');
    sortLang = lang;
    country = prefs.getString('country') ?? '';
    includeContactId = prefs.getBool('contactId') ?? true;
    tab = (prefs.getInt('tab') ?? -1).clamp(-1, 1);
    sort = SortMode.values[(prefs.getInt('sort') ?? 0).clamp(0, 1)];
    lastFormat = Format
        .values[(prefs.getInt('fmt') ?? 0).clamp(0, Format.values.length - 1)];
    var loaded = <Person>[];
    if (openStore) {
      try {
        await _store.open();
        loaded = _store.load();
      } catch (_) {
        loaded = [];
      }
    }
    replacePeople(loaded);
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
    sortLang = l;
    resort();
    notifyListeners();
    (await SharedPreferences.getInstance()).setString('lang', l);
  }

  Future<void> setCountry(String c) async {
    country = c.trim();
    notifyListeners();
    (await SharedPreferences.getInstance()).setString('country', country);
  }

  Future<void> setTab(int t) async {
    tab = t;
    notifyListeners();
    (await SharedPreferences.getInstance()).setInt('tab', t);
  }

  Future<void> setIncludeContactId(bool v) async {
    includeContactId = v;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool('contactId', v);
  }

  Future<void> setSort(SortMode s) async {
    sort = s;
    resort();
    notifyListeners();
    (await SharedPreferences.getInstance()).setInt('sort', s.index);
  }

  Future<void> rememberFormat(Format f) async {
    lastFormat = f;
    (await SharedPreferences.getInstance()).setInt('fmt', f.index);
  }

  static String sortKey(Person p) => sortKeyOf(p);

  static String groupLetter(Person p) => groupLetterOf(p);

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
            aliases: p.aliases,
            added: now.subtract(Duration(microseconds: i++)),
          ),
        )
        .toList();
    await _store.putAll([...added, ...changed]);
    replacePeople([..._people, ...added]);
    notifyListeners();
    return added.length;
  }

  Future<List<Person>> remove(Iterable<String> ids) async {
    final set = ids.toSet();
    final gone = _people.where((p) => set.contains(p.id)).toList();
    selected.removeAll(set);
    await _store.deleteAll(set);
    replacePeople(_people.where((p) => !set.contains(p.id)).toList());
    notifyListeners();
    return gone;
  }

  Future<void> restore(List<Person> list) async {
    await _store.putAll(list);
    replacePeople([..._people, ...list]);
    notifyListeners();
  }

  Future<void> update(Person p) async {
    await _store.putAll([p]);
    replacePeople(
      [for (final x in _people) x.id == p.id ? p : x],
      changedIds: [p.id],
    );
    notifyListeners();
  }

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
    await _store.putAll(edited);
    replacePeople(next, changedIds: byId.keys);
    notifyListeners();
    return before;
  }

  Future<void> clearAll() async {
    selected.clear();
    await _store.clear();
    replacePeople([]);
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
    selected.removeAll(set);
    await _store.deleteAll(set);
    await _store.putAll(changed);
    replacePeople(
      _people.where((p) => !set.contains(p.id)).toList(),
      changedIds: changed.map((p) => p.id),
    );
    notifyListeners();
    return removed.length;
  }
}

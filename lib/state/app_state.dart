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
  final int skipped;
  const ImportPlan(
    this.incoming,
    this.fresh,
    this.dupes,
    this.sources,
    this.formats, {
    this.skipped = 0,
  });
}

class DedupeGroup {
  final Person keep;
  final List<Person> drop;
  const DedupeGroup(this.keep, this.drop);
}

class DedupePlan {
  final List<DedupeGroup> groups;
  const DedupePlan(this.groups);
  bool get isEmpty => groups.isEmpty;
  int get removed => groups.fold(0, (a, g) => a + g.drop.length);
}

class DedupeUndo {
  final List<Person> originals;
  final List<Person> removed;
  const DedupeUndo(this.originals, this.removed);
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
    if (openStore) loaded = await _openStore();
    replacePeople(loaded);
    ready = true;
    notifyListeners();
  }

  int quarantined = 0;

  bool get storeFailed => _store.failed;

  Future<List<Person>> _openStore() async {
    try {
      await _store.open();
      final loaded = _store.load();
      try {
        await _store.quarantineBad();
        quarantined = await _store.quarantineCount();
      } catch (_) {}
      return loaded;
    } catch (_) {
      return [];
    }
  }

  Future<void> retryStore() async {
    final loaded = await _openStore();
    if (!_store.failed) replacePeople(loaded);
    notifyListeners();
  }

  Future<String> quarantineJson() => _store.quarantineJson();

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
    var skipped = 0;
    for (final r in results) {
      skipped += r.skipped;
      incoming.addAll(r.people);
      if (r.people.isNotEmpty) {
        formats[r.format] = (formats[r.format] ?? 0) + r.people.length;
        sources.add(r.people.first.source);
      }
    }
    final byKey = <String, Person>{};
    for (final p in _people) {
      for (final k in p.matchKeys) {
        byKey.putIfAbsent(k, () => p);
      }
    }
    final fresh = <Person>[];
    final dupes = <(Person, Person)>[];
    final freshByKey = <String, Person>{};
    for (final p in incoming) {
      Person? existing;
      for (final k in p.matchKeys) {
        existing = byKey[k];
        if (existing != null) break;
      }
      if (existing != null) {
        dupes.add((p, existing));
        continue;
      }
      Person? twin;
      for (final k in p.matchKeys) {
        twin = freshByKey[k];
        if (twin != null) break;
      }
      if (twin != null &&
          (twin.displayName == p.displayName || !p.hasName || !twin.hasName)) {
        twin.absorb(p);
        continue;
      }
      fresh.add(p);
      for (final k in p.matchKeys) {
        freshByKey.putIfAbsent(k, () => p);
      }
    }
    return ImportPlan(
      incoming,
      fresh,
      dupes,
      sources,
      formats,
      skipped: skipped,
    );
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
            jobTitle: p.jobTitle,
            note: p.note,
            source: p.source,
            starred: p.starred,
            groups: [...p.groups],
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

  DedupePlan planDedupe() {
    final byKey = <String, Person>{};
    final drops = <String, List<Person>>{};
    final keeps = <String, Person>{};
    for (final p in [..._people]..sort((a, b) => a.added.compareTo(b.added))) {
      Person? keep;
      for (final k in p.matchKeys) {
        keep = byKey[k];
        if (keep != null) break;
      }
      if (keep != null && keep.id != p.id) {
        keeps[keep.id] = keep;
        (drops[keep.id] ??= []).add(p);
        for (final k in p.matchKeys) {
          byKey.putIfAbsent(k, () => keep!);
        }
      } else {
        for (final k in p.matchKeys) {
          byKey.putIfAbsent(k, () => p);
        }
      }
    }
    return DedupePlan([
      for (final e in drops.entries) DedupeGroup(keeps[e.key]!, e.value),
    ]);
  }

  Future<DedupeUndo> applyDedupe(DedupePlan plan) async {
    final originals = <Person>[];
    final removed = <Person>[];
    for (final g in plan.groups) {
      originals.add(g.keep.copy());
      for (final d in g.drop) {
        g.keep.absorb(d);
        removed.add(d);
      }
    }
    final ids = {for (final p in removed) p.id};
    selected.removeAll(ids);
    await _store.deleteAll(ids);
    await _store.putAll([for (final g in plan.groups) g.keep]);
    replacePeople(
      _people.where((p) => !ids.contains(p.id)).toList(),
      changedIds: [for (final g in plan.groups) g.keep.id],
    );
    notifyListeners();
    return DedupeUndo(originals, removed);
  }

  Future<void> undoDedupe(DedupeUndo undo) async {
    final byId = {for (final p in undo.originals) p.id: p};
    await _store.putAll([...undo.originals, ...undo.removed]);
    replacePeople([
      for (final p in _people) byId[p.id] ?? p,
      ...undo.removed,
    ], changedIds: byId.keys);
    notifyListeners();
  }

  Future<int> dedupe() async {
    final plan = planDedupe();
    if (plan.isEmpty) return 0;
    await applyDedupe(plan);
    return plan.removed;
  }
}

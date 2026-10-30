import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../io/codec.dart';
import '../models/person.dart';
import '../services/library_store.dart';
import 'contact_list.dart';
import '../phone/phone_key.dart';
import '../services/region_detect.dart';

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
  bool dynamicColor = false;
  bool swipeActions = true;
  String lang = 'en';
  String country = '';
  List<String> recent = [];
  List<String> saved = [];
  String region = '';
  bool get needsRegionPick => country.isNotEmpty && region.isEmpty;
  bool ready = false;
  ExportOptions exportOptions = const ExportOptions();
  Format lastFormat = Format.csv;
  bool includeContactId = true;
  int tab = -1;

  AppState({LibraryStore? store}) : _store = store ?? LibraryStore();

  LibraryStore get store => _store;

  List<Person> get _people => people;

  Future<void> init({bool openStore = true, bool detectRegion = false}) async {
    final prefs = await SharedPreferences.getInstance();
    themeMode = ThemeMode.values[(prefs.getInt('theme') ?? 0).clamp(0, 2)];
    dynamicColor = prefs.getBool('dynamicColor') ?? false;
    swipeActions = prefs.getBool('swipeActions') ?? true;
    final sys = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    lang =
        prefs.getString('lang') ??
        (const ['en', 'ar', 'zh', 'es', 'fr'].contains(sys) ? sys : 'en');
    sortLang = lang;
    country = prefs.getString('country') ?? '';
    region = prefs.getString('region') ?? '';
    recent = prefs.getStringList('recentSearches') ?? [];
    saved = prefs.getStringList('savedSearches') ?? [];
    if (region.isEmpty && country.isNotEmpty) {
      final r = PhoneKey.uniqueRegionForCode(country);
      if (r != null) {
        region = r.name;
        await prefs.setString('region', region);
      }
    }
    if (region.isEmpty && country.isEmpty && detectRegion) {
      final detected = await RegionDetect.detect();
      if (detected.isNotEmpty) {
        region = detected;
        country = PhoneKey.callingCode(PhoneKey.parseRegion(detected)!);
      }
    }
    PhoneKey.useRegion(region);
    includeContactId = prefs.getBool('contactId') ?? true;
    tab = (prefs.getInt('tab') ?? -1).clamp(-1, 3);
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

  Future<void> setSwipeActions(bool on) async {
    swipeActions = on;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool('swipeActions', on);
  }

  Future<void> setDynamicColor(bool on) async {
    dynamicColor = on;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool('dynamicColor', on);
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
    final r = PhoneKey.uniqueRegionForCode(country);
    if (r != null) {
      region = r.name;
      PhoneKey.useRegion(region);
      invalidateNumbers();
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('country', country);
    if (r != null) await prefs.setString('region', region);
  }

  Future<void> rememberSearch(String q) async {
    final t = q.trim();
    if (t.length < 2 || saved.contains(t)) return;
    recent = [t, ...recent.where((e) => e != t)].take(10).toList();
    notifyListeners();
    (await SharedPreferences.getInstance()).setStringList(
      'recentSearches',
      recent,
    );
  }

  Future<void> forgetRecent() async {
    recent = [];
    notifyListeners();
    (await SharedPreferences.getInstance()).setStringList(
      'recentSearches',
      recent,
    );
  }

  Future<void> saveSearch(String q) async {
    final t = q.trim();
    if (t.isEmpty || saved.contains(t)) return;
    saved = [t, ...saved].take(20).toList();
    recent = recent.where((e) => e != t).toList();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('savedSearches', saved);
    await prefs.setStringList('recentSearches', recent);
  }

  Future<void> unsaveSearch(String q) async {
    saved = saved.where((e) => e != q).toList();
    notifyListeners();
    (await SharedPreferences.getInstance()).setStringList(
      'savedSearches',
      saved,
    );
  }

  Future<void> setRegion(String iso) async {
    final r = PhoneKey.parseRegion(iso);
    if (r == null) return;
    region = r.name;
    country = PhoneKey.callingCode(r);
    PhoneKey.useRegion(region);
    invalidateNumbers();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('region', region);
    await prefs.setString('country', country);
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
    final byKey = <String, List<Person>>{};
    for (final p in _people) {
      for (final k in p.matchKeys) {
        (byKey[k] ??= []).add(p);
      }
    }
    Person? find(Map<String, List<Person>> index, Person p) {
      for (final k in p.matchKeys) {
        for (final o in index[k] ?? const <Person>[]) {
          if (o.sharesIdentity(p)) return o;
        }
      }
      return null;
    }

    final fresh = <Person>[];
    final dupes = <(Person, Person)>[];
    final freshByKey = <String, List<Person>>{};
    for (final p in incoming) {
      final existing = find(byKey, p);
      if (existing != null) {
        dupes.add((p, existing));
        continue;
      }
      final twin = find(freshByKey, p);
      if (twin != null &&
          (twin.displayName == p.displayName || !p.hasName || !twin.hasName)) {
        twin.absorb(p);
        continue;
      }
      fresh.add(p);
      for (final k in p.matchKeys) {
        (freshByKey[k] ??= []).add(p);
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
    final byKey = <String, List<Person>>{};
    final drops = <String, List<Person>>{};
    final keeps = <String, Person>{};
    for (final p in [..._people]..sort((a, b) => a.added.compareTo(b.added))) {
      Person? keep;
      for (final k in p.matchKeys) {
        for (final o in byKey[k] ?? const <Person>[]) {
          if (o.sharesIdentity(p)) {
            keep = o;
            break;
          }
        }
        if (keep != null) break;
      }
      if (keep != null && keep.id != p.id) {
        keeps[keep.id] = keep;
        (drops[keep.id] ??= []).add(p);
        for (final k in p.matchKeys) {
          (byKey[k] ??= []).add(keep);
        }
      } else {
        for (final k in p.matchKeys) {
          (byKey[k] ??= []).add(p);
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

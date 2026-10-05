import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/person.dart';
import '../search/fold.dart';
import '../search/fuzzy.dart';

enum SortMode { name, recent }

enum ListFilter { all, starred, noNumber, noName }

String sortKeyOf(Person p) {
  final n = p.displayName;
  if (Fold.hasCjk(n)) {
    final py = Fold.pinyin(n);
    if (py.isNotEmpty) return py;
  }
  return Fold.basic(n);
}

String groupLetterOf(Person p) {
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

abstract class ContactList extends ChangeNotifier {
  final _index = FuzzyIndex();
  List<Person> _people = [];
  List<Person> _sorted = [];
  List<Person> _filtered = [];
  List<Hit> _hits = [];
  final Set<String> selected = {};
  String _query = '';
  SortMode sort = SortMode.name;
  String sortLang = 'en';
  ListFilter filter = ListFilter.all;
  String? accountFilter;
  String? groupFilter;
  bool _dirtyIndex = true;
  Timer? _debounce;
  final Map<String, String> _keyCache = {};
  final Map<String, String> _letterCache = {};

  List<Person> get people => _people;
  String get query => _query;
  bool get searching => _query.trim().isNotEmpty;
  bool get selecting => selected.isNotEmpty;
  int get phoneCount => _people.fold(0, (s, p) => s + p.phones.length);
  bool get filtering =>
      filter != ListFilter.all || accountFilter != null || groupFilter != null;

  List<Person> get visible => searching
      ? [
          for (final h in _hits)
            if (_passes(h.person)) h.person,
        ]
      : _filtered;

  List<Person> get sorted => _sorted;
  List<Hit> get hits => _hits;

  Hit? hitFor(Person p) {
    if (!searching) return null;
    for (final h in _hits) {
      if (identical(h.person, p)) return h;
    }
    return null;
  }

  @protected
  void replacePeople(List<Person> next, {Iterable<String>? changedIds}) {
    _people = next;
    final ids = {for (final p in next) p.id};
    selected.retainAll(ids);
    _dirtyIndex = true;
    resort();
  }

  String letterFor(Person p) =>
      _letterCache.putIfAbsent(p.displayName, () => groupLetterOf(p));

  bool _passes(Person p) {
    final ok = switch (filter) {
      ListFilter.all => true,
      ListFilter.starred => p.starred,
      ListFilter.noNumber => !p.hasNumber,
      ListFilter.noName => p.name.trim().isEmpty,
    };
    if (!ok) return false;
    if (accountFilter != null &&
        (p.account?.key ?? AccountRef.device.key) != accountFilter) {
      return false;
    }
    if (groupFilter != null && !p.groups.contains(groupFilter)) return false;
    return true;
  }

  @protected
  void resort() {
    _sorted = [..._people];
    if (sort == SortMode.name) {
      String k(Person p) =>
          _keyCache.putIfAbsent(p.displayName, () => sortKeyOf(p));
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

      final arFirst = sortLang == 'ar';
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
    _filtered = filtering ? _sorted.where(_passes).toList() : _sorted;
    if (searching) _runSearch();
  }

  void setFilter(ListFilter f, {String? account, String? group}) {
    filter = f;
    accountFilter = account;
    groupFilter = group;
    resort();
    notifyListeners();
  }

  void clearFilters() => setFilter(ListFilter.all);

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
      _dirtyIndex = false;
    }
    _hits = _index.search(_query);
  }

  void warmIndex() {
    if (_dirtyIndex && _people.isNotEmpty) {
      _index.build(_people);
      _dirtyIndex = false;
    }
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

  Person? byId(String id) {
    for (final p in _people) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

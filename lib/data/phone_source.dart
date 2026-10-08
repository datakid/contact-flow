import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;

import '../models/person.dart';
import '../search/fold.dart';
import 'contact_source.dart';

class PhoneSource implements ContactSource {
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static const _props = {
    fc.ContactProperty.name,
    fc.ContactProperty.phone,
    fc.ContactProperty.email,
    fc.ContactProperty.organization,
    fc.ContactProperty.note,
    fc.ContactProperty.favorite,
  };

  final Map<String, fc.Contact> _raw = {};
  Map<String, String> _groupIds = {};
  final Map<String, Set<String>> _membership = {};

  @override
  bool get isDevice => true;

  static Access _map(fc.PermissionStatus s) => switch (s) {
    fc.PermissionStatus.granted ||
    fc.PermissionStatus.limited => Access.granted,
    fc.PermissionStatus.permanentlyDenied ||
    fc.PermissionStatus.restricted => Access.blocked,
    fc.PermissionStatus.notDetermined => Access.notAsked,
    fc.PermissionStatus.denied => Access.denied,
  };

  @override
  Future<Access> status() async {
    if (!supported) return Access.unsupported;
    return _map(
      await fc.FlutterContacts.permissions.check(fc.PermissionType.readWrite),
    );
  }

  @override
  Future<Access> request() async {
    if (!supported) return Access.unsupported;
    return _map(
      await fc.FlutterContacts.permissions.request(fc.PermissionType.readWrite),
    );
  }

  @override
  Future<void> openSettings() => fc.FlutterContacts.permissions.openSettings();

  static String _label(fc.PhoneLabel l) => switch (l) {
    fc.PhoneLabel.home => 'home',
    fc.PhoneLabel.work || fc.PhoneLabel.workMobile => 'work',
    fc.PhoneLabel.homeFax ||
    fc.PhoneLabel.workFax ||
    fc.PhoneLabel.otherFax => 'fax',
    fc.PhoneLabel.main || fc.PhoneLabel.companyMain => 'main',
    fc.PhoneLabel.pager || fc.PhoneLabel.workPager => 'pager',
    fc.PhoneLabel.other => 'other',
    _ => 'mobile',
  };

  static fc.PhoneLabel _toLabel(String l) => switch (l) {
    'home' => fc.PhoneLabel.home,
    'work' => fc.PhoneLabel.work,
    'fax' => fc.PhoneLabel.workFax,
    'main' => fc.PhoneLabel.main,
    'pager' => fc.PhoneLabel.pager,
    'other' => fc.PhoneLabel.other,
    _ => fc.PhoneLabel.mobile,
  };

  static String _fullName(fc.Contact c) {
    final d = c.displayName?.trim() ?? '';
    if (d.isNotEmpty) return d;
    final n = c.name;
    if (n == null) return '';
    final first = n.first ?? '', middle = n.middle ?? '', last = n.last ?? '';
    if (Fold.hasCjk('$first$last')) return '$last$middle$first';
    return [first, middle, last].where((e) => e.isNotEmpty).join(' ');
  }

  Person _toPerson(fc.Contact c) {
    final id = c.id!;
    final org = c.organizations.isEmpty ? null : c.organizations.first;
    final accounts = c.metadata?.accounts ?? const [];
    final account = accounts.isEmpty
        ? null
        : AccountRef(accounts.first.name, accounts.first.type);
    final orgName = org?.name ?? '';
    final full = _fullName(c);
    final name = full == orgName && (c.name?.first ?? '').isEmpty ? '' : full;
    return Person(
      id: 'phone:$id',
      name: name,
      aliases: aliasesOf(c, name),
      phones: [
        for (final p in c.phones) PhoneEntry(p.number, _label(p.label.label)),
      ],
      emails: [for (final e in c.emails) e.address],
      org: orgName,
      jobTitle: org?.jobTitle ?? '',
      note: c.notes.map((n) => n.note).where((n) => n.isNotEmpty).join('\n'),
      source: 'device',
      added: DateTime.fromMillisecondsSinceEpoch(int.tryParse(id) ?? 0),
      phoneId: id,
      account: account,
      starred: c.android?.isFavorite ?? false,
      groups: [
        for (final e in _groupIds.entries)
          if (_membership[e.value]?.contains(id) ?? false) e.key,
      ]..sort(),
    );
  }

  Future<void> _loadGroups() async {
    _membership.clear();
    final groups = await fc.FlutterContacts.groups.getAll();
    final ids = <String, String>{};
    for (final g in groups) {
      final gid = g.id;
      if (gid == null || g.name.trim().isEmpty) continue;
      ids.putIfAbsent(g.name.trim(), () => gid);
      final members = await fc.FlutterContacts.getAll(
        filter: fc.ContactFilter.group(gid),
      );
      (_membership[ids[g.name.trim()]!] ??= {}).addAll(
        members.map((m) => m.id).whereType<String>(),
      );
    }
    _groupIds = ids;
  }

  @override
  Future<List<Person>> readAll() async {
    try {
      await _loadGroups();
    } catch (_) {
      _groupIds = {};
      _membership.clear();
    }
    final list = await fc.FlutterContacts.getAll(properties: _props);
    _raw.clear();
    final out = <Person>[];
    for (final c in list) {
      if (c.id == null) continue;
      _raw[c.id!] = c;
      out.add(_toPerson(c));
    }
    return out;
  }

  @override
  Future<List<AccountRef>> accounts() async {
    final list = await fc.FlutterContacts.accounts.getAll();
    final seen = <String>{};
    return [
      for (final a in list)
        if (seen.add('${a.type}|${a.name}')) AccountRef(a.name, a.type),
    ];
  }

  @override
  Future<List<String>> groups() async => _groupIds.keys.toList()..sort();

  static List<String> aliasesOf(fc.Contact c, String name) =>
      Aliases.clean(Aliases.parse(c.name?.nickname ?? ''), name: name);

  static fc.Name _name(Person p) {
    final full = p.name.trim();
    if (full.isEmpty) return const fc.Name();
    if (Fold.hasCjk(full) && !full.contains(' ')) {
      final r = full.runes.toList();
      if (r.length == 1) return fc.Name(first: full);
      return fc.Name(
        last: String.fromCharCode(r.first),
        first: String.fromCharCodes(r.skip(1)),
      );
    }
    final parts = full.split(RegExp(r'\s+'));
    if (parts.length == 1) return fc.Name(first: full);
    final last = parts.removeLast();
    return fc.Name(first: parts.join(' '), last: last);
  }

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static fc.Name? _nameFor(fc.Contact base, Person p) {
    final baseName = _fullName(base);
    final baseOrg = base.organizations.isEmpty
        ? ''
        : (base.organizations.first.name ?? '');
    final shown = baseName == baseOrg && (base.name?.first ?? '').isEmpty
        ? ''
        : baseName;
    final aliases = p.cleanAliases;
    final sameName = shown.trim() == p.name.trim();
    final sameAliases = _sameList(aliasesOf(base, shown), aliases);
    if (sameName && sameAliases && base.id != null) return base.name;
    final nick = aliases.isEmpty ? null : Aliases.join(aliases);
    final n = sameName && base.name != null ? base.name! : _name(p);
    return fc.Name(
      first: n.first,
      middle: n.middle,
      last: n.last,
      prefix: n.prefix,
      suffix: n.suffix,
      phoneticFirst: n.phoneticFirst,
      phoneticMiddle: n.phoneticMiddle,
      phoneticLast: n.phoneticLast,
      previousFamilyName: n.previousFamilyName,
      nickname: nick,
    );
  }

  static List<fc.Phone> _phonesFor(fc.Contact base, Person p) {
    final pool = [...base.phones];
    final out = <fc.Phone>[];
    for (final x in p.phones) {
      final i = pool.indexWhere((b) => b.number.trim() == x.number.trim());
      if (i < 0) {
        out.add(fc.Phone(number: x.number, label: fc.Label(_toLabel(x.label))));
        continue;
      }
      final b = pool.removeAt(i);
      out.add(
        _label(b.label.label) == x.label
            ? b
            : b.copyWith(label: fc.Label(_toLabel(x.label))),
      );
    }
    return out;
  }

  static List<fc.Email> _emailsFor(fc.Contact base, Person p) {
    final pool = [...base.emails];
    final out = <fc.Email>[];
    for (final e in p.emails) {
      final i = pool.indexWhere(
        (b) => b.address.trim().toLowerCase() == e.trim().toLowerCase(),
      );
      out.add(
        i < 0 ? fc.Email(address: e) : pool.removeAt(i).copyWith(address: e),
      );
    }
    return out;
  }

  static List<fc.Organization> _orgsFor(fc.Contact base, Person p) {
    if (p.org.isEmpty && p.jobTitle.isEmpty) return const [];
    final first = base.organizations.isEmpty ? null : base.organizations.first;
    final org = fc.Organization(
      name: p.org.isEmpty ? null : p.org,
      jobTitle: p.jobTitle.isEmpty ? null : p.jobTitle,
      departmentName: first?.departmentName,
      phoneticName: first?.phoneticName,
      jobDescription: first?.jobDescription,
      symbol: first?.symbol,
      officeLocation: first?.officeLocation,
    );
    return [org, ...base.organizations.skip(1)];
  }

  static List<fc.Note> _notesFor(fc.Contact base, Person p) {
    if (p.note.isEmpty) return const [];
    final joined = base.notes
        .map((n) => n.note)
        .where((n) => n.isNotEmpty)
        .join('\n');
    if (joined == p.note) return base.notes;
    final first = base.notes.isEmpty ? null : base.notes.first;
    return [
      first == null ? fc.Note(note: p.note) : first.copyWith(note: p.note),
    ];
  }

  static fc.Contact apply(fc.Contact base, Person p) => base.copyWith(
    name: _nameFor(base, p),
    phones: _phonesFor(base, p),
    emails: _emailsFor(base, p),
    organizations: _orgsFor(base, p),
    notes: _notesFor(base, p),
    android: fc.AndroidData(
      isFavorite: p.starred,
      customRingtone: base.android?.customRingtone,
      sendToVoicemail: base.android?.sendToVoicemail,
    ),
  );

  Future<String> _groupId(String name, AccountRef? account) async {
    final existing = _groupIds[name];
    if (existing != null) return existing;
    final g = await fc.FlutterContacts.groups.create(
      name,
      account: account == null || account.isLocal && account.type.isEmpty
          ? null
          : fc.Account(id: '', name: account.name, type: account.type),
    );
    _groupIds[name] = g.id!;
    return g.id!;
  }

  Future<void> _syncGroups(
    String id,
    List<String> wanted,
    AccountRef? account,
  ) async {
    final current = {
      for (final e in _groupIds.entries)
        if (_membership[e.value]?.contains(id) ?? false) e.key,
    };
    for (final g in wanted.toSet().difference(current)) {
      final gid = await _groupId(g, account);
      await fc.FlutterContacts.groups.addContacts(
        groupId: gid,
        contactIds: [id],
      );
      (_membership[gid] ??= {}).add(id);
    }
    for (final g in current.difference(wanted.toSet())) {
      final gid = _groupIds[g]!;
      await fc.FlutterContacts.groups.removeContacts(
        groupId: gid,
        contactIds: [id],
      );
      _membership[gid]?.remove(id);
    }
  }

  @override
  Future<String> create(Person p, {AccountRef? account}) async {
    final acc = account ?? p.account;
    final id = await fc.FlutterContacts.create(
      apply(const fc.Contact(), p),
      account: acc == null || acc.type.isEmpty
          ? null
          : fc.Account(id: '', name: acc.name, type: acc.type),
    );
    if (p.groups.isNotEmpty) await _syncGroups(id, p.groups, acc);
    return id;
  }

  Future<fc.Contact> _fresh(String id) async {
    final c = await fc.FlutterContacts.get(id, properties: _props);
    if (c == null) throw ContactGone(id);
    return c;
  }

  @override
  Future<void> update(Person p) async {
    final id = p.phoneId;
    if (id == null) throw ContactGone(p.id);
    final base = await _fresh(id);
    try {
      await fc.FlutterContacts.update(apply(base, p));
    } catch (e) {
      final s = e.toString().toLowerCase();
      if (s.contains('read') && s.contains('only')) {
        throw ReadOnlyAccount(p.account?.name ?? '');
      }
      rethrow;
    }
    await _syncGroups(id, p.groups, p.account);
    _raw[id] = base;
  }

  @override
  Future<void> delete(String phoneId) async {
    await _fresh(phoneId);
    await fc.FlutterContacts.delete(phoneId);
    _raw.remove(phoneId);
  }

  @override
  Stream<void> get changes => fc.FlutterContacts.onDatabaseChange;
}

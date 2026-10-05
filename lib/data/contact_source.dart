import '../models/person.dart';

enum Access { notAsked, granted, denied, blocked, unsupported }

class ReadOnlyAccount implements Exception {
  final String account;
  const ReadOnlyAccount(this.account);
  @override
  String toString() => 'read-only: $account';
}

class ContactGone implements Exception {
  final String id;
  const ContactGone(this.id);
  @override
  String toString() => 'gone: $id';
}

abstract class ContactSource {
  bool get isDevice;

  Future<Access> status();

  Future<Access> request();

  Future<void> openSettings();

  Future<List<Person>> readAll();

  Future<List<AccountRef>> accounts();

  Future<List<String>> groups();

  Future<String> create(Person p, {AccountRef? account});

  Future<void> update(Person p);

  Future<void> delete(String phoneId);

  Stream<void> get changes;
}

class FakeSource implements ContactSource {
  final Map<String, Person> _rows = {};
  final List<AccountRef> _accounts;
  final Set<String> _groups;
  Access access;
  final Set<String> failOn;
  final Set<String> readOnlyAccounts;
  Duration latency;
  int _seq = 0;
  int writes = 0;

  FakeSource({
    Iterable<Person> seed = const [],
    List<AccountRef>? accounts,
    Iterable<String> groups = const [],
    this.access = Access.granted,
    Set<String>? failOn,
    Set<String>? readOnlyAccounts,
    this.latency = Duration.zero,
  }) : _accounts =
           accounts ??
           const [
             AccountRef('', ''),
             AccountRef('me@example.com', 'com.google'),
           ],
       _groups = {...groups},
       failOn = failOn ?? {},
       readOnlyAccounts = readOnlyAccounts ?? {} {
    for (final p in seed) {
      final id = p.phoneId ?? 'f${_seq++}';
      _rows[id] = p.copy(phoneId: id);
      _groups.addAll(p.groups);
    }
  }

  @override
  bool get isDevice => false;

  @override
  Future<Access> status() async => access;

  @override
  Future<Access> request() async {
    if (access == Access.notAsked) access = Access.granted;
    return access;
  }

  @override
  Future<void> openSettings() async {}

  Future<void> _wait() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  @override
  Future<List<Person>> readAll() async {
    await _wait();
    return [for (final p in _rows.values) p.copy()];
  }

  Person? byPhoneId(String id) => _rows[id]?.copy();

  int get size => _rows.length;

  @override
  Future<List<AccountRef>> accounts() async => [..._accounts];

  @override
  Future<List<String>> groups() async => _groups.toList()..sort();

  void _guard(Person p, String id) {
    if (failOn.contains(p.name) || failOn.contains(id)) {
      throw StateError('write failed: ${p.name}');
    }
    final acc = p.account;
    if (acc != null && readOnlyAccounts.contains(acc.key)) {
      throw ReadOnlyAccount(acc.name);
    }
  }

  @override
  Future<String> create(Person p, {AccountRef? account}) async {
    await _wait();
    final id = 'f${_seq++}';
    final row = p.copy(phoneId: id)..account = account ?? p.account;
    _guard(row, id);
    _rows[id] = row;
    _groups.addAll(row.groups);
    writes++;
    return id;
  }

  @override
  Future<void> update(Person p) async {
    await _wait();
    final id = p.phoneId;
    if (id == null || !_rows.containsKey(id)) throw ContactGone(id ?? '');
    final existing = _rows[id]!;
    _guard(existing, id);
    _guard(p, id);
    _rows[id] = p.copy()..account = existing.account;
    _groups.addAll(p.groups);
    writes++;
  }

  @override
  Future<void> delete(String phoneId) async {
    await _wait();
    final existing = _rows[phoneId];
    if (existing == null) throw ContactGone(phoneId);
    _guard(existing, phoneId);
    _rows.remove(phoneId);
    writes++;
  }

  void removeBehindTheScenes(String phoneId) => _rows.remove(phoneId);

  @override
  Stream<void> get changes => const Stream.empty();
}

import 'dart:async';

import '../domain/change_set.dart';
import '../models/person.dart';
import 'contact_source.dart';
import 'journal.dart';

class CancelToken {
  bool _cancelled = false;
  bool get cancelled => _cancelled;
  void cancel() => _cancelled = true;
}

class ExecutionProgress {
  final int done;
  final int total;
  const ExecutionProgress(this.done, this.total);
  double get fraction => total == 0 ? 1 : done / total;
}

class ExecutionResult {
  final JournalEntry entry;
  final bool cancelled;
  const ExecutionResult(this.entry, this.cancelled);
  int get ok => entry.okCount;
  int get failed => entry.failedCount;
  int get skipped => entry.skippedCount;
}

class Executor {
  static const batchSize = 25;

  final ContactSource source;
  final Journal journal;
  const Executor(this.source, this.journal);

  Future<ExecutionResult> run(
    ChangeSet set, {
    CancelToken? cancel,
    void Function(ExecutionProgress)? onProgress,
    String? undoOf,
  }) async {
    final entry = journal.begin(set, undoOf: undoOf);
    await journal.save(entry);
    final total = set.changes.length;
    var cancelled = false;
    for (var i = 0; i < total; i++) {
      if (cancel?.cancelled ?? false) {
        cancelled = true;
        break;
      }
      final change = set.changes[i];
      final record = entry.records[i];
      try {
        await _apply(change, record);
        record.status = ResultStatus.ok;
      } catch (e) {
        record.status = ResultStatus.failed;
        record.error = describe(e);
      }
      final done = i + 1;
      if (done % batchSize == 0 || done == total) {
        onProgress?.call(ExecutionProgress(done, total));
        await journal.save(entry);
        await Future<void>.delayed(Duration.zero);
      }
    }
    entry.state = cancelled ? EntryState.cancelled : EntryState.done;
    if (undoOf != null) {
      final original = journal.byId(undoOf);
      if (original != null && entry.okCount > 0) {
        original.undoneAt = journal.clock();
        await journal.save(original);
      }
    }
    await journal.save(entry);
    await journal.prune();
    return ExecutionResult(entry, cancelled);
  }

  Future<void> _apply(Change c, ChangeRecord record) async {
    switch (c) {
      case CreateChange():
        record.phoneId = await source.create(c.after, account: c.account);
      case UpdateChange():
        await source.update(_target(c.before, c.after));
      case DeleteChange():
        await source.delete(_phoneId(c.before));
      case MergeChange():
        await source.update(_target(c.keepBefore, c.keepAfter));
        final failures = <String>[];
        for (final r in c.removed) {
          try {
            await source.delete(_phoneId(r));
          } catch (e) {
            failures.add('${r.displayName}: ${describe(e)}');
          }
        }
        if (failures.isNotEmpty) throw StateError(failures.join('; '));
    }
  }

  static Person _target(Person before, Person after) {
    final out = after.copy(phoneId: before.phoneId);
    out.account = before.account;
    if (out.phoneId == null) throw ContactGone(before.id);
    return out;
  }

  static String _phoneId(Person p) {
    final id = p.phoneId;
    if (id == null) throw ContactGone(p.id);
    return id;
  }

  static String describe(Object e) {
    if (e is ReadOnlyAccount) return 'read-only';
    if (e is ContactGone) return 'gone';
    final s = e.toString().split('\n').first;
    return s.length > 140 ? '${s.substring(0, 137)}…' : s;
  }
}

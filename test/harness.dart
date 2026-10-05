import 'package:contact_flow/data/contact_source.dart';
import 'package:contact_flow/data/journal.dart';
import 'package:contact_flow/data/sample.dart';
import 'package:contact_flow/main.dart';
import 'package:contact_flow/models/person.dart';
import 'package:contact_flow/services/launcher.dart';
import 'package:contact_flow/state/app_state.dart';
import 'package:contact_flow/state/phone_book.dart';
import 'package:contact_flow/state/queue_state.dart';
import 'package:flutter/material.dart';

class Rig {
  final AppState app;
  final PhoneBook book;
  final QueueState queue;
  final RecordingLauncher launcher;
  final FakeSource source;
  final MemoryKeyValue kv;
  Rig(this.app, this.book, this.queue, this.launcher, this.source, this.kv);

  Widget wrap(Widget child) => AppProviders(
    state: app,
    book: book,
    queue: queue,
    launcher: launcher,
    child: child,
  );
}

Future<Rig> makeRig({
  required AppState app,
  Access access = Access.granted,
  List<Person>? seed,
  MemoryKeyValue? kv,
}) async {
  final source = FakeSource(
    seed: seed ?? Sample.phoneBook(),
    accounts: const [AccountRef.device, Sample.google],
    access: access,
  );
  final book = PhoneBook(source, Journal(MemoryJournalStore()));
  final store = kv ?? MemoryKeyValue();
  final launcher = RecordingLauncher();
  final queue = QueueState(store, launcher);
  await queue.load();
  return Rig(app, book, queue, launcher, source, store);
}

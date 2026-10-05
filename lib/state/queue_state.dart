import 'package:flutter/foundation.dart';

import '../domain/queue.dart';
import '../domain/reach.dart';
import '../models/person.dart';
import '../services/launcher.dart';

abstract class KeyValue {
  Future<String?> get(String key);
  Future<void> put(String key, String value);
  Future<void> remove(String key);
}

class MemoryKeyValue implements KeyValue {
  final Map<String, String> data = {};
  @override
  Future<String?> get(String key) async => data[key];
  @override
  Future<void> put(String key, String value) async => data[key] = value;
  @override
  Future<void> remove(String key) async => data.remove(key);
}

enum OpenResult { opened, needsCountry, invalid, failed }

class QueueState extends ChangeNotifier {
  static const storageKey = 'message_queue';

  final KeyValue store;
  final Launcher launcher;
  MessageQueue? queue;
  bool loaded = false;

  QueueState(this.store, this.launcher);

  bool get active => queue != null && !queue!.finished;

  Future<void> load() async {
    try {
      queue = MessageQueue.decode(await store.get(storageKey));
    } catch (_) {
      queue = null;
    }
    if (queue != null && queue!.finished) queue = null;
    loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final q = queue;
    if (q == null || q.finished) {
      await store.remove(storageKey);
    } else {
      await store.put(storageKey, q.encode());
    }
  }

  Future<MessageQueue> start(
    List<Person> people,
    String template, {
    required Channel channel,
    String country = '',
  }) async {
    queue = MessageQueue.build(
      people,
      template,
      channel: channel,
      country: country,
    );
    await _save();
    notifyListeners();
    return queue!;
  }

  Future<OpenResult> openCurrent() async {
    final q = queue;
    final step = q?.current;
    if (q == null || step == null) return OpenResult.failed;
    final link = q.linkFor(step);
    switch (link) {
      case ReachNeedsCountry():
        return OpenResult.needsCountry;
      case ReachInvalid():
        return OpenResult.invalid;
      case ReachReady():
        q.markOpened();
        await _save();
        notifyListeners();
        final ok = await launcher.open(link.link.uri);
        return ok ? OpenResult.opened : OpenResult.failed;
    }
  }

  Future<void> markSent() async {
    queue?.markSent();
    await _after();
  }

  Future<void> skip() async {
    queue?.skip();
    await _after();
  }

  Future<void> stop() async {
    queue?.stop();
    await _after();
  }

  Future<void> retarget(String country) async {
    final q = queue;
    if (q == null) return;
    queue = MessageQueue(
      id: q.id,
      channel: q.channel,
      template: q.template,
      country: country,
      created: q.created,
      steps: q.steps,
      withoutNumber: q.withoutNumber,
      stopped: q.stopped,
    );
    await _save();
    notifyListeners();
  }

  Future<void> _after() async {
    await _save();
    notifyListeners();
  }

  void dismiss() {
    if (queue != null && queue!.finished) {
      queue = null;
      notifyListeners();
    }
  }
}

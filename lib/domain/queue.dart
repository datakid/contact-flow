import 'dart:convert';

import '../models/person.dart';
import 'reach.dart';
import 'templates.dart';

enum StepState { pending, opened, sent, skipped }

class QueueStep {
  final String contactId;
  final String name;
  final String number;
  final String text;
  StepState state;
  QueueStep(
    this.contactId,
    this.name,
    this.number,
    this.text, [
    this.state = StepState.pending,
  ]);

  Map<String, dynamic> toJson() => {
    'c': contactId,
    'n': name,
    'p': number,
    't': text,
    's': state.index,
  };

  factory QueueStep.fromJson(Map m) => QueueStep(
    '${m['c']}',
    '${m['n']}',
    '${m['p']}',
    '${m['t']}',
    StepState.values[((m['s'] as int?) ?? 0).clamp(
      0,
      StepState.values.length - 1,
    )],
  );
}

class MessageQueue {
  final String id;
  final Channel channel;
  final String template;
  final String country;
  final DateTime created;
  final List<QueueStep> steps;
  final List<String> withoutNumber;
  bool stopped;

  MessageQueue({
    required this.id,
    required this.channel,
    required this.template,
    required this.country,
    required this.created,
    required this.steps,
    this.withoutNumber = const [],
    this.stopped = false,
  });

  static MessageQueue build(
    List<Person> people,
    String template, {
    Channel channel = Channel.sms,
    String country = '',
    DateTime? now,
  }) {
    final t = MessageTemplate(template);
    final steps = <QueueStep>[];
    final missing = <String>[];
    for (final p in people) {
      final number = p.phones
          .map((e) => e.number.trim())
          .firstWhere((n) => Phones.digits(n).length >= 3, orElse: () => '');
      if (number.isEmpty) {
        missing.add(p.displayName);
        continue;
      }
      steps.add(QueueStep(p.id, p.displayName, number, t.render(p)));
    }
    final at = now ?? DateTime.now();
    return MessageQueue(
      id: at.microsecondsSinceEpoch.toRadixString(36),
      channel: channel,
      template: template,
      country: country,
      created: at,
      steps: steps,
      withoutNumber: missing,
    );
  }

  int get total => steps.length;
  int get handled => steps
      .where((s) => s.state == StepState.sent || s.state == StepState.skipped)
      .length;
  int get sent => steps.where((s) => s.state == StepState.sent).length;
  int get skipped => steps.where((s) => s.state == StepState.skipped).length;
  bool get finished => stopped || handled == total;
  double get progress => total == 0 ? 1 : handled / total;

  int? get currentIndex {
    for (var i = 0; i < steps.length; i++) {
      final s = steps[i].state;
      if (s == StepState.pending || s == StepState.opened) return i;
    }
    return null;
  }

  QueueStep? get current {
    final i = currentIndex;
    return i == null ? null : steps[i];
  }

  void markOpened() => current?.state = StepState.opened;

  void markSent() => current?.state = StepState.sent;

  void skip() => current?.state = StepState.skipped;

  void stop() => stopped = true;

  bool get awaitingReturn => current?.state == StepState.opened;

  ReachOutcome linkFor(QueueStep s) =>
      Reach.link(channel, s.number, country: country, text: s.text);

  String encode() => jsonEncode({
    'id': id,
    'ch': channel.index,
    'tp': template,
    'cc': country,
    'at': created.millisecondsSinceEpoch,
    'st': stopped,
    'wn': withoutNumber,
    'steps': steps.map((s) => s.toJson()).toList(),
  });

  static MessageQueue? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw) as Map;
      return MessageQueue(
        id: '${m['id']}',
        channel:
            Channel.values[((m['ch'] as int?) ?? 1).clamp(
              0,
              Channel.values.length - 1,
            )],
        template: '${m['tp'] ?? ''}',
        country: '${m['cc'] ?? ''}',
        created: DateTime.fromMillisecondsSinceEpoch(m['at'] as int),
        stopped: m['st'] == true,
        withoutNumber: ((m['wn'] as List?) ?? const [])
            .map((e) => '$e')
            .toList(),
        steps: ((m['steps'] as List?) ?? const [])
            .whereType<Map>()
            .map(QueueStep.fromJson)
            .toList(),
      );
    } catch (_) {
      return null;
    }
  }
}

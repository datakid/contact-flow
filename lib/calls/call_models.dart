enum CallType {
  incoming,
  outgoing,
  missed,
  rejected,
  voicemail,
  blocked,
  other,
}

class CallRecord {
  final String number;
  final int dateMs;
  final int durationSec;
  final CallType type;
  final String cachedName;
  final int presentation;
  const CallRecord({
    required this.number,
    required this.dateMs,
    this.durationSec = 0,
    this.type = CallType.incoming,
    this.cachedName = '',
    this.presentation = 1,
  });

  bool get hiddenNumber =>
      number.trim().isEmpty || presentation == 2 || presentation == 3;

  static CallType typeFromAndroid(int t) => switch (t) {
    1 => CallType.incoming,
    2 => CallType.outgoing,
    3 => CallType.missed,
    4 => CallType.voicemail,
    5 => CallType.rejected,
    6 => CallType.blocked,
    _ => CallType.other,
  };

  static CallRecord fromMap(Map<dynamic, dynamic> m) => CallRecord(
    number: '${m['number'] ?? ''}',
    dateMs: (m['date'] as num?)?.toInt() ?? 0,
    durationSec: (m['duration'] as num?)?.toInt() ?? 0,
    type: typeFromAndroid((m['type'] as num?)?.toInt() ?? 0),
    cachedName: '${m['name'] ?? ''}',
    presentation: (m['presentation'] as num?)?.toInt() ?? 1,
  );
}

class CallGroup {
  final String key;
  String number;
  int count = 0;
  int incoming = 0;
  int outgoing = 0;
  int missed = 0;
  int lastMs = 0;
  int talkSec = 0;
  String cachedName = '';
  final List<CallRecord> calls = [];
  CallGroup(this.key, this.number);

  void add(CallRecord c) {
    calls.add(c);
    count++;
    switch (c.type) {
      case CallType.incoming:
        incoming++;
      case CallType.outgoing:
        outgoing++;
      case CallType.missed:
      case CallType.rejected:
      case CallType.blocked:
        missed++;
      case CallType.voicemail:
      case CallType.other:
        break;
    }
    talkSec += c.durationSec;
    if (c.dateMs >= lastMs) {
      lastMs = c.dateMs;
      number = c.number;
    }
    if (cachedName.isEmpty && c.cachedName.isNotEmpty) {
      cachedName = c.cachedName;
    }
  }
}

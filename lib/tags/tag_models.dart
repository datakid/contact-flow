import '../phone/phone_key.dart';

class Tag {
  final String id;
  final String name;
  final int colour;
  final int created;
  const Tag({
    required this.id,
    required this.name,
    required this.colour,
    required this.created,
  });

  Tag copyWith({String? name, int? colour}) => Tag(
    id: id,
    name: name ?? this.name,
    colour: colour ?? this.colour,
    created: created,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'colour': colour,
    'created': created,
  };

  static Tag fromJson(Map<dynamic, dynamic> m) => Tag(
    id: '${m['id']}',
    name: '${m['name'] ?? ''}',
    colour: (m['colour'] as num?)?.toInt() ?? 0xFFE8664A,
    created: (m['created'] as num?)?.toInt() ?? 0,
  );
}

class NumberTag {
  final String key;
  final String raw;
  final String region;
  final String tagId;
  final String? note;
  const NumberTag({
    required this.key,
    required this.raw,
    required this.region,
    required this.tagId,
    this.note,
  });

  String get storageKey => 'nt:$tagId|$key';

  NumberTag copyWith({String? key, String? region, String? tagId}) => NumberTag(
    key: key ?? this.key,
    raw: raw,
    region: region ?? this.region,
    tagId: tagId ?? this.tagId,
    note: note,
  );

  Map<String, Object?> toJson() => {
    'key': key,
    'raw': raw,
    'region': region,
    'tagId': tagId,
    if (note != null) 'note': note,
  };

  static NumberTag fromJson(Map<dynamic, dynamic> m) => NumberTag(
    key: '${m['key']}',
    raw: '${m['raw'] ?? ''}',
    region: '${m['region'] ?? ''}',
    tagId: '${m['tagId']}',
    note: m['note'] == null ? null : '${m['note']}',
  );
}

class TagKey {
  static String of(String raw) {
    final i = PhoneKey.info(raw);
    if (i.isEmpty) return '';
    final e = i.e164;
    if (e != null) return e;
    return 'u:${i.key}@${PhoneKey.regionCode}';
  }

  static bool isUnparsed(String key) => key.startsWith('u:');
}

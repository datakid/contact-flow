import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/person.dart';
import 'tabular.dart';

class _Field {
  final int number;
  final int wire;
  final int value;
  final Uint8List? bytes;
  const _Field(this.number, this.wire, this.value, this.bytes);
}

class _Msg {
  final List<_Field> fields;
  const _Msg(this.fields);

  static _Msg? parse(Uint8List b) {
    final out = <_Field>[];
    var p = 0;
    while (p < b.length) {
      final k = _Pb.varint(b, p);
      if (k == null) return null;
      p = k.$2;
      final field = k.$1 >> 3, wire = k.$1 & 7;
      if (field == 0) return null;
      switch (wire) {
        case 0:
          final v = _Pb.varint(b, p);
          if (v == null) return null;
          out.add(_Field(field, 0, v.$1, null));
          p = v.$2;
        case 1:
          if (p + 8 > b.length) return null;
          out.add(_Field(field, 1, 0, Uint8List.sublistView(b, p, p + 8)));
          p += 8;
        case 5:
          if (p + 4 > b.length) return null;
          out.add(_Field(field, 5, 0, Uint8List.sublistView(b, p, p + 4)));
          p += 4;
        case 2:
          final l = _Pb.varint(b, p);
          if (l == null) return null;
          p = l.$2;
          if (l.$1 < 0 || p + l.$1 > b.length) return null;
          out.add(
            _Field(field, 2, l.$1, Uint8List.sublistView(b, p, p + l.$1)),
          );
          p += l.$1;
        default:
          return null;
      }
    }
    return _Msg(out);
  }

  int? int_(int n) {
    for (final f in fields) {
      if (f.number == n && f.wire == 0) return f.value;
    }
    return null;
  }

  Iterable<int> ints(int n) sync* {
    for (final f in fields) {
      if (f.number != n) continue;
      if (f.wire == 0) {
        yield f.value;
      } else if (f.wire == 2 && f.bytes != null) {
        var p = 0;
        while (p < f.bytes!.length) {
          final v = _Pb.varint(f.bytes!, p);
          if (v == null) break;
          yield v.$1;
          p = v.$2;
        }
      }
    }
  }

  Uint8List? bytes(int n) {
    for (final f in fields) {
      if (f.number == n && f.wire == 2) return f.bytes;
    }
    return null;
  }

  _Msg? msg(int n) {
    final b = bytes(n);
    return b == null ? null : parse(b);
  }

  Iterable<_Msg> msgs(int n) sync* {
    for (final f in fields) {
      if (f.number == n && f.wire == 2 && f.bytes != null) {
        final m = parse(f.bytes!);
        if (m != null) yield m;
      }
    }
  }

  String? str(int n) {
    final b = bytes(n);
    if (b == null) return null;
    try {
      return utf8.decode(b);
    } catch (_) {
      return null;
    }
  }

  int? ref(int n) => msg(n)?.int_(1);
}

class _Pb {
  static (int, int)? varint(Uint8List b, int p) {
    var v = 0, shift = 0;
    while (p < b.length) {
      final x = b[p++];
      v |= (x & 0x7f) << shift;
      if (x < 0x80) return (v, p);
      shift += 7;
      if (shift > 63) return null;
    }
    return null;
  }
}

class _Obj {
  final int type;
  final Uint8List data;
  const _Obj(this.type, this.data);
}

class NumbersFile {
  static List<Person> read(Uint8List bytes, String source) {
    final z = ZipDecoder().decodeBytes(bytes);
    final iwa = z.files
        .where((f) => f.isFile && f.name.endsWith('.iwa'))
        .toList();
    final objects = <int, _Obj>{};
    for (final f in iwa) {
      try {
        _index(_iwa(Uint8List.fromList(f.content as List<int>)), objects);
      } catch (_) {}
    }
    final grids = _tables(objects);
    final people = <Person>[];
    for (final g in grids) {
      if (g.isEmpty) continue;
      final m = Tabular.detect(g);
      people.addAll(Tabular.toPeople(g, m, source));
    }
    if (people.isNotEmpty) return people;
    return _fallback(iwa, source);
  }

  static List<List<List<String>>> _tables(Map<int, _Obj> objects) {
    final out = <List<List<String>>>[];
    for (final e in objects.entries) {
      if (e.value.type != 6001) continue;
      try {
        final g = _grid(_Msg.parse(e.value.data)!, objects);
        if (g.isNotEmpty) out.add(g);
      } catch (_) {}
    }
    return out;
  }

  static _Msg? _obj(Map<int, _Obj> objects, int? id) {
    if (id == null) return null;
    final o = objects[id];
    return o == null ? null : _Msg.parse(o.data);
  }

  static Map<int, String> _strings(Map<int, _Obj> objects, _Msg? list) {
    final out = <int, String>{};
    if (list == null) return out;
    void take(_Msg m) {
      for (final entry in m.msgs(3)) {
        final k = entry.int_(1);
        final s = entry.str(3);
        if (k != null && s != null) out[k] = s;
      }
    }

    take(list);
    for (final seg in list.msgs(4)) {
      take(_obj(objects, seg.int_(1)) ?? seg);
    }
    return out;
  }

  static List<List<String>> _grid(_Msg model, Map<int, _Obj> objects) {
    final rows = model.int_(6) ?? 0;
    final cols = model.int_(7) ?? 0;
    if (rows == 0 || cols == 0 || rows > 200000 || cols > 500) return const [];
    final store = model.msg(4);
    if (store == null) return const [];
    final strings = _strings(objects, _obj(objects, store.ref(4)));
    final rich = <int, String>{};
    final richList = _obj(objects, store.ref(17));
    if (richList != null) {
      for (final entry in richList.msgs(3)) {
        final k = entry.int_(1);
        final payloadId = entry.msg(9)?.int_(1);
        if (k == null || payloadId == null) continue;
        final text = _richText(objects, payloadId);
        if (text != null) rich[k] = text;
      }
    }

    final rowIndex = <int>[];
    final rowHeaders = store.msg(1);
    if (rowHeaders != null) {
      for (final bucketRef in rowHeaders.msgs(2)) {
        final bucket = _obj(objects, bucketRef.int_(1));
        if (bucket == null) continue;
        for (final h in bucket.msgs(2)) {
          rowIndex.add(h.int_(1) ?? rowIndex.length);
        }
      }
    }

    final grid = List.generate(rows, (_) => List<String>.filled(cols, ''));
    final tileStorage = store.msg(3);
    if (tileStorage == null) return const [];
    var bufferIdx = 0;
    for (final t in tileStorage.msgs(1)) {
      final tileId = t.int_(1) ?? 0;
      final tile = _obj(objects, t.ref(2));
      if (tile == null) continue;
      final bnc = (tile.int_(7) ?? 0) == 1;
      for (final ri in tile.msgs(5)) {
        final tileRow = ri.int_(1) ?? 0;
        final buf = bnc ? ri.bytes(6) : ri.bytes(3);
        final offs = bnc ? ri.bytes(7) : ri.bytes(4);
        final wide = (ri.int_(8) ?? 0) == 1;
        int row;
        if (bufferIdx < rowIndex.length) {
          row = rowIndex[bufferIdx];
        } else {
          row = tileId * 256 + tileRow;
        }
        bufferIdx++;
        if (buf == null || offs == null || row < 0 || row >= rows) continue;
        final offsets = <int>[];
        final bd = ByteData.sublistView(offs);
        for (var i = 0; i + 1 < offs.length; i += 2) {
          final o = bd.getInt16(i, Endian.little);
          offsets.add(o < 0 ? -1 : (wide ? o * 4 : o));
        }
        for (var c = 0; c < cols && c < offsets.length; c++) {
          final start = offsets[c];
          if (start < 0 || start >= buf.length) continue;
          var end = buf.length;
          for (var k = c + 1; k < offsets.length; k++) {
            if (offsets[k] >= 0) {
              end = offsets[k];
              break;
            }
          }
          if (end <= start) continue;
          final v = bnc
              ? _cellBnc(Uint8List.sublistView(buf, start, end), strings, rich)
              : _cellPre(Uint8List.sublistView(buf, start, end), strings);
          if (v != null) grid[row][c] = v;
        }
      }
    }
    return grid.where((r) => r.any((c) => c.trim().isNotEmpty)).toList();
  }

  static String? _richText(Map<int, _Obj> objects, int payloadId) {
    final payload = _obj(objects, payloadId);
    if (payload == null) return null;
    for (final f in payload.fields) {
      if (f.wire == 0 && f.value > 0) {
        final storage = _obj(objects, f.value);
        if (storage == null) continue;
        final texts = storage.fields
            .where((x) => x.number == 3 && x.wire == 2)
            .map((x) {
              try {
                return utf8.decode(x.bytes!);
              } catch (_) {
                return '';
              }
            })
            .join();
        if (texts.isNotEmpty) return texts;
      }
    }
    final ref = payload.ref(1);
    final storage = _obj(objects, ref);
    if (storage == null) return null;
    final s = storage.fields
        .where((x) => x.number == 3 && x.wire == 2)
        .map((x) => utf8.decode(x.bytes!, allowMalformed: true))
        .join();
    return s.isEmpty ? null : s;
  }

  static String? _cellBnc(
    Uint8List b,
    Map<int, String> strings,
    Map<int, String> rich,
  ) {
    if (b.length < 12 || b[0] != 5) return null;
    final type = b[1];
    final d = ByteData.sublistView(b);
    final flags = d.getUint32(8, Endian.little);
    var o = 12;
    String? dec;
    double? dbl;
    int? strId;
    int? richId;
    if (flags & 0x1 != 0) {
      if (o + 16 > b.length) return null;
      dec = _decimal128(Uint8List.sublistView(b, o, o + 16));
      o += 16;
    }
    if (flags & 0x2 != 0) {
      if (o + 8 > b.length) return null;
      dbl = d.getFloat64(o, Endian.little);
      o += 8;
    }
    if (flags & 0x4 != 0) o += 8;
    if (flags & 0x8 != 0 && o + 4 <= b.length) {
      strId = d.getInt32(o, Endian.little);
      o += 4;
    }
    if (flags & 0x10 != 0 && o + 4 <= b.length) {
      richId = d.getInt32(o, Endian.little);
      o += 4;
    }
    switch (type) {
      case 3:
        return strId == null ? null : strings[strId];
      case 9:
        return richId == null ? null : rich[richId];
      case 2:
      case 10:
        if (dec != null) return dec;
        if (dbl != null) return _num(dbl);
        return null;
      default:
        if (strId != null) return strings[strId];
        if (dec != null) return dec;
        return null;
    }
  }

  static String? _cellPre(Uint8List b, Map<int, String> strings) {
    if (b.length < 12) return null;
    final d = ByteData.sublistView(b);
    final version = b[0];
    final type = b[2];
    final flags = version >= 4 ? d.getUint32(8, Endian.little) : 0;
    var o = version >= 4 ? 12 : 8;
    if (version >= 4) {
      for (final bit in [
        0x02,
        0x80,
        0x2000,
        0x1000,
        0x4000,
        0x8000,
        0x10000,
        0x20000,
        0x40000,
      ]) {
        if (flags & bit != 0) o += 4;
      }
    }
    if (type == 3 && o + 4 <= b.length) {
      final id = d.getInt32(o, Endian.little);
      return strings[id];
    }
    if (type == 2 && o + 8 <= b.length) {
      return _num(d.getFloat64(o, Endian.little));
    }
    return null;
  }

  static String _num(double v) {
    if (v == v.truncateToDouble() && v.abs() < 1e17) {
      return BigInt.from(v).toString();
    }
    return v.toString();
  }

  static String _decimal128(Uint8List b) {
    final exp = (((b[15] & 0x7f) << 7) | (b[14] >> 1)) - 0x1820;
    var mant = BigInt.from(b[14] & 1);
    for (var i = 13; i >= 0; i--) {
      mant = mant * BigInt.from(256) + BigInt.from(b[i]);
    }
    final neg = b[15] & 0x80 != 0;
    String s;
    if (exp >= 0) {
      s = (mant * BigInt.from(10).pow(exp)).toString();
    } else {
      final digits = mant.toString().padLeft(-exp + 1, '0');
      final ip = digits.substring(0, digits.length + exp);
      final fp = digits
          .substring(digits.length + exp)
          .replaceFirst(RegExp(r'0+$'), '');
      s = fp.isEmpty ? ip : '$ip.$fp';
    }
    return neg ? '-$s' : s;
  }

  static void _index(Uint8List raw, Map<int, _Obj> out) {
    var p = 0;
    while (p < raw.length) {
      final l = _Pb.varint(raw, p);
      if (l == null) return;
      p = l.$2;
      if (p + l.$1 > raw.length) return;
      final info = _Msg.parse(Uint8List.sublistView(raw, p, p + l.$1));
      p += l.$1;
      if (info == null) return;
      final id = info.int_(1) ?? 0;
      var first = true;
      for (final mi in info.msgs(2)) {
        final type = mi.int_(1) ?? 0;
        final len = mi.int_(3) ?? 0;
        if (p + len > raw.length) return;
        if (first) {
          out[id] = _Obj(type, Uint8List.sublistView(raw, p, p + len));
          first = false;
        }
        p += len;
      }
    }
  }

  static Uint8List _iwa(Uint8List data) {
    final out = BytesBuilder(copy: false);
    var i = 0;
    while (i + 4 <= data.length) {
      final type = data[i];
      final len = data[i + 1] | (data[i + 2] << 8) | (data[i + 3] << 16);
      i += 4;
      if (i + len > data.length) break;
      final chunk = Uint8List.sublistView(data, i, i + len);
      out.add(type == 0 ? _snappy(chunk) : chunk);
      i += len;
    }
    return out.toBytes();
  }

  static Uint8List _snappy(Uint8List src) {
    var p = 0;
    var size = 0, shift = 0;
    while (true) {
      final b = src[p++];
      size |= (b & 0x7f) << shift;
      if (b < 0x80) break;
      shift += 7;
    }
    final dst = Uint8List(size);
    var d = 0;
    while (p < src.length && d < size) {
      final tag = src[p++];
      final kind = tag & 3;
      if (kind == 0) {
        var len = tag >> 2;
        if (len >= 60) {
          final n = len - 59;
          len = 0;
          for (var k = 0; k < n; k++) {
            len |= src[p++] << (8 * k);
          }
        }
        len += 1;
        dst.setRange(d, d + len, src, p);
        p += len;
        d += len;
      } else {
        int len, off;
        if (kind == 1) {
          len = ((tag >> 2) & 7) + 4;
          off = ((tag >> 5) << 8) | src[p++];
        } else if (kind == 2) {
          len = (tag >> 2) + 1;
          off = src[p] | (src[p + 1] << 8);
          p += 2;
        } else {
          len = (tag >> 2) + 1;
          off =
              src[p] |
              (src[p + 1] << 8) |
              (src[p + 2] << 16) |
              (src[p + 3] << 24);
          p += 4;
        }
        for (var k = 0; k < len; k++) {
          dst[d] = dst[d - off];
          d++;
        }
      }
    }
    return dst;
  }

  static List<Person> _fallback(List<ArchiveFile> files, String source) {
    final strings = <String>[];
    for (final f in files) {
      try {
        final raw = _iwa(Uint8List.fromList(f.content as List<int>));
        final objs = <int, _Obj>{};
        _index(raw, objs);
        for (final o in objs.values) {
          _walk(o.data, strings, 0);
        }
      } catch (_) {}
    }
    final out = <Person>[];
    Person? cur;
    void flush() {
      if (cur != null && (cur!.phones.isNotEmpty || cur!.emails.isNotEmpty)) {
        out.add(cur!);
      }
      cur = null;
    }

    for (final raw in strings) {
      final s = raw.trim();
      if (s.isEmpty || s.length > 80) continue;
      if (Phones.looksLikePhone(s)) {
        cur ??= Person(name: '', source: source);
        cur!.phones.add(PhoneEntry(s));
        continue;
      }
      if (RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s)) {
        cur ??= Person(name: '', source: source);
        cur!.emails.add(s);
        continue;
      }
      if (!RegExp(r'\p{L}', unicode: true).hasMatch(s) ||
          Tabular.isHeaderWord(s)) {
        continue;
      }
      if (cur != null && cur!.phones.isNotEmpty) flush();
      cur ??= Person(name: s, source: source);
    }
    flush();
    return out;
  }

  static final _printable = RegExp(
    r'^[^\x00-\x08\x0B\x0C\x0E-\x1F\x7F\uFFFD]+$',
  );

  static void _walk(Uint8List b, List<String> out, int depth) {
    if (depth > 8) return;
    final m = _Msg.parse(b);
    if (m == null) return;
    for (final f in m.fields) {
      if (f.wire != 2 || f.bytes == null || f.bytes!.isEmpty) continue;
      String? s;
      try {
        s = utf8.decode(f.bytes!);
      } catch (_) {}
      if (s != null && f.bytes![0] >= 0x20 && _printable.hasMatch(s)) {
        out.add(s);
      } else {
        _walk(f.bytes!, out, depth + 1);
      }
    }
  }
}

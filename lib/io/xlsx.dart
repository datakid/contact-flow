import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

class Xlsx {
  static List<List<String>> read(Uint8List bytes) {
    final z = ZipDecoder().decodeBytes(bytes);
    String? file(String name) {
      final f = z.findFile(name);
      if (f == null) return null;
      return utf8.decode(f.content as List<int>, allowMalformed: true);
    }

    final shared = <String>[];
    final ss = file('xl/sharedStrings.xml');
    if (ss != null) {
      for (final si in RegExp(r'<si\b[^>]*>([\s\S]*?)</si>').allMatches(ss)) {
        shared.add(_texts(si.group(1)!));
      }
    }
    var sheetPath = 'xl/worksheets/sheet1.xml';
    final wb = file('xl/workbook.xml');
    final rels = file('xl/_rels/workbook.xml.rels');
    if (wb != null && rels != null) {
      final rid = RegExp(
        r'<sheet\b[^>]*r:id="([^"]+)"',
      ).firstMatch(wb)?.group(1);
      if (rid != null) {
        final rel =
            RegExp(
              '<Relationship\\b[^>]*Id="$rid"[^>]*/?>',
            ).firstMatch(rels)?.group(0) ??
            RegExp(
              '<Relationship\\b[^>]*Target="[^"]*"[^>]*Id="$rid"',
            ).firstMatch(rels)?.group(0);
        final target = rel == null
            ? null
            : RegExp(r'Target="([^"]+)"').firstMatch(rel)?.group(1);
        if (target != null) {
          sheetPath = target.startsWith('/')
              ? target.substring(1)
              : 'xl/$target';
        }
      }
    }
    final sheet =
        file(sheetPath) ??
        z.files
            .where(
              (f) =>
                  f.name.startsWith('xl/worksheets/') &&
                  f.name.endsWith('.xml'),
            )
            .map(
              (f) => utf8.decode(f.content as List<int>, allowMalformed: true),
            )
            .firstOrNull;
    if (sheet == null) return const [];
    final rows = <List<String>>[];
    for (final rm in RegExp(
      r'<row\b[^>]*>([\s\S]*?)</row>',
    ).allMatches(sheet)) {
      final row = <String>[];
      for (final cm in RegExp(
        r'<c\b([^>]*?)(?:/>|>([\s\S]*?)</c>)',
      ).allMatches(rm.group(1)!)) {
        final attrs = cm.group(1) ?? '';
        final inner = cm.group(2) ?? '';
        final ref = RegExp(r'r="([A-Z]+)\d+"').firstMatch(attrs)?.group(1);
        final idx = ref == null ? row.length : _colIndex(ref);
        while (row.length < idx) {
          row.add('');
        }
        final t = RegExp(r't="([^"]+)"').firstMatch(attrs)?.group(1);
        String v;
        if (t == 'inlineStr') {
          v = _texts(inner);
        } else {
          final raw =
              RegExp(r'<v>([\s\S]*?)</v>').firstMatch(inner)?.group(1) ?? '';
          if (t == 's') {
            final i = int.tryParse(raw) ?? -1;
            v = i >= 0 && i < shared.length ? shared[i] : '';
          } else if (t == 'str' || t == 'e' || t == 'b') {
            v = _unescape(raw);
          } else {
            v = _number(raw);
          }
        }
        if (row.length == idx) {
          row.add(v);
        } else {
          row[idx] = v;
        }
      }
      if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
    }
    return rows;
  }

  static String _number(String raw) {
    if (raw.isEmpty) return '';
    final d = double.tryParse(raw);
    if (d == null) return raw;
    if (d == d.truncateToDouble() && d.abs() < 1e17) {
      return BigInt.from(d).toString();
    }
    return raw;
  }

  static int _colIndex(String letters) {
    var n = 0;
    for (final c in letters.codeUnits) {
      n = n * 26 + (c - 64);
    }
    return n - 1;
  }

  static String _texts(String xml) {
    final b = StringBuffer();
    for (final m in RegExp(r'<t\b[^>]*>([\s\S]*?)</t>').allMatches(xml)) {
      b.write(_unescape(m.group(1)!));
    }
    return b.toString();
  }

  static String _unescape(String s) => s
      .replaceAllMapped(
        RegExp(r'&#x([0-9a-fA-F]+);'),
        (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
      )
      .replaceAllMapped(
        RegExp(r'&#(\d+);'),
        (m) => String.fromCharCode(int.parse(m.group(1)!)),
      )
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

  static String _colName(int i) {
    var n = i + 1;
    var s = '';
    while (n > 0) {
      final r = (n - 1) % 26;
      s = String.fromCharCode(65 + r) + s;
      n = (n - 1) ~/ 26;
    }
    return s;
  }

  static Uint8List write(
    List<List<String>> rows, {
    String sheetName = 'Contacts',
    bool rtl = false,
  }) {
    final width = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    final widths = List<int>.filled(width, 10);
    for (final r in rows) {
      for (var i = 0; i < r.length; i++) {
        final l = r[i].runes.length + 2;
        if (l > widths[i]) widths[i] = l > 60 ? 60 : l;
      }
    }
    final sd = StringBuffer();
    for (var ri = 0; ri < rows.length; ri++) {
      sd.write('<row r="${ri + 1}">');
      final r = rows[ri];
      for (var ci = 0; ci < r.length; ci++) {
        final v = r[ci];
        if (v.isEmpty) continue;
        final style = ri == 0 ? ' s="1"' : ' s="2"';
        sd.write(
          '<c r="${_colName(ci)}${ri + 1}" t="inlineStr"$style><is><t xml:space="preserve">${_esc(v)}</t></is></c>',
        );
      }
      sd.write('</row>');
    }
    final cols = StringBuffer('<cols>');
    for (var i = 0; i < width; i++) {
      cols.write(
        '<col min="${i + 1}" max="${i + 1}" width="${widths[i]}" customWidth="1"/>',
      );
    }
    cols.write('</cols>');
    final sheet =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<sheetViews><sheetView workbookViewId="0"${rtl ? ' rightToLeft="1"' : ''}><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews>'
        '${width > 0 ? cols : ''}<sheetData>$sd</sheetData>'
        '${rows.isNotEmpty && width > 0 ? '<autoFilter ref="A1:${_colName(width - 1)}${rows.length}"/>' : ''}'
        '</worksheet>';
    final styles =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<numFmts count="0"/>'
        '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font></fonts>'
        '<fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FFE8664A"/><bgColor indexed="64"/></patternFill></fill></fills>'
        '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
        '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
        '<cellXfs count="3"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
        '<xf numFmtId="49" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1" applyNumberFormat="1"/>'
        '<xf numFmtId="49" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/></cellXfs>'
        '</styleSheet>';
    final files = <String, String>{
      '[Content_Types].xml':
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
          '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
          '<Default Extension="xml" ContentType="application/xml"/>'
          '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
          '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
          '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
          '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
          '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>'
          '</Types>',
      '_rels/.rels':
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
          '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
          '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
          '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>'
          '</Relationships>',
      'docProps/core.xml':
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
          '<dc:title>Contacts</dc:title><dc:creator>Contact Flow</dc:creator>'
          '<dcterms:created xsi:type="dcterms:W3CDTF">${DateTime.now().toUtc().toIso8601String().split('.').first}Z</dcterms:created>'
          '</cp:coreProperties>',
      'docProps/app.xml':
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties"><Application>Contact Flow</Application></Properties>',
      'xl/workbook.xml':
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
          '<sheets><sheet name="${_esc(sheetName)}" sheetId="1" r:id="rId1"/></sheets>'
          '${rows.isNotEmpty && width > 0 ? '<definedNames><definedName name="_xlnm._FilterDatabase" localSheetId="0" hidden="1">\'${_esc(sheetName)}\'!\$A\$1:\$${_colName(width - 1)}\$${rows.length}</definedName></definedNames>' : ''}'
          '</workbook>',
      'xl/_rels/workbook.xml.rels':
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
          '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
          '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
          '</Relationships>',
      'xl/styles.xml': styles,
      'xl/worksheets/sheet1.xml': sheet,
    };
    final a = Archive();
    files.forEach((k, v) {
      final data = utf8.encode(v);
      a.addFile(ArchiveFile(k, data.length, data));
    });
    return Uint8List.fromList(ZipEncoder().encode(a)!);
  }
}

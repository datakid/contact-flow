import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'zip_guard.dart';

class XlsxSheet {
  final String name;
  final List<List<String>> rows;
  final List<int> widths;
  final Set<int> headerRows;
  const XlsxSheet(
    this.name,
    this.rows, {
    this.widths = const [],
    this.headerRows = const {},
  });
}

class Xlsx {
  static const _maxColumn = 16383;

  static const _ns = r'(?:\w+:)?';

  static List<List<String>> read(Uint8List bytes) {
    final sheets = readSheets(bytes, firstOnly: true);
    return sheets.isEmpty ? const [] : sheets.first.rows;
  }

  static List<XlsxSheet> readSheets(Uint8List bytes, {bool firstOnly = false}) {
    final z = ZipGuard.decode(bytes);
    String? file(String name) {
      final f = z.findFile(name);
      if (f == null) return null;
      return utf8.decode(f.content as List<int>, allowMalformed: true);
    }

    final shared = <String>[];
    final ss = file('xl/sharedStrings.xml');
    if (ss != null) {
      for (final si in RegExp(
        '<${_ns}si\\b[^>]*?(?:/>|>([\\s\\S]*?)</${_ns}si>)',
      ).allMatches(ss)) {
        shared.add(_texts(si.group(1) ?? ''));
      }
    }
    final pads = _padWidths(file('xl/styles.xml'));
    final wb = file('xl/workbook.xml');
    final rels = file('xl/_rels/workbook.xml.rels');
    var targets = _sheetTargets(wb, rels);
    if (targets.isEmpty) {
      final names =
          z.files
              .where(
                (f) =>
                    f.isFile &&
                    f.name.startsWith('xl/worksheets/') &&
                    f.name.endsWith('.xml'),
              )
              .map((f) => f.name)
              .toList()
            ..sort(_naturalCompare);
      final sheet1 = names.indexOf('xl/worksheets/sheet1.xml');
      if (sheet1 > 0) {
        names
          ..removeAt(sheet1)
          ..insert(0, 'xl/worksheets/sheet1.xml');
      }
      targets = [
        for (var i = 0; i < names.length; i++) ('Sheet${i + 1}', names[i]),
      ];
    }
    final out = <XlsxSheet>[];
    for (final t in targets) {
      final xml = file(t.$2);
      if (xml == null) continue;
      out.add(XlsxSheet(t.$1, _rows(xml, shared, pads)));
      if (firstOnly) break;
    }
    if (out.isEmpty && wb == null) {
      throw const FormatException('Not an Excel workbook');
    }
    return out;
  }

  static int _naturalCompare(String a, String b) {
    int n(String x) =>
        int.tryParse(RegExp(r'(\d+)\.xml$').firstMatch(x)?.group(1) ?? '') ?? 0;
    final c = n(a).compareTo(n(b));
    return c != 0 ? c : a.compareTo(b);
  }

  static List<(String, String)> _sheetTargets(String? wb, String? rels) {
    if (wb == null || rels == null) return const [];
    final out = <(String, String)>[];
    for (final m in RegExp('<${_ns}sheet\\b([^>]*?)/?>').allMatches(wb)) {
      final attrs = m.group(1)!;
      final name =
          RegExp(r'\bname="([^"]*)"').firstMatch(attrs)?.group(1) ?? '';
      final rid = RegExp(r'\b\w+:id="([^"]+)"').firstMatch(attrs)?.group(1);
      if (rid == null) continue;
      final rel = RegExp(
        '<${_ns}Relationship\\b[^>]*?\\bId="${RegExp.escape(rid)}"[^>]*>',
      ).firstMatch(rels)?.group(0);
      final target = rel == null
          ? null
          : RegExp(r'Target="([^"]+)"').firstMatch(rel)?.group(1);
      if (target == null) continue;
      out.add((
        _unescape(name),
        target.startsWith('/') ? target.substring(1) : 'xl/$target',
      ));
    }
    return out;
  }

  static List<int> _padWidths(String? styles) {
    if (styles == null) return const [];
    final codes = <int, String>{};
    for (final m in RegExp('<${_ns}numFmt\\b([^>]*?)/?>').allMatches(styles)) {
      final a = m.group(1)!;
      final id = int.tryParse(
        RegExp(r'\bnumFmtId="(\d+)"').firstMatch(a)?.group(1) ?? '',
      );
      final code = RegExp(r'\bformatCode="([^"]*)"').firstMatch(a)?.group(1);
      if (id != null && code != null) codes[id] = _unescape(code);
    }
    final block = RegExp(
      '<${_ns}cellXfs\\b[^>]*>([\\s\\S]*?)</${_ns}cellXfs>',
    ).firstMatch(styles)?.group(1);
    if (block == null) return const [];
    final out = <int>[];
    for (final m in RegExp('<${_ns}xf\\b([^>]*?)/?>').allMatches(block)) {
      final id = int.tryParse(
        RegExp(r'\bnumFmtId="(\d+)"').firstMatch(m.group(1)!)?.group(1) ?? '',
      );
      final code = id == null ? null : codes[id];
      out.add(
        code != null && RegExp(r'^0{2,}$').hasMatch(code) ? code.length : 0,
      );
    }
    return out;
  }

  static List<List<String>> _rows(
    String sheet,
    List<String> shared,
    List<int> pads,
  ) {
    final rows = <List<String>>[];
    for (final rm in RegExp(
      '<${_ns}row\\b[^>]*?(?:/>|>([\\s\\S]*?)</${_ns}row>)',
    ).allMatches(sheet)) {
      final body = rm.group(1);
      if (body == null) continue;
      final row = <String>[];
      for (final cm in RegExp(
        '<${_ns}c\\b([^>]*?)(?:/>|>([\\s\\S]*?)</${_ns}c>)',
      ).allMatches(body)) {
        final attrs = cm.group(1) ?? '';
        final inner = cm.group(2) ?? '';
        final ref = RegExp(r'\br="([A-Z]+)\d+"').firstMatch(attrs)?.group(1);
        final idx = ref == null ? row.length : _colIndex(ref);
        if (idx < 0 || idx > _maxColumn) continue;
        while (row.length < idx) {
          row.add('');
        }
        final t = RegExp(r'\bt="([^"]+)"').firstMatch(attrs)?.group(1);
        String v;
        if (t == 'inlineStr') {
          v = _texts(inner);
        } else {
          final raw =
              RegExp(
                '<${_ns}v>([\\s\\S]*?)</${_ns}v>',
              ).firstMatch(inner)?.group(1) ??
              '';
          if (t == 's') {
            final i = int.tryParse(raw) ?? -1;
            v = i >= 0 && i < shared.length ? shared[i] : '';
          } else if (t == 'str' || t == 'e' || t == 'b') {
            v = _unescape(raw);
          } else {
            v = _number(raw);
            final si = int.tryParse(
              RegExp(r'\bs="(\d+)"').firstMatch(attrs)?.group(1) ?? '',
            );
            final width = si != null && si < pads.length ? pads[si] : 0;
            if (width > 0 && v.length < width && RegExp(r'^\d+$').hasMatch(v)) {
              v = v.padLeft(width, '0');
            }
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
    final clean = xml.replaceAll(
      RegExp('<${_ns}rPh\\b[^>]*>[\\s\\S]*?</${_ns}rPh>'),
      '',
    );
    final b = StringBuffer();
    for (final m in RegExp(
      '<${_ns}t(?:\\s[^>]*)?>([\\s\\S]*?)</${_ns}t>',
    ).allMatches(clean)) {
      b.write(_unescape(m.group(1)!));
    }
    return b.toString();
  }

  static String _char(int? code) {
    if (code == null || code < 0 || code > 0x10FFFF) return '';
    if (code >= 0xD800 && code <= 0xDFFF) return '';
    return String.fromCharCode(code);
  }

  static String _unescape(String s) => s
      .replaceAllMapped(
        RegExp(r'&#x([0-9a-fA-F]{1,8});'),
        (m) => _char(int.tryParse(m.group(1)!, radix: 16)),
      )
      .replaceAllMapped(
        RegExp(r'&#(\d{1,9});'),
        (m) => _char(int.tryParse(m.group(1)!)),
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

  static String _sheetName(String raw, String fallback) {
    final s = raw.replaceAll(RegExp(r"[\\/?*\[\]:']"), '').trim();
    final cut = s.runes.length > 31
        ? String.fromCharCodes(s.runes.take(31))
        : s;
    return cut.isEmpty ? fallback : cut;
  }

  static String _otherName(String name, String taken) =>
      name.toLowerCase() == taken.toLowerCase()
      ? '${String.fromCharCodes(name.runes.take(28))} 2'
      : name;

  static List<int> _widths(List<List<String>> rows, List<int> fixed) {
    final width = rows.fold<int>(
      fixed.length,
      (m, r) => r.length > m ? r.length : m,
    );
    final out = List<int>.generate(
      width,
      (i) => i < fixed.length ? fixed[i] : 10,
    );
    if (fixed.isEmpty) {
      for (final r in rows) {
        for (var i = 0; i < r.length; i++) {
          final l = r[i].runes.length + 2;
          if (l > out[i]) out[i] = l > 60 ? 60 : l;
        }
      }
    }
    return out;
  }

  static String _sheetXml(
    List<List<String>> rows, {
    required List<int> widths,
    required Set<int> headerRows,
    required int bodyStyle,
    required bool rtl,
    required bool freeze,
    required bool filter,
    required bool textColumns,
  }) {
    final width = widths.length;
    final sd = StringBuffer();
    for (var ri = 0; ri < rows.length; ri++) {
      sd.write('<row r="${ri + 1}">');
      final r = rows[ri];
      final header = headerRows.contains(ri);
      final style = header ? 1 : bodyStyle;
      for (var ci = 0; ci < r.length; ci++) {
        final v = r[ci];
        if (v.isEmpty) {
          if (header) sd.write('<c r="${_colName(ci)}${ri + 1}" s="1"/>');
          continue;
        }
        sd.write(
          '<c r="${_colName(ci)}${ri + 1}" t="inlineStr" s="$style"><is><t xml:space="preserve">${_esc(v)}</t></is></c>',
        );
      }
      sd.write('</row>');
    }
    final cols = StringBuffer('<cols>');
    for (var i = 0; i < width; i++) {
      cols.write(
        '<col min="${i + 1}" max="${i + 1}" width="${widths[i]}" customWidth="1"${textColumns ? ' style="2"' : ''}/>',
      );
    }
    cols.write('</cols>');
    final view = freeze
        ? '<sheetView workbookViewId="0"${rtl ? ' rightToLeft="1"' : ''}><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView>'
        : '<sheetView workbookViewId="0"${rtl ? ' rightToLeft="1"' : ''}/>';
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<sheetViews>$view</sheetViews>'
        '${width > 0 ? cols : ''}<sheetData>$sd</sheetData>'
        '${filter && rows.isNotEmpty && width > 0 ? '<autoFilter ref="A1:${_colName(width - 1)}${rows.length}"/>' : ''}'
        '</worksheet>';
  }

  static Uint8List write(
    List<List<String>> rows, {
    String sheetName = 'Contacts',
    bool rtl = false,
    bool textColumns = false,
    List<int> columnWidths = const [],
    XlsxSheet? guide,
  }) {
    final first = _sheetName(sheetName, 'Contacts');
    final second = guide == null
        ? null
        : _otherName(_sheetName(guide.name, 'Guide'), first);
    final widths = _widths(rows, columnWidths);
    final width = widths.length;
    final sheet = _sheetXml(
      rows,
      widths: widths,
      headerRows: const {0},
      bodyStyle: 2,
      rtl: rtl,
      freeze: true,
      filter: true,
      textColumns: textColumns,
    );
    final guideSheet = guide == null
        ? null
        : _sheetXml(
            guide.rows,
            widths: _widths(guide.rows, guide.widths),
            headerRows: guide.headerRows,
            bodyStyle: 3,
            rtl: rtl,
            freeze: false,
            filter: false,
            textColumns: false,
          );
    final styles =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<numFmts count="0"/>'
        '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font></fonts>'
        '<fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill><fill><patternFill patternType="solid"><fgColor rgb="FFE8664A"/><bgColor indexed="64"/></patternFill></fill></fills>'
        '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
        '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
        '<cellXfs count="4"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
        '<xf numFmtId="49" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1" applyNumberFormat="1"/>'
        '<xf numFmtId="49" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
        '<xf numFmtId="49" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyAlignment="1"><alignment vertical="top" wrapText="1"/></xf></cellXfs>'
        '</styleSheet>';
    final files = <String, String>{
      '[Content_Types].xml':
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
          '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
          '<Default Extension="xml" ContentType="application/xml"/>'
          '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
          '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
          '${guideSheet == null ? '' : '<Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'}'
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
          '<sheets><sheet name="${_esc(first)}" sheetId="1" r:id="rId1"/>${second == null ? '' : '<sheet name="${_esc(second)}" sheetId="2" r:id="rId3"/>'}</sheets>'
          '${rows.isNotEmpty && width > 0 ? '<definedNames><definedName name="_xlnm._FilterDatabase" localSheetId="0" hidden="1">\'${_esc(first)}\'!\$A\$1:\$${_colName(width - 1)}\$${rows.length}</definedName></definedNames>' : ''}'
          '</workbook>',
      'xl/_rels/workbook.xml.rels':
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
          '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
          '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
          '${guideSheet == null ? '' : '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/>'}'
          '</Relationships>',
      'xl/styles.xml': styles,
      'xl/worksheets/sheet1.xml': sheet,
      if (guideSheet != null) 'xl/worksheets/sheet2.xml': guideSheet,
    };
    final a = Archive();
    files.forEach((k, v) {
      final data = utf8.encode(v);
      a.addFile(ArchiveFile(k, data.length, data));
    });
    return Uint8List.fromList(ZipEncoder().encode(a)!);
  }
}

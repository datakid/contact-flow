import 'dart:typed_data';

import '../io/codec.dart';
import '../io/xlsx.dart';
import '../l10n.dart';

class SheetTemplate {
  static const formats = [Format.xlsx, Format.csv];

  static String fileName(Format f) => 'contact-flow-template.${f.exportExt}';

  static List<String> headers(L l) => [
    l.t('name'),
    l.t('phone'),
    l.t('email'),
    l.t('company'),
    l.t('note'),
    l.t('alias'),
  ];

  static XlsxSheet guide(L l) {
    final c = Codec.templateColumns(headers: headers(l));
    return XlsxSheet(
      l.t('tplSheet'),
      [
        [l.t('tplTitle'), '', ''],
        [],
        [l.t('tplColColumn'), l.t('tplColMeaning'), l.t('tplColExample')],
        [c[0], l.t('tplName'), l.t('tplExName')],
        [c[1], l.t('tplPhone'), l.t('tplExPhone')],
        [c[2], l.t('tplPhone2'), l.t('tplExPhone2')],
        [c[3], l.t('tplEmail'), 'sara@example.com'],
        [c[4], l.t('tplCompany'), 'Acme'],
        [c[5], l.t('tplNote'), l.t('tplExNote')],
        [c[6], l.t('tplAlias'), l.t('tplExAlias')],
        [],
        [l.t('tplTips'), l.t('tplTip1')],
        ['', l.t('tplTip2')],
        ['', l.t('tplTip3')],
      ],
      widths: const [20, 64, 28],
      headerRows: const {0, 2},
    );
  }

  static Uint8List build(Format f, L l) => Codec.template(
    f,
    headers: headers(l),
    guide: f == Format.xlsx ? guide(l) : null,
    sheetName: l.t('tplContacts'),
    rtl: l.rtl,
  );
}

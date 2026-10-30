import 'package:phone_numbers_parser/metadata.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import '../models/person.dart';

class PhoneInfo {
  final String key;
  final bool explicit;
  final String? e164;
  final PhoneNumber? parsed;
  const PhoneInfo(this.key, this.explicit, this.e164, this.parsed);

  static const empty = PhoneInfo('', false, null, null);

  bool get isEmpty => key.isEmpty;
}

class PhoneKey {
  static IsoCode? _region;
  static final Map<String, PhoneInfo> _cache = {};
  static final _ext = RegExp(
    r'\s*(?:x|ext\.?|#)\s*\d+\s*$',
    caseSensitive: false,
  );
  static final _nonDigit = RegExp(r'[^0-9]');

  static IsoCode? get region => _region;

  static String get regionCode => _region?.name ?? '';

  static IsoCode? parseRegion(String? iso) {
    final t = iso?.trim().toUpperCase() ?? '';
    if (t.isEmpty) return null;
    for (final r in IsoCode.values) {
      if (r.name == t) return r;
    }
    return null;
  }

  static void useRegion(String? iso) {
    final next = parseRegion(iso);
    if (next == _region) return;
    _region = next;
    _cache.clear();
  }

  static String callingCode(IsoCode r) =>
      metadataByIsoCode[r]?.countryCode ?? '';

  static List<IsoCode> regionsForCode(String cc) {
    final digits = cc
        .replaceAll(_nonDigit, '')
        .replaceFirst(RegExp(r'^0+'), '');
    return countryCodeToIsoCode[digits] ?? const <IsoCode>[];
  }

  static IsoCode? uniqueRegionForCode(String cc) {
    final list = regionsForCode(cc);
    return list.length == 1 ? list.first : null;
  }

  static String _last9(String x) =>
      x.length > 9 ? x.substring(x.length - 9) : x;

  static PhoneInfo info(String raw) {
    final hit = _cache[raw];
    if (hit != null) return hit;
    final v = _compute(raw, _region);
    if (_cache.length > 200000) _cache.clear();
    _cache[raw] = v;
    return v;
  }

  static IsoCode? mainRegionForCode(String cc) {
    final list = regionsForCode(cc);
    return list.isEmpty ? null : list.first;
  }

  static PhoneInfo infoIn(String raw, IsoCode region) => _compute(raw, region);

  static String extension(String raw) {
    final m = _ext.firstMatch(Phones.asciiDigits(raw).trim());
    return m == null ? '' : m.group(0)!.replaceAll(_nonDigit, '');
  }

  static PhoneInfo _compute(String raw, IsoCode? region) {
    final s = Phones.asciiDigits(raw).trim().replaceFirst(_ext, '');
    final plus = s.startsWith('+');
    var d = s.replaceAll(_nonDigit, '');
    if (d.length < 5) return PhoneInfo.empty;
    var explicit = plus;
    if (!plus && d.startsWith('00') && d.length > 9) {
      explicit = true;
      d = d.substring(2);
    }
    if (explicit) {
      try {
        final pn = PhoneNumber.parse('+$d');
        if (pn.isValid()) {
          return PhoneInfo(_last9(pn.nsn), true, pn.international, pn);
        }
      } catch (_) {}
      return PhoneInfo(_last9(d), false, null, null);
    }
    if (region != null) {
      try {
        final pn = PhoneNumber.parse(d, callerCountry: region);
        if (pn.isValid()) {
          return PhoneInfo(_last9(pn.nsn), false, pn.international, pn);
        }
      } catch (_) {}
    }
    return PhoneInfo(_last9(d), false, null, null);
  }

  static String key(String raw) => info(raw).key;

  static bool compatible(String a, String b) {
    final x = info(a);
    final y = info(b);
    if (x.key.isEmpty || x.key != y.key) return false;
    if (x.explicit && y.explicit) return x.e164 == y.e164;
    return true;
  }

  static String? e164(String raw) => info(raw).e164;

  static String? international(String raw) {
    final pn = info(raw).parsed;
    if (pn == null) return null;
    final body = pn.formatNsn(format: NsnFormat.international);
    return '+${pn.countryCode} $body';
  }

  static String? national(String raw) {
    final pn = info(raw).parsed;
    if (pn == null) return null;
    final formatted = pn.formatNsn();
    final np = metadataByIsoCode[pn.isoCode]?.nationalPrefix ?? '';
    final rule = _nationalRule(pn.isoCode, pn.nsn);
    if (np.isEmpty || rule == null || rule.isEmpty) return formatted;
    final cut = formatted.indexOf(RegExp(r'[^0-9]'));
    final first = cut < 0 ? formatted : formatted.substring(0, cut);
    final rest = cut < 0 ? '' : formatted.substring(cut);
    return rule.replaceAll(r'$NP', np).replaceAll(r'$FG', first) + rest;
  }

  static String? _nationalRule(IsoCode iso, String nsn) {
    try {
      dynamic def = metadataFormatsByIsoCode[iso];
      var hops = 0;
      while (def != null && hops++ < 4) {
        try {
          def = metadataFormatsByIsoCode[def.referenceIsoCode as IsoCode];
        } catch (_) {
          break;
        }
      }
      final formats = def?.formats as List?;
      if (formats == null || formats.isEmpty) return null;
      dynamic hit;
      if (formats.length == 1) {
        hit = formats.first;
      } else {
        for (final f in formats) {
          final lead = (f.leadingDigits as List).cast<String>();
          final leadOk =
              lead.isEmpty || RegExp(lead.last).matchAsPrefix(nsn) != null;
          if (leadOk && RegExp('^(?:${f.pattern})\$').hasMatch(nsn)) {
            hit = f;
            break;
          }
        }
      }
      return hit?.nationalPrefixFormattingRule as String?;
    } catch (_) {
      return null;
    }
  }
}

import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/services.dart';

import '../phone/phone_key.dart';

class RegionDetect {
  static const _channel = MethodChannel('contactflow/device');

  static Future<String> detect() async {
    try {
      final sim = await _channel.invokeMethod<String>('simCountry');
      final r = PhoneKey.parseRegion(sim);
      if (r != null) return r.name;
    } catch (_) {}
    final locale = PlatformDispatcher.instance.locale.countryCode;
    return PhoneKey.parseRegion(locale)?.name ?? '';
  }
}

import 'package:flutter/services.dart';

const bool callsBuild = bool.fromEnvironment('CALLS');

class Edition {
  static const _channel = MethodChannel('contactflow/device');

  static Future<String?> nativeName() async {
    try {
      return await _channel.invokeMethod<String>('edition');
    } catch (_) {
      return null;
    }
  }

  static String dartName({bool calls = callsBuild}) => calls ? 'full' : 'lite';

  static String? mismatch(String? native, {bool calls = callsBuild}) {
    if (native == null || native.isEmpty) return null;
    return native == dartName(calls: calls) ? null : native;
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class IncomingFile {
  final String name;
  final Uint8List bytes;
  const IncomingFile(this.name, this.bytes);
}

class Incoming {
  static const _ch = MethodChannel('contactflow/incoming');
  static final _ctrl = StreamController<List<IncomingFile>>.broadcast();
  static bool _ready = false;

  static Stream<List<IncomingFile>> get stream => _ctrl.stream;

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static void start() {
    if (!supported || _ready) return;
    _ready = true;
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'ready') await _take();
    });
    _take();
  }

  static Future<void> _take() async {
    try {
      final raw = await _ch.invokeMethod<List<dynamic>>('take');
      if (raw == null || raw.isEmpty) return;
      final files = <IncomingFile>[];
      for (final m in raw.whereType<Map>()) {
        final b = m['bytes'];
        if (b is Uint8List) {
          files.add(IncomingFile('${m['name'] ?? 'shared'}', b));
        }
      }
      if (files.isNotEmpty) _ctrl.add(files);
    } catch (_) {}
  }
}

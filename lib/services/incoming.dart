import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'incoming_read.dart';

class IncomingFile {
  final String name;
  final Uint8List? bytes;
  final String? path;
  final String? error;
  const IncomingFile(this.name, {this.bytes, this.path, this.error});

  Future<Uint8List?> read() async {
    final b = bytes;
    if (b != null) return b;
    final p = path;
    if (p == null) return null;
    return takeFileBytes(p);
  }
}

class Incoming {
  static const _ch = MethodChannel('contactflow/incoming');
  static final List<IncomingFile> _buffer = [];
  static void Function(List<IncomingFile>)? _handler;
  static bool _ready = false;

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static void attach(void Function(List<IncomingFile>) handler) {
    _handler = handler;
    _flush();
    start();
  }

  static void detach(void Function(List<IncomingFile>) handler) {
    if (_handler == handler) _handler = null;
  }

  static void start() {
    if (!supported || _ready) return;
    _ready = true;
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'ready') await _take();
    });
    unawaited(_take());
  }

  @visibleForTesting
  static void deliver(List<IncomingFile> files) {
    _buffer.addAll(files);
    _flush();
  }

  @visibleForTesting
  static void reset() {
    _buffer.clear();
    _handler = null;
  }

  static void _flush() {
    final h = _handler;
    if (h == null || _buffer.isEmpty) return;
    final out = List<IncomingFile>.of(_buffer);
    _buffer.clear();
    h(out);
  }

  static Future<void> _take() async {
    try {
      final raw = await _ch.invokeMethod<List<dynamic>>('take');
      if (raw == null || raw.isEmpty) return;
      final files = <IncomingFile>[];
      for (final m in raw.whereType<Map>()) {
        final name = '${m['name'] ?? 'shared'}';
        final b = m['bytes'];
        final path = m['path'];
        final error = m['error'];
        if (b is Uint8List) {
          files.add(IncomingFile(name, bytes: b));
        } else if (path is String) {
          files.add(IncomingFile(name, path: path));
        } else if (error is String) {
          files.add(IncomingFile(name, error: error));
        }
      }
      if (files.isNotEmpty) deliver(files);
    } catch (_) {}
  }
}

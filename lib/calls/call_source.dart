import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../services/edition.dart';
import 'call_models.dart';

abstract class CallSource {
  Future<bool> hasPermission();
  Future<bool> request();
  Future<List<CallRecord>> readAll({void Function(int loaded)? onPage});
}

class ChannelCallSource implements CallSource {
  static const pageSize = 2000;
  final MethodChannel _ch;

  ChannelCallSource([MethodChannel? channel])
    : _ch = channel ?? const MethodChannel('contactflow/calls');

  static bool get supported =>
      callsBuild && !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> hasPermission() async =>
      await _ch.invokeMethod<bool>('hasPermission') ?? false;

  @override
  Future<bool> request() async =>
      await _ch.invokeMethod<bool>('request') ?? false;

  @override
  Future<List<CallRecord>> readAll({void Function(int loaded)? onPage}) async {
    final out = <CallRecord>[];
    int? before;
    while (true) {
      final page = await _ch.invokeMethod<List<dynamic>>('read', {
        'before': before,
        'size': pageSize,
      });
      final rows = [
        for (final m in page ?? const <dynamic>[])
          CallRecord.fromMap(m as Map<dynamic, dynamic>),
      ];
      out.addAll(rows);
      onPage?.call(out.length);
      if (rows.length < pageSize) break;
      before = rows.last.dateMs;
    }
    return out;
  }
}

class FakeCallSource implements CallSource {
  final List<CallRecord> records;
  bool granted;
  FakeCallSource(this.records, {this.granted = true});

  @override
  Future<bool> hasPermission() async => granted;

  @override
  Future<bool> request() async => granted;

  @override
  Future<List<CallRecord>> readAll({void Function(int loaded)? onPage}) async {
    if (!granted) throw StateError('denied');
    final sorted = [...records]..sort((a, b) => b.dateMs.compareTo(a.dateMs));
    onPage?.call(sorted.length);
    return sorted;
  }
}

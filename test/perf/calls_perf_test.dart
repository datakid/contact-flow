@Tags(['perf'])
library;

import 'dart:io';

import 'package:contact_flow/calls/call_grouper.dart';
import 'package:contact_flow/calls/call_models.dart';
import 'package:contact_flow/calls/saved_numbers.dart';
import 'package:contact_flow/phone/phone_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('20k calls group in under 500 ms', () {
    PhoneKey.useRegion('SA');
    addTearDown(() => PhoneKey.useRegion(''));
    final calls = <CallRecord>[
      for (var i = 0; i < 20000; i++)
        CallRecord(
          number: i % 3 == 0
              ? '05${(i % 3000).toString().padLeft(8, '0').substring(1)}'
              : '+9665${(i % 3000).toString().padLeft(8, '0')}',
          dateMs: 1700000000000 + i * 1000,
          durationSec: i % 90,
          type: CallType.values[i % 3],
        ),
    ];
    final saved = SavedNumbers.of(const []);
    final sw = Stopwatch()..start();
    final groups = CallGrouper.group(calls, saved: saved);
    stdout.writeln('20k calls: ${sw.elapsedMilliseconds}ms ${groups.length}');
    expect(groups, isNotEmpty);
    expect(sw.elapsedMilliseconds, lessThan(500));
  });
}

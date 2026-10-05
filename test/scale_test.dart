import 'package:contact_flow/domain/merger.dart';
import 'package:contact_flow/domain/planner.dart';
import 'package:contact_flow/domain/sync.dart';
import 'package:contact_flow/models/person.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

List<Person> book(int n) => [
  for (var i = 0; i < n; i++)
    Person(
      name: 'Person ${i.toString().padLeft(5, '0')} Family${i % 97}',
      phones: [PhoneEntry('+97150${(1000000 + i).toString()}')],
      emails: ['p$i@example.com'],
      org: i % 3 == 0 ? 'Org ${i % 40}' : '',
      phoneId: '$i',
    ),
];

List<Person> sheet(int n) => [
  for (var i = 0; i < n; i++)
    Person(
      name: 'Person ${i.toString().padLeft(5, '0')} Family${i % 97}',
      phones: [PhoneEntry('050${(1000000 + i).toString()}')],
      org: 'Updated ${i % 11}',
      phoneId: i.isEven ? '$i' : null,
    ),
];

List<Person> runDupes(List<Person> p) => [
  for (final g in Merger.findDuplicates(p)) ...g.people,
];

int runBatchPlan(List<Person> p) {
  final edited = [for (final x in p) x.copy()..org = 'New'];
  return Planner.batch(p, edited).length;
}

void main() {
  test('sync planner on 5k phone × 5k rows in an isolate under 2 s', () async {
    final phone = book(5000);
    final rows = sheet(5000);
    final sw = Stopwatch()..start();
    final plan = await compute(
      runSyncPlan,
      SyncJob(phone, rows, FieldPolicy.fillEmpty),
    );
    sw.stop();
    debugPrint('sync 5k×5k: ${sw.elapsedMilliseconds} ms');
    expect(plan.updates.length + plan.unchanged.length, 5000);
    expect(plan.conflicts, isEmpty);
    expect(sw.elapsedMilliseconds, lessThan(2000));
  });

  test('duplicate finder and batch planner on 5k contacts', () async {
    final phone = book(5000);
    final sw = Stopwatch()..start();
    final dupes = await compute(runDupes, phone);
    final planned = await compute(runBatchPlan, phone);
    sw.stop();
    debugPrint('dupes + batch 5k: ${sw.elapsedMilliseconds} ms');
    expect(dupes, isEmpty);
    expect(planned, 5000);
    expect(sw.elapsedMilliseconds, lessThan(2000));
  });
}

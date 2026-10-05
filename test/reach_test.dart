import 'package:contact_flow/domain/queue.dart';
import 'package:contact_flow/domain/reach.dart';
import 'package:contact_flow/models/person.dart';
import 'package:flutter_test/flutter_test.dart';

Uri ready(ReachOutcome o) => (o as ReachReady).link.uri;

void main() {
  group('Reach links', () {
    test('call and SMS keep the number as dialled', () {
      expect(
        ready(Reach.link(Channel.call, '050 123-4567')).toString(),
        'tel:0501234567',
      );
      expect(
        ready(Reach.link(Channel.call, '+44 7700 900461')).toString(),
        'tel:+447700900461',
      );
      final sms = ready(
        Reach.link(Channel.sms, '+971 50 123 4567', text: 'Hi Ali & co'),
      );
      expect(sms.scheme, 'smsto');
      expect(sms.path, '+971501234567');
      expect(Uri.decodeComponent(sms.query.split('=').last), 'Hi Ali & co');
    });

    test('WhatsApp uses wa.me with international digits', () {
      final u = ready(
        Reach.link(
          Channel.whatsapp,
          '050 123 4567',
          country: '+971',
          text: 'مرحبا',
        ),
      );
      expect(u.host, 'wa.me');
      expect(u.path, '/971501234567');
      expect(u.queryParameters['text'], 'مرحبا');
      expect(
        ready(Reach.link(Channel.whatsapp, '+44 7700 900461')).path,
        '/447700900461',
      );
    });

    test('Signal uses signal.me with +E164', () {
      final u = ready(Reach.link(Channel.signal, '00971 50 123 4567'));
      expect(u.toString(), 'https://signal.me/#p/+971501234567');
    });

    test('asks for a country when a number has no prefix', () {
      expect(
        Reach.link(Channel.whatsapp, '050 123 4567'),
        isA<ReachNeedsCountry>(),
      );
      expect(
        Reach.link(Channel.signal, '050 123 4567'),
        isA<ReachNeedsCountry>(),
      );
      expect(Reach.link(Channel.call, '050 123 4567'), isA<ReachReady>());
    });

    test('invalid numbers are refused', () {
      expect(Reach.link(Channel.call, '—'), isA<ReachInvalid>());
      expect(
        Reach.link(Channel.whatsapp, '12345', country: '1'),
        isA<ReachInvalid>(),
      );
    });

    test('group SMS joins recipients', () {
      final u = Reach.groupSms([
        '+1 415 555 0101',
        '050 111 2222',
      ], text: 'Party!');
      expect(u.path, '+14155550101;0501112222');
    });

    test('copy numbers removes repeats and can normalise', () {
      final people = [
        Person(
          name: 'A',
          phones: [
            const PhoneEntry('050 111 2222'),
            const PhoneEntry('+971 50 111 2222'),
          ],
        ),
        Person(name: 'B', phones: [const PhoneEntry('+44 7700 900461')]),
      ];
      expect(Reach.copyList(people), ['050 111 2222', '+44 7700 900461']);
      expect(Reach.copyList(people, e164: true, country: '971'), [
        '+971501112222',
        '+447700900461',
      ]);
    });
  });

  group('Message queue', () {
    final people = [
      Person(
        id: 'a',
        name: 'Amelia Hart',
        phones: [const PhoneEntry('+44 7700 900461')],
      ),
      Person(id: 'b', name: 'No Number'),
      Person(
        id: 'c',
        name: 'محمد عبد الله',
        phones: [const PhoneEntry('050 123 4567')],
      ),
      Person(
        id: 'd',
        name: 'Jon Smith',
        phones: [const PhoneEntry('+1 415 555 0101')],
      ),
      Person(
        id: 'e',
        name: 'Léa Fontaine',
        phones: [const PhoneEntry('+33 6 12 34 56 78')],
      ),
      Person(
        id: 'f',
        name: '王伟',
        phones: [const PhoneEntry('+86 138 0013 8000')],
      ),
    ];

    test('personalises each step and lists people without a number', () {
      final q = MessageQueue.build(people, 'Hi {first}!');
      expect(q.total, 5);
      expect(q.withoutNumber, ['No Number']);
      expect(q.steps.first.text, 'Hi Amelia!');
      expect(q.steps[1].text, 'Hi محمد عبد!');
    });

    test('progress survives a restart and resumes at the right person', () {
      final q = MessageQueue.build(
        people,
        'Hello {name}',
        channel: Channel.whatsapp,
        country: '971',
      );
      q.markOpened();
      q.markSent();
      q.skip();
      q.markOpened();
      final saved = q.encode();
      final back = MessageQueue.decode(saved)!;
      expect(back.id, q.id);
      expect(back.channel, Channel.whatsapp);
      expect(back.country, '971');
      expect(back.sent, 1);
      expect(back.skipped, 1);
      expect(back.awaitingReturn, isTrue);
      expect(back.current!.name, 'Jon Smith');
      back.markSent();
      back.markOpened();
      back.markSent();
      back.markOpened();
      back.markSent();
      expect(back.finished, isTrue);
      expect(back.progress, 1);
      expect(back.currentIndex, isNull);
    });

    test('stop ends the queue; garbage decodes to null', () {
      final q = MessageQueue.build(people, 'x')..stop();
      expect(MessageQueue.decode(q.encode())!.finished, isTrue);
      expect(MessageQueue.decode('{oops'), isNull);
      expect(MessageQueue.decode(null), isNull);
    });

    test('links come from the queue channel', () {
      final q = MessageQueue.build(
        people,
        'Hi',
        channel: Channel.whatsapp,
        country: '971',
      );
      final c = q.steps.firstWhere((s) => s.contactId == 'c');
      expect(ready(q.linkFor(c)).path, '/971501234567');
    });
  });
}

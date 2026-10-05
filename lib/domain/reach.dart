import '../models/person.dart';
import 'international.dart';

enum Channel { call, sms, whatsapp, signal }

class ReachLink {
  final Channel channel;
  final Uri uri;
  const ReachLink(this.channel, this.uri);
}

sealed class ReachOutcome {
  const ReachOutcome();
}

class ReachReady extends ReachOutcome {
  final ReachLink link;
  const ReachReady(this.link);
}

class ReachNeedsCountry extends ReachOutcome {
  const ReachNeedsCountry();
}

class ReachInvalid extends ReachOutcome {
  const ReachInvalid();
}

class Reach {
  static const groupWarnAt = 50;

  static String dialable(String number) {
    final a = Phones.asciiDigits(number).trim();
    final plus = a.startsWith('+');
    final d = Phones.digits(a);
    return plus ? '+$d' : d;
  }

  static ReachOutcome link(
    Channel channel,
    String number, {
    String country = '',
    String text = '',
  }) {
    final d = dialable(number);
    if (Phones.digits(d).length < 3) return const ReachInvalid();
    switch (channel) {
      case Channel.call:
        return ReachReady(ReachLink(channel, Uri(scheme: 'tel', path: d)));
      case Channel.sms:
        return ReachReady(
          ReachLink(
            channel,
            Uri(
              scheme: 'smsto',
              path: d,
              query: text.isEmpty ? null : 'body=${Uri.encodeComponent(text)}',
            ),
          ),
        );
      case Channel.whatsapp:
      case Channel.signal:
        final n = InternationalNumber.of(number, country: country);
        if (n.status == InternationalStatus.needsCountry) {
          return const ReachNeedsCountry();
        }
        if (!n.ok) return const ReachInvalid();
        if (channel == Channel.whatsapp) {
          return ReachReady(
            ReachLink(
              channel,
              Uri.https(
                'wa.me',
                '/${n.digits}',
                text.isEmpty ? null : {'text': text},
              ),
            ),
          );
        }
        return ReachReady(
          ReachLink(channel, Uri.parse('https://signal.me/#p/${n.e164}')),
        );
    }
  }

  static Uri groupSms(List<String> numbers, {String text = ''}) {
    final list = numbers.map(dialable).where((n) => n.isNotEmpty).join(';');
    return Uri(
      scheme: 'smsto',
      path: list,
      query: text.isEmpty ? null : 'body=${Uri.encodeComponent(text)}',
    );
  }

  static List<String> copyList(
    Iterable<Person> people, {
    bool e164 = false,
    String country = '',
  }) {
    final out = <String>[];
    final seen = <String>{};
    for (final p in people) {
      for (final e in p.phones) {
        final v = e164
            ? (InternationalNumber.of(e.number, country: country).ok
                  ? InternationalNumber.of(e.number, country: country).e164
                  : dialable(e.number))
            : e.number.trim();
        final k = Phones.key(v).isEmpty ? v : Phones.key(v);
        if (v.isNotEmpty && seen.add(k)) out.add(v);
      }
    }
    return out;
  }
}

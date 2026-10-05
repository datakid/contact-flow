import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../domain/international.dart';
import '../domain/reach.dart';
import '../io/vcard.dart';
import '../l10n.dart';
import '../models/person.dart';
import '../services/file_out.dart';
import '../services/launcher.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'widgets.dart';

class ReachApps {
  static final Map<Channel, bool> _cache = {};

  static Uri probe(Channel c) => switch (c) {
    Channel.whatsapp => Uri.parse('whatsapp://send?phone=0'),
    Channel.signal => Uri.parse('sgnl://signal.me'),
    Channel.call => Uri(scheme: 'tel', path: '0'),
    Channel.sms => Uri(scheme: 'smsto', path: '0'),
  };

  static Future<bool> available(Launcher launcher, Channel c) async {
    if (c == Channel.call || c == Channel.sms) return true;
    final hit = _cache[c];
    if (hit != null) return hit;
    final ok = await launcher.canOpen(probe(c));
    _cache[c] = ok;
    return ok;
  }

  static void reset() => _cache.clear();
}

String channelLabel(L l, Channel c) => l.t('ch_${c.name}');

IconData channelIcon(Channel c) => switch (c) {
  Channel.call => Icons.call_rounded,
  Channel.sms => Icons.sms_outlined,
  Channel.whatsapp => Icons.chat_rounded,
  Channel.signal => Icons.lock_outline_rounded,
};

Future<String?> askCountry(BuildContext context, {bool force = false}) async {
  final app = context.read<AppState>();
  if (!force && app.country.isNotEmpty) return app.country;
  final l = L.of(context);
  final p = context.pal;
  final c = TextEditingController(
    text: InternationalNumber.countryDigits(app.country),
  );
  final picked = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.t('countryTitle'), style: Type.display(p, size: 28)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.t('countryBody'),
              style: TextStyle(color: p.inkSoft, height: 1.5),
            ),
            const SizedBox(height: 14),
            Directionality(
              textDirection: TextDirection.ltr,
              child: TextField(
                key: const ValueKey('countryField'),
                controller: c,
                autofocus: true,
                keyboardType: TextInputType.phone,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: p.ink,
                ),
                decoration: InputDecoration(
                  prefixText: '+ ',
                  hintText: '971',
                  filled: true,
                  fillColor: p.paper,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: p.hairline),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final cc in const [
                  '1',
                  '44',
                  '971',
                  '966',
                  '20',
                  '33',
                  '34',
                  '49',
                  '86',
                  '91',
                ])
                  ActionChip(label: Text('+$cc'), onPressed: () => c.text = cc),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(
            l.t('cancel'),
            style: TextStyle(color: p.ink, fontWeight: FontWeight.w700),
          ),
        ),
        TextButton(
          key: const ValueKey('countrySave'),
          onPressed: () {
            final d = InternationalNumber.countryDigits(c.text);
            Navigator.pop(ctx, d.isEmpty || d.length > 4 ? null : '+$d');
          },
          child: Text(
            l.t('save'),
            style: TextStyle(color: p.accent, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
  if (picked != null) await app.setCountry(picked);
  return picked;
}

Future<bool> reachOut(
  BuildContext context,
  Channel channel,
  String number, {
  String text = '',
}) async {
  final l = L.of(context);
  final launcher = context.read<Launcher>();
  var country = context.read<AppState>().country;
  var outcome = Reach.link(channel, number, country: country, text: text);
  if (outcome is ReachNeedsCountry) {
    final c = await askCountry(context, force: true);
    if (c == null || !context.mounted) return false;
    country = c;
    outcome = Reach.link(channel, number, country: country, text: text);
  }
  switch (outcome) {
    case ReachReady():
      final ok = await launcher.open(outcome.link.uri);
      if (!ok && context.mounted) toast(context, l.t('cantOpen'));
      return ok;
    case ReachInvalid():
    case ReachNeedsCountry():
      if (context.mounted) toast(context, l.t('badNumber'));
      return false;
  }
}

Future<void> shareContact(BuildContext context, List<Person> people) async {
  final bytes = utf8.encode(VCard.write(people));
  final name = people.length == 1
      ? '${people.first.displayName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')}.vcf'
      : 'contacts.vcf';
  try {
    await shareBytes(bytes, name, 'text/vcard');
  } catch (e) {
    if (context.mounted) toast(context, friendlyError(e));
  }
}

Future<void> copyNumbers(BuildContext context, List<Person> people) async {
  final l = L.of(context);
  final p = context.pal;
  final app = context.read<AppState>();
  final withNumber = people.where((x) => x.hasNumber).length;
  final style = await showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
            child: Text(l.t('copyNumbers'), style: Type.display(p, size: 30)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              l.n(withNumber, 'withNumberOne', 'withNumberN'),
              style: TextStyle(color: p.inkSoft),
            ),
          ),
          ListTile(
            key: const ValueKey('copyAsSaved'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            leading: Icon(Icons.notes_rounded, color: p.ink),
            title: Text(
              l.t('copyAsSaved'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            onTap: () => Navigator.pop(c, 'saved'),
          ),
          ListTile(
            key: const ValueKey('copyE164'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            leading: Icon(Icons.public_rounded, color: p.ink),
            title: Text(
              l.t('copyE164'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              app.country.isEmpty
                  ? l.t('copyE164Sub')
                  : l.t('copyE164With', {'cc': app.country}),
            ),
            onTap: () => Navigator.pop(c, 'e164'),
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
  if (style == null || !context.mounted) return;
  var country = app.country;
  if (style == 'e164' && country.isEmpty) {
    country = await askCountry(context) ?? '';
    if (!context.mounted) return;
  }
  final list = Reach.copyList(people, e164: style == 'e164', country: country);
  await Clipboard.setData(ClipboardData(text: list.join('\n')));
  if (context.mounted) {
    toast(context, l.n(list.length, 'copiedNumbersOne', 'copiedNumbersN'));
  }
}

class ReachBar extends StatefulWidget {
  final Person person;
  const ReachBar({super.key, required this.person});

  @override
  State<ReachBar> createState() => _ReachBarState();
}

class _ReachBarState extends State<ReachBar> {
  Map<Channel, bool> _apps = const {
    Channel.whatsapp: true,
    Channel.signal: true,
  };

  @override
  void initState() {
    super.initState();
    final launcher = context.read<Launcher>();
    Future.wait([
      ReachApps.available(launcher, Channel.whatsapp),
      ReachApps.available(launcher, Channel.signal),
    ]).then((v) {
      if (mounted) {
        setState(() => _apps = {Channel.whatsapp: v[0], Channel.signal: v[1]});
      }
    });
  }

  Future<String?> _pickNumber() async {
    final phones = widget.person.phones
        .where((e) => Phones.digits(e.number).length >= 3)
        .toList();
    if (phones.isEmpty) return null;
    if (phones.length == 1) return phones.first.number;
    final l = L.of(context);
    return showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHandle(),
            for (final e in phones)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                title: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    e.number,
                    textAlign: l.rtl ? TextAlign.right : TextAlign.left,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                subtitle: Text(l.t('labels_${e.label}')),
                onTap: () => Navigator.pop(c, e.number),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _go(Channel c) async {
    final n = await _pickNumber();
    if (n == null || !mounted) return;
    await reachOut(context, c, n);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = context.pal;
    final has = widget.person.hasNumber;
    final channels = [
      Channel.call,
      Channel.sms,
      if (_apps[Channel.whatsapp] ?? true) Channel.whatsapp,
      if (_apps[Channel.signal] ?? true) Channel.signal,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final c in channels)
              _QuickAction(
                key: ValueKey('reach-${c.name}'),
                icon: channelIcon(c),
                label: channelLabel(l, c),
                onTap: has ? () => _go(c) : null,
              ),
            _QuickAction(
              key: const ValueKey('reach-copy'),
              icon: Icons.copy_rounded,
              label: l.t('copy'),
              onTap: has
                  ? () async {
                      final n = await _pickNumber();
                      if (n == null || !context.mounted) return;
                      await Clipboard.setData(ClipboardData(text: n));
                      if (context.mounted) toast(context, l.t('copied'));
                    }
                  : null,
            ),
          ],
        ),
        if (has && channels.contains(Channel.signal))
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              l.t('signalNote'),
              textAlign: TextAlign.center,
              style: TextStyle(color: p.inkFaint, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _QuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Pressable(
      onTap: onTap,
      haptic: true,
      child: SizedBox(
        width: 62,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: p.paper,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.hairline),
              ),
              child: Icon(icon, color: p.accent, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: p.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

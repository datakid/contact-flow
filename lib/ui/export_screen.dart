import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../io/codec.dart';
import '../io/jobs.dart';
import '../l10n.dart';
import '../models/person.dart';
import '../services/device_contacts.dart';
import '../services/file_out.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> openExport(BuildContext context, List<Person> people) {
  final l = L.of(context);
  if (people.isEmpty) {
    toast(context, l.t('nothingToExport'));
    return Future.value();
  }
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  return Navigator.of(context).push(
    PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, a, b) => ExportScreen(people: people),
      transitionsBuilder: (_, a, b, child) {
        final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: c,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(c),
            child: child,
          ),
        );
      },
    ),
  );
}

class ExportScreen extends StatefulWidget {
  final List<Person> people;
  const ExportScreen({super.key, required this.people});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  late Format _f;
  late ExportOptions _o;
  late final TextEditingController _name;
  bool _busy = false;
  double? _progress;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    _f = s.lastFormat;
    _o = s.exportOptions;
    final d = DateTime.now();
    _name = TextEditingController(
      text: 'contacts-${d.year}${_two(d.month)}${_two(d.day)}',
    );
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _fileName {
    final base = _name.text.trim().isEmpty
        ? 'contacts'
        : _name.text.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '-');
    return '$base.${_f.exportExt}';
  }

  List<String> _headers(L l) => [
    l.t('name'),
    l.t('phone'),
    l.t('email'),
    l.t('company'),
    l.t('note'),
  ];

  String _preview(L l) {
    final sample = widget.people.take(4).toList();
    switch (_f) {
      case Format.xlsx:
      case Format.numbers:
        final rows = Codec.table(sample, _o, headers: _headers(l));
        return rows
            .map((r) => r.where((c) => c.isNotEmpty).join('   │   '))
            .join('\n');
      default:
        final bytes = Codec.encode(sample, _f, _o, headers: _headers(l));
        var s = utf8
            .decode(bytes, allowMalformed: true)
            .replaceAll('\uFEFF', '')
            .replaceAll('\r\n', '\n');
        final lines = s.split('\n');
        if (lines.length > 14) s = '${lines.take(14).join('\n')}\n…';
        return s.trimRight();
    }
  }

  Future<void> _run({required bool share}) async {
    final l = L.of(context);
    final s = context.read<AppState>();
    setState(() => _busy = true);
    s.exportOptions = _o;
    s.rememberFormat(_f);
    try {
      final people = widget.people;
      final f = _f;
      final o = _o.copyWith(rtl: l.rtl);
      final headers = _headers(l);
      final bytes = await encodeInBackground(EncodeJob(people, f, o, headers));
      final name = _fileName;
      if (share) {
        await shareBytes(bytes, name, _f.mime);
      } else {
        final saved = await saveBytes(bytes, name, _f.mime);
        if (saved != null && mounted) {
          toast(context, l.t('saved', {'name': name}));
        }
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _toPhone() async {
    final l = L.of(context);
    if (!DeviceContacts.supported) {
      toast(context, l.t('webDevice').split('.').first);
      return;
    }
    final access = await DeviceContacts.request(write: true);
    if (!mounted) return;
    if (access != DeviceAccess.granted) {
      toast(
        context,
        access == DeviceAccess.blocked ? l.t('permBlocked') : l.t('permDenied'),
        action: access == DeviceAccess.blocked ? l.t('openSettings') : null,
        onAction: DeviceContacts.openSettings,
      );
      return;
    }
    setState(() => _progress = 0);
    try {
      final (n, skipped) = await DeviceContacts.writeAll(
        widget.people,
        progress: (v) {
          if (mounted) setState(() => _progress = v);
        },
      );
      if (mounted) {
        final msg = l.t('written', {'n': n});
        toast(
          context,
          skipped == 0
              ? msg
              : '$msg · ${l.t('skippedOnPhone', {'n': skipped})}',
        );
      }
    } catch (e) {
      if (mounted) toast(context, friendlyError(e));
    }
    if (mounted) setState(() => _progress = null);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = context.pal;
    final n = widget.people.length;
    final phones = widget.people.fold<int>(0, (a, x) => a + x.phones.length);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (DeviceContacts.supported)
            IconButton(
              tooltip: l.t('saveToPhone'),
              onPressed: _progress != null ? null : _toPhone,
              icon: const Icon(Icons.phone_iphone_rounded),
            ),
          const SizedBox(width: 6),
        ],
        bottom: _progress == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(value: _progress, minHeight: 2),
              ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.t('export'), style: Type.display(p, size: 52)),
                        const SizedBox(height: 6),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: l.n(n, 'contacts_one', 'contacts_many'),
                                style: TextStyle(
                                  color: p.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(
                                text: '  ·  ',
                                style: TextStyle(color: p.inkFaint),
                              ),
                              TextSpan(
                                text: l.n(
                                  phones,
                                  'numbers_one',
                                  'numbers_many',
                                ),
                                style: TextStyle(
                                  color: p.inkSoft,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          style: const TextStyle(fontSize: 14.5),
                        ),
                      ],
                    ),
                  ),
                  SectionLabel(l.t('format')),
                  SizedBox(
                    height: 150,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: Format.values.length,
                      separatorBuilder: (_, i) => const SizedBox(width: 10),
                      itemBuilder: (c, i) {
                        final f = Format.values[i];
                        final active = f == _f;
                        return Pressable(
                          haptic: true,
                          onTap: () => setState(() => _f = f),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                            width: 124,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: active ? p.sheet : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: active ? p.ink : p.hairline,
                                width: active ? 1.6 : 1.2,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FormatGlyph(f, size: 38, active: active),
                                const Spacer(),
                                Text(
                                  f.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: p.ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                SizedBox(
                                  height: 30,
                                  child: Text(
                                    formatBlurb(l, f),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      height: 1.3,
                                      color: p.inkSoft,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 240),
                    child: _f == Format.numbers
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 16,
                                  color: p.sage,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    l.t('numbersNote'),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: p.inkSoft,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  SectionLabel(l.t('fileName')),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      height: 54,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: p.sheet,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: p.hairline, width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _name,
                              onChanged: (_) => setState(() {}),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: p.ink,
                                fontSize: 15,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isCollapsed: true,
                              ),
                            ),
                          ),
                          Text(
                            '.${_f.exportExt}',
                            style: TextStyle(
                              color: p.inkFaint,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SectionLabel(l.t('options')),
                  _options(l, p),
                  SectionLabel(l.t('previewOut')),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      child: Container(
                        key: ValueKey(
                          '${_f.name}${_o.hashCode}${_o.header}${_o.includeEmail}${_o.includeOrg}${_o.includeNote}${_o.allNumbers}${_o.phoneStyle}${_o.txtWithNames}',
                        ),
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: p.sheet,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: p.hairline),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            _preview(l),
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontFamilyFallback: Type.fallback,
                              fontSize: 12,
                              height: 1.6,
                              color: p.inkSoft,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              decoration: BoxDecoration(
                color: p.paper,
                border: Border(top: BorderSide(color: p.hairline)),
              ),
              child: Row(
                children: [
                  GhostButton(
                    label: l.t('share'),
                    icon: Icons.ios_share_rounded,
                    onTap: _busy ? null : () => _run(share: true),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PrimaryButton(
                      label: l.t('save'),
                      icon: Icons.download_rounded,
                      busy: _busy,
                      onTap: () => _run(share: false),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _options(L l, Palette p) {
    final tabular =
        _f == Format.csv || _f == Format.xlsx || _f == Format.numbers;
    final rich = _f != Format.txt;
    Widget sw(String label, bool v, void Function(bool) on) => SwitchListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      value: v,
      onChanged: (x) => setState(() => on(x)),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: p.ink,
        ),
      ),
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              for (final st in PhoneStyle.values) ...[
                Expanded(
                  child: Pressable(
                    haptic: true,
                    onTap: () =>
                        setState(() => _o = _o.copyWith(phoneStyle: st)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _o.phoneStyle == st ? p.ink : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _o.phoneStyle == st ? p.ink : p.hairline,
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            switch (st) {
                              PhoneStyle.original => l.t('styleOriginal'),
                              PhoneStyle.e164 => l.t('styleE164'),
                              PhoneStyle.digits => l.t('styleDigits'),
                            },
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: _o.phoneStyle == st ? p.paper : p.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            switch (st) {
                              PhoneStyle.original => '+1 (415) 555',
                              PhoneStyle.e164 => '+1415555',
                              PhoneStyle.digits => '1415555',
                            },
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: _o.phoneStyle == st
                                  ? p.paper.withValues(alpha: 0.7)
                                  : p.inkFaint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (st != PhoneStyle.values.last) const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        sw(
          l.t('allNumbers'),
          _o.allNumbers,
          (v) => _o = _o.copyWith(allNumbers: v),
        ),
        if (tabular)
          sw(l.t('headerRow'), _o.header, (v) => _o = _o.copyWith(header: v)),
        if (_f == Format.txt)
          sw(
            l.t('withNames'),
            _o.txtWithNames,
            (v) => _o = _o.copyWith(txtWithNames: v),
          ),
        if (rich)
          sw(
            l.t('includeEmail'),
            _o.includeEmail,
            (v) => _o = _o.copyWith(includeEmail: v),
          ),
        if (rich)
          sw(
            l.t('includeOrg'),
            _o.includeOrg,
            (v) => _o = _o.copyWith(includeOrg: v),
          ),
        if (rich)
          sw(
            l.t('includeNote'),
            _o.includeNote,
            (v) => _o = _o.copyWith(includeNote: v),
          ),
      ],
    );
  }
}

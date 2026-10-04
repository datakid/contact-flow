import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/sample.dart';
import '../io/codec.dart';
import '../io/jobs.dart';
import '../l10n.dart';
import '../models/person.dart';
import '../services/device_contacts.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> showImport(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _ImportSheet(),
  );
}

class _ImportSheet extends StatefulWidget {
  const _ImportSheet();

  @override
  State<_ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends State<_ImportSheet> {
  bool _busy = false;
  bool _pasting = false;
  String? _note;
  final _paste = TextEditingController();

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  Future<void> _review(List<ImportResult> results) async {
    final s = context.read<AppState>();
    final l = L.of(context);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final total = results.fold<int>(0, (a, r) => a + r.people.length);
    if (total == 0) {
      setState(() {
        _busy = false;
        _note = l.t('nothingFound');
      });
      return;
    }
    final plan = s.plan(results);
    final root = Navigator.of(context, rootNavigator: true);
    nav.pop();
    final added = await root.push<int>(
      MaterialPageRoute(builder: (_) => ReviewScreen(plan: plan)),
    );
    if (added != null && added >= 0) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(l.t('imported', {'n': added})),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 92),
        ),
      );
    }
  }

  Future<void> _fromDevice() async {
    final l = L.of(context);
    if (!DeviceContacts.supported) {
      setState(() => _note = l.t('webDevice'));
      return;
    }
    setState(() {
      _busy = true;
      _note = null;
    });
    final access = await DeviceContacts.request();
    if (!mounted) return;
    if (access != DeviceAccess.granted) {
      setState(() {
        _busy = false;
        _note = access == DeviceAccess.blocked
            ? l.t('permBlocked')
            : l.t('permDenied');
      });
      return;
    }
    try {
      final people = await DeviceContacts.readAll();
      if (!mounted) return;
      await _review([ImportResult(people, Format.vcf, 'device')]);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _note = friendlyError(e);
        });
      }
    }
  }

  Future<void> _fromFiles() async {
    final l = L.of(context);
    setState(() {
      _busy = true;
      _note = null;
    });
    FilePickerResult? res;
    try {
      res = await FilePicker.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.any,
      );
    } catch (_) {
      res = null;
    }
    if (!mounted) return;
    if (res == null || res.files.isEmpty) {
      setState(() => _busy = false);
      return;
    }
    final results = <ImportResult>[];
    final failed = <String>[];
    for (final f in res.files) {
      final bytes = f.bytes;
      if (bytes == null) {
        failed.add(f.name);
        continue;
      }
      try {
        final name = f.name;
        results.add(await decodeInBackground(DecodeJob(name, bytes)));
      } catch (_) {
        failed.add(f.name);
      }
    }
    if (!mounted) return;
    if (failed.isNotEmpty) {
      toast(context, l.t('importFailed', {'name': failed.join(', ')}));
    }
    await _review(results);
  }

  Future<void> _fromPaste() async {
    final text = _paste.text;
    if (text.trim().isEmpty) return;
    setState(() => _busy = true);
    final bytes = Uint8List.fromList(utf8.encode(text));
    final trimmed = text.trimLeft();
    final name = trimmed.toUpperCase().startsWith('BEGIN:VCARD')
        ? 'pasted.vcf'
        : (trimmed.startsWith('[') || trimmed.startsWith('{'))
        ? 'pasted.json'
        : (text
                      .split('\n')
                      .where(
                        (x) =>
                            x.contains(',') ||
                            x.contains('\t') ||
                            x.contains(';'),
                      )
                      .length >
                  1
              ? 'pasted.csv'
              : 'pasted.txt');
    ImportResult r;
    try {
      r = Codec.decode(name, bytes);
      if (r.people.isEmpty && name != 'pasted.txt') {
        r = Codec.decode('pasted.txt', bytes);
      }
    } catch (_) {
      r = Codec.decode('pasted.txt', bytes);
    }
    await _review([r]);
  }

  Future<void> _sample() async {
    await _review([ImportResult(Sample.people(), Format.vcf, 'sample')]);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = context.pal;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            0,
            0,
            0,
            16 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.t('import'),
                        style: Type.display(p, size: 40),
                      ),
                    ),
                    if (_busy)
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: p.accent,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                child: Text(
                  l.t('privacy'),
                  style: TextStyle(
                    color: p.inkSoft,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              _Option(
                icon: Icons.smartphone_rounded,
                title: l.t('fromDevice'),
                sub: l.t('fromDeviceSub'),
                onTap: _busy ? null : _fromDevice,
                index: 0,
              ),
              _Option(
                icon: Icons.folder_open_rounded,
                title: l.t('fromFile'),
                sub: l.t('fromFileSub'),
                onTap: _busy ? null : _fromFiles,
                index: 1,
              ),
              _Option(
                icon: Icons.content_paste_rounded,
                title: l.t('paste'),
                sub: l.t('pasteSub'),
                onTap: _busy
                    ? null
                    : () => setState(() => _pasting = !_pasting),
                index: 2,
                open: _pasting,
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: _pasting
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: p.paper,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: p.hairline),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              child: TextField(
                                controller: _paste,
                                maxLines: 6,
                                minLines: 4,
                                autofocus: true,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  height: 1.5,
                                  color: p.ink,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: l.t('pasteHint'),
                                  hintStyle: TextStyle(color: p.inkFaint),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            PrimaryButton(
                              label: l.t('detect'),
                              icon: Icons.auto_awesome_rounded,
                              onTap: _fromPaste,
                              busy: _busy,
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                child: _note == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: p.accentSoft,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _note!,
                                style: TextStyle(
                                  color: p.ink,
                                  fontWeight: FontWeight.w600,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (_note == l.t('webDevice'))
                                    Pill(
                                      label: l.t('loadSample'),
                                      active: true,
                                      onTap: _sample,
                                      icon: Icons.auto_stories_rounded,
                                    ),
                                  if (_note == l.t('permBlocked'))
                                    Pill(
                                      label: l.t('openSettings'),
                                      active: true,
                                      onTap: DeviceContacts.openSettings,
                                      icon: Icons.settings_rounded,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              SectionLabel(l.t('supported')),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final f in Format.values) FormatGlyph(f, size: 46),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback? onTap;
  final int index;
  final bool open;
  const _Option({
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
    required this.index,
    this.open = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return FadeSlideIn(
      index: index,
      child: Pressable(
        onTap: onTap,
        haptic: true,
        scale: 0.985,
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: p.paper,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: open ? p.ink.withValues(alpha: 0.4) : p.hairline,
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: p.sheet,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.hairline),
                ),
                child: Icon(icon, color: p.accent, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      sub,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: p.inkSoft,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedRotation(
                turns: open ? 0.25 : 0,
                duration: const Duration(milliseconds: 240),
                child: Icon(
                  Directionality.of(context) == TextDirection.rtl
                      ? Icons.chevron_left_rounded
                      : Icons.chevron_right_rounded,
                  color: p.inkFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReviewScreen extends StatefulWidget {
  final ImportPlan plan;
  const ReviewScreen({super.key, required this.plan});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  bool _merge = true;
  bool _busy = false;
  late final Set<String> _skip = {};

  List<Person> get _fresh => widget.plan.fresh;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = context.pal;
    final plan = widget.plan;
    final count =
        _fresh.length - _skip.length + (_merge ? 0 : plan.dupes.length);
    final previewList = [
      ..._fresh,
      if (!_merge) ...plan.dupes.map((d) => d.$1),
    ];
    final isDevice = plan.sources.contains('device');
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l.t('preview'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${plan.incoming.length}',
                            style: Type.display(
                              p,
                              size: 88,
                            ).copyWith(height: 0.95),
                          ),
                          Text(
                            l.n(
                              plan.incoming.length,
                              'contacts_one',
                              'contacts_many',
                            ),
                            style: Type.display(
                              p,
                              size: 24,
                              italic: true,
                            ).copyWith(color: p.inkSoft),
                          ),
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              _Stat(
                                label: l.t('newOnes'),
                                value: _fresh.length,
                                color: p.accent,
                              ),
                              const SizedBox(width: 10),
                              _Stat(
                                label: l.t('duplicates'),
                                value: plan.dupes.length,
                                color: p.sage,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (plan.formats.isNotEmpty)
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final e in plan.formats.entries)
                                  if (!isDevice && e.value > 0)
                                    Tag('${e.key.title} · ${e.value}'),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (plan.dupes.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                        child: SwitchListTile(
                          value: _merge,
                          onChanged: (v) => setState(() => _merge = v),
                          title: Text(
                            l.t('mergeDupes'),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: p.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (previewList.isNotEmpty)
                    SliverToBoxAdapter(child: SectionLabel(l.t('newOnes')))
                  else
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              color: p.sage,
                              size: 28,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l.t('allKnown'),
                              style: Type.display(p, size: 26),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _merge
                                  ? l.t('allKnownMerge')
                                  : l.t('allKnownSub'),
                              style: TextStyle(
                                color: p.inkSoft,
                                fontSize: 14.5,
                                height: 1.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  SliverList.builder(
                    itemCount: previewList.length > 400
                        ? 400
                        : previewList.length,
                    itemBuilder: (c, i) {
                      final person = previewList[i];
                      final skip = _skip.contains(person.id);
                      return InkWell(
                        onTap: () => setState(
                          () => skip
                              ? _skip.remove(person.id)
                              : _skip.add(person.id),
                        ),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: skip ? 0.35 : 1,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 9,
                            ),
                            child: Row(
                              children: [
                                Avatar(person: person, size: 38),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        person.displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: p.ink,
                                          decoration: skip
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                      ),
                                      Directionality(
                                        textDirection: TextDirection.ltr,
                                        child: Text(
                                          person.phones
                                              .map((e) => e.number)
                                              .join('  ·  '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: p.inkSoft,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  skip
                                      ? Icons.add_circle_outline_rounded
                                      : Icons.check_circle_rounded,
                                  color: skip ? p.inkFaint : p.accent,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  if (previewList.length > 400)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          '+ ${previewList.length - 400}',
                          style: Type.display(
                            p,
                            size: 26,
                          ).copyWith(color: p.inkSoft),
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: PrimaryButton(
                label: count > 0
                    ? l.t('addN', {'n': count})
                    : (_merge && plan.dupes.isNotEmpty
                          ? l.t('updateN', {'n': plan.dupes.length})
                          : l.t('done')),
                icon: Icons.check_rounded,
                busy: _busy,
                onTap: () async {
                  setState(() => _busy = true);
                  final s = context.read<AppState>();
                  final keep = _fresh
                      .where((x) => !_skip.contains(x.id))
                      .toList();
                  final dupes = _merge
                      ? plan.dupes
                      : plan.dupes
                            .where((d) => !_skip.contains(d.$1.id))
                            .toList();
                  final n = await s.commit(
                    ImportPlan(
                      plan.incoming,
                      keep,
                      dupes,
                      plan.sources,
                      plan.formats,
                    ),
                    merge: _merge,
                  );
                  if (context.mounted) Navigator.pop(context, n);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: p.sheet,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: p.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Type.label(p),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: value.toDouble()),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (c, v, _) =>
                  Text('${v.round()}', style: Type.display(p, size: 36)),
            ),
          ],
        ),
      ),
    );
  }
}

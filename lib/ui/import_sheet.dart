import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/sample.dart';
import '../domain/sheet_template.dart';
import '../io/codec.dart';
import '../io/cancel_token.dart';
import '../io/jobs.dart';
import '../l10n.dart';
import '../models/person.dart';
import '../services/device_contacts.dart';
import '../services/file_out.dart';
import '../services/incoming_read.dart';
import '../state/app_state.dart';
import '../state/phone_book.dart';
import 'import_issues.dart';
import 'sync_screen.dart';
import 'theme.dart';
import 'widgets.dart';
import '../tags/tag_book.dart';

Future<void> saveTemplate(BuildContext context, Format f) async {
  final l = L.of(context);
  try {
    final bytes = SheetTemplate.build(f, l);
    final name = SheetTemplate.fileName(f);
    final saved = await saveBytes(bytes, name, f.mime);
    if (saved == null || !context.mounted) return;
    toast(
      context,
      l.t('saved', {'name': name}),
      action: l.t('share'),
      onAction: () => shareBytes(bytes, name, f.mime),
    );
  } catch (e) {
    if (context.mounted) toast(context, friendlyError(e));
  }
}

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
  bool _templating = false;
  bool _templateHint = false;
  String? _note;
  final _paste = TextEditingController();
  final _cancel = CancelToken();

  @override
  void dispose() {
    _cancel.cancel();
    _paste.dispose();
    super.dispose();
  }

  Future<void> _review(List<ImportResult> results) async {
    final s = context.read<AppState>();
    final l = L.of(context);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final total = results.fold<int>(0, (a, r) => a + r.people.length);
    final problems = ImportIssues.describe(l, results);
    if (total == 0) {
      setState(() {
        _busy = false;
        _note = problems.isEmpty ? l.t('nothingFound') : problems;
        _templateHint = ImportIssues.suggestsTemplate(results);
      });
      return;
    }
    final plan = s.plan(results);
    final root = Navigator.of(context, rootNavigator: true);
    nav.pop();
    if (problems.isNotEmpty) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(problems),
          duration: const Duration(seconds: 6),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 92),
        ),
      );
    }
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
      setState(() {
        _note = l.t('webDevice');
        _templateHint = false;
      });
      return;
    }
    setState(() {
      _busy = true;
      _note = null;
      _templateHint = false;
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
    setState(() {
      _busy = true;
      _note = null;
      _templateHint = false;
    });
    FilePickerResult? res;
    try {
      res = await FilePicker.pickFiles(
        allowMultiple: true,
        withData: kIsWeb,
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
    for (final f in res.files) {
      if (f.size > maxImportBytes) {
        results.add(ImportResult.problem(f.name, ImportIssue.tooLarge));
        continue;
      }
      var bytes = f.bytes;
      final path = f.path;
      if (bytes == null && path != null && !kIsWeb) {
        bytes = await readFileBytes(path);
      }
      if (bytes == null) {
        results.add(ImportResult.failed(f.name));
        continue;
      }
      results.add(
        await decodeInBackground(DecodeJob(f.name, bytes), cancel: _cancel),
      );
    }
    if (!mounted) return;
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
    var r = await decodeInBackground(DecodeJob(name, bytes), cancel: _cancel);
    if (r.people.isEmpty && name != 'pasted.txt') {
      r = await decodeInBackground(
        DecodeJob('pasted.txt', bytes),
        cancel: _cancel,
      );
    }
    if (!mounted) return;
    if (r.people.isEmpty) r = ImportResult(const [], r.format, '');
    await _review([r]);
  }

  Future<void> _sample() async {
    await _review([ImportResult(Sample.people(), Format.vcf, 'sample')]);
  }

  List<Widget> _templateButtons() => [
    for (final f in SheetTemplate.formats)
      Pill(
        label: '${f.title} (.${f.exportExt})',
        active: true,
        icon: Icons.download_rounded,
        onTap: () => saveTemplate(context, f),
      ),
  ];

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
                        style: AppText.display(p, size: 40),
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
              _Option(
                icon: Icons.download_rounded,
                title: l.t('getTemplate'),
                sub: l.t('getTemplateSub'),
                onTap: _busy
                    ? null
                    : () => setState(() => _templating = !_templating),
                index: 3,
                open: _templating,
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: _templating
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _templateButtons(),
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
                                  if (_templateHint) ..._templateButtons(),
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
  bool _labelsToTags = true;

  TagBook? get _tagBook {
    try {
      return context.read<TagBook>();
    } catch (_) {
      return null;
    }
  }

  bool get _hasLabels =>
      _fresh.any((p) => p.groups.isNotEmpty) ||
      widget.plan.dupes.any((d) => d.$1.groups.isNotEmpty);

  Future<void> _tagFromLabels(TagBook book, Iterable<Person> people) async {
    for (final p in people) {
      final numbers = [for (final e in p.phones) e.number];
      if (numbers.isEmpty) continue;
      for (final g in p.groups) {
        final tag = await book.create(g);
        await book.assign([tag.id], numbers);
      }
    }
  }

  bool _busy = false;
  late final Set<String> _skip = {};

  List<Person> get _fresh => widget.plan.fresh;

  int get _count {
    final fresh = _fresh.where((x) => !_skip.contains(x.id)).length;
    if (_merge) return fresh;
    return fresh +
        widget.plan.dupes.where((d) => !_skip.contains(d.$1.id)).length;
  }

  Future<void> _commit() async {
    if (_busy) return;
    setState(() => _busy = true);
    final plan = widget.plan;
    final s = context.read<AppState>();
    final l = L.of(context);
    final keep = _fresh.where((x) => !_skip.contains(x.id)).toList();
    final dupes = _merge
        ? plan.dupes
        : plan.dupes.where((d) => !_skip.contains(d.$1.id)).toList();
    try {
      final n = await s.commit(
        ImportPlan(plan.incoming, keep, dupes, plan.sources, plan.formats),
        merge: _merge,
      );
      final book = _tagBook;
      if (_labelsToTags && book != null) {
        try {
          await _tagFromLabels(book, [...keep, ...dupes.map((d) => d.$1)]);
        } catch (_) {}
      }
      if (mounted) Navigator.pop(context, n);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      toast(context, l.t('importFailed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = context.pal;
    final plan = widget.plan;
    final count = _count;
    final previewList = [
      ..._fresh,
      if (!_merge) ...plan.dupes.map((d) => d.$1),
    ];
    final entries = <_ReviewEntry>[
      if (_fresh.isNotEmpty) ...[
        _ReviewEntry.header(l.t('newOnes'), _fresh.length),
        for (final f in _fresh) _ReviewEntry.row(f),
      ],
      if (plan.dupes.isNotEmpty) ...[
        _ReviewEntry.header(l.t('duplicates'), plan.dupes.length),
        for (final d in plan.dupes) _ReviewEntry.row(d.$1, existing: d.$2),
      ],
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
                            style: AppText.display(
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
                            style: AppText.display(
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
                          if (plan.skipped > 0) ...[
                            const SizedBox(height: 12),
                            Text(
                              l.t('skippedRows', {'n': plan.skipped}),
                              style: TextStyle(
                                color: p.inkSoft,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
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
                  if (_tagBook != null && _hasLabels)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                        child: SwitchListTile(
                          key: const ValueKey('labels-to-tags'),
                          value: _labelsToTags,
                          onChanged: (v) => setState(() => _labelsToTags = v),
                          title: Text(
                            l.t('labelsAsTags'),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: p.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (previewList.isEmpty)
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
                              style: AppText.display(p, size: 26),
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
                    itemCount: entries.length,
                    itemBuilder: (c, i) {
                      final e = entries[i];
                      final header = e.header;
                      if (header != null) {
                        return SectionLabel('$header · ${e.count}');
                      }
                      final person = e.person!;
                      final lockedMerge = e.existing != null && _merge;
                      return _ReviewRow(
                        key: ValueKey('review-${person.id}'),
                        person: person,
                        existing: e.existing,
                        skipped: !lockedMerge && _skip.contains(person.id),
                        locked: lockedMerge,
                        onToggle: () => setState(
                          () => _skip.contains(person.id)
                              ? _skip.remove(person.id)
                              : _skip.add(person.id),
                        ),
                      );
                    },
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
            if (context.watch<PhoneBook>().granted && !isDevice)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: GhostButton(
                    key: const ValueKey('updatePhone'),
                    label: l.t('updatePhone'),
                    icon: Icons.sync_rounded,
                    onTap: () {
                      final rows = plan.incoming;
                      final nav = Navigator.of(context);
                      openSync(context, rows).then((_) {
                        if (nav.mounted && nav.canPop()) nav.pop(-1);
                      });
                    },
                  ),
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
                onTap: _commit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewEntry {
  final String? header;
  final int count;
  final Person? person;
  final Person? existing;
  const _ReviewEntry.header(String this.header, this.count)
    : person = null,
      existing = null;
  const _ReviewEntry.row(Person this.person, {this.existing})
    : header = null,
      count = 0;
}

class _ReviewRow extends StatefulWidget {
  final Person person;
  final Person? existing;
  final bool skipped;
  final bool locked;
  final VoidCallback onToggle;
  const _ReviewRow({
    super.key,
    required this.person,
    required this.existing,
    required this.skipped,
    required this.locked,
    required this.onToggle,
  });

  @override
  State<_ReviewRow> createState() => _ReviewRowState();
}

class _ReviewRowState extends State<_ReviewRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = context.pal;
    final person = widget.person;
    final skip = widget.skipped;
    final detail = person.origin.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: widget.locked ? null : widget.onToggle,
          child: AnimatedOpacity(
            duration: AppMotion.base,
            opacity: skip ? 0.35 : 1,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 24, end: 4),
              child: Row(
                children: [
                  Avatar(person: person, size: 38),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                              person.phones.map((e) => e.number).join('  ·  '),
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
                  ),
                  if (!widget.locked)
                    Icon(
                      skip
                          ? Icons.add_circle_outline_rounded
                          : Icons.check_circle_rounded,
                      color: skip ? p.inkFaint : p.accent,
                      size: 22,
                    )
                  else
                    Icon(Icons.merge_rounded, color: p.sageText, size: 22),
                  IconButton(
                    key: ValueKey('review-expand-${person.id}'),
                    tooltip: _open ? l.t('detailsHide') : l.t('detailsShow'),
                    onPressed: () => setState(() => _open = !_open),
                    icon: Icon(
                      _open
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: p.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: AppMotion.base,
          curve: AppMotion.curve,
          alignment: AlignmentDirectional.topStart,
          child: !_open
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(76, 0, 24, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.existing != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            l.t('mergesInto', {
                              'name': widget.existing!.displayName,
                            }),
                            style: TextStyle(
                              color: p.sageText,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (detail.isNotEmpty) ...[
                        Text(
                          l.t('originalLine'),
                          style: AppText.label(p).copyWith(color: p.inkSoft),
                        ),
                        const SizedBox(height: 4),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Container(
                            key: ValueKey('review-origin-${person.id}'),
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: p.sheet,
                              borderRadius: BorderRadius.circular(
                                AppRadius.sm,
                              ),
                              border: Border.all(color: p.hairline),
                            ),
                            child: SelectableText(
                              detail,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                height: 1.4,
                                color: p.ink,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ],
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
                    style: AppText.label(p),
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
                  Text('${v.round()}', style: AppText.display(p, size: 36)),
            ),
          ],
        ),
      ),
    );
  }
}

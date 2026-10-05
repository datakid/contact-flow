import 'package:flutter/material.dart' hide StepState;
import 'package:provider/provider.dart';

import '../domain/queue.dart';
import '../l10n.dart';
import '../state/queue_state.dart';
import 'reach_ui.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> openQueue(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute(builder: (_) => const QueueScreen()));

class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

  Future<void> _open(BuildContext context) async {
    final l = L.of(context);
    final q = context.read<QueueState>();
    var r = await q.openCurrent();
    if (r == OpenResult.needsCountry && context.mounted) {
      final c = await askCountry(context, force: true);
      if (c == null || !context.mounted) return;
      await q.retarget(c);
      r = await q.openCurrent();
    }
    if (!context.mounted) return;
    if (r == OpenResult.invalid) toast(context, l.t('badNumber'));
    if (r == OpenResult.failed) toast(context, l.t('cantOpen'));
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final p = context.pal;
    final state = context.watch<QueueState>();
    final q = state.queue;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          q == null ? l.t('queue') : channelLabel(l, q.channel),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: q == null ? _empty(l, p) : _body(context, q, l, p),
      ),
    );
  }

  Widget _empty(L l, Palette p) => Padding(
    padding: const EdgeInsets.all(24),
    child: Text(l.t('queueEmpty'), style: Type.display(p, size: 28)),
  );

  Widget _body(BuildContext context, MessageQueue q, L l, Palette p) {
    final state = context.read<QueueState>();
    final cur = q.current;
    final done = q.finished;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
                child: Text(
                  l.t('progressOf', {'done': q.handled, 'total': q.total}),
                  key: const ValueKey('queueProgress'),
                  style: Type.display(p, size: 34),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: q.progress,
                    minHeight: 8,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Text(
                  l.t('queueStats', {'sent': q.sent, 'skipped': q.skipped}),
                  style: TextStyle(color: p.inkSoft),
                ),
              ),
              if (done)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                  child: Text(
                    q.stopped ? l.t('queueStopped') : l.t('queueDone'),
                    style: Type.display(p, size: 28),
                  ),
                )
              else if (cur != null)
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: p.sheet,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: p.hairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l.t('nextUp').toUpperCase(), style: Type.label(p)),
                      const SizedBox(height: 6),
                      Text(
                        cur.name,
                        key: const ValueKey('queueCurrent'),
                        style: Type.display(p, size: 28),
                      ),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          cur.number,
                          textAlign: l.rtl ? TextAlign.right : TextAlign.left,
                          style: TextStyle(
                            color: p.inkSoft,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (cur.text.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          cur.text,
                          style: TextStyle(color: p.ink, height: 1.4),
                        ),
                      ],
                      if (q.awaitingReturn) ...[
                        const SizedBox(height: 12),
                        Text(
                          l.t('didYouSend'),
                          style: TextStyle(
                            color: p.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              if (q.withoutNumber.isNotEmpty) ...[
                SectionLabel(
                  l.n(q.withoutNumber.length, 'noNumberOne', 'noNumberN'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    q.withoutNumber.join(', '),
                    style: TextStyle(color: p.inkSoft, fontSize: 13),
                  ),
                ),
              ],
              SectionLabel(l.t('everyone')),
              for (final s in q.steps)
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  leading: Icon(
                    switch (s.state) {
                      StepState.sent => Icons.check_circle_rounded,
                      StepState.skipped => Icons.remove_circle_outline_rounded,
                      StepState.opened => Icons.open_in_new_rounded,
                      StepState.pending => Icons.radio_button_unchecked_rounded,
                    },
                    color: s.state == StepState.sent ? p.sage : p.inkFaint,
                    size: 20,
                  ),
                  title: Text(
                    s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: done
              ? PrimaryButton(
                  label: l.t('done'),
                  icon: Icons.check_rounded,
                  onTap: () {
                    state.dismiss();
                    Navigator.of(context).maybePop();
                  },
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PrimaryButton(
                      key: const ValueKey('queueOpen'),
                      label: q.awaitingReturn
                          ? l.t('sentNext')
                          : l.t('openFor', {'name': cur?.name ?? ''}),
                      icon: q.awaitingReturn
                          ? Icons.check_rounded
                          : Icons.open_in_new_rounded,
                      onTap: q.awaitingReturn
                          ? state.markSent
                          : () => _open(context),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: GhostButton(
                            key: const ValueKey('queueSkip'),
                            label: l.t('skip'),
                            icon: Icons.skip_next_rounded,
                            onTap: state.skip,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GhostButton(
                            key: const ValueKey('queueStop'),
                            label: l.t('stop'),
                            icon: Icons.stop_rounded,
                            onTap: state.stop,
                          ),
                        ),
                      ],
                    ),
                    if (q.awaitingReturn)
                      TextButton(
                        onPressed: () => _open(context),
                        child: Text(l.t('openAgain')),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

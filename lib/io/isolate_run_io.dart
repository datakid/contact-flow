import 'dart:async';
import 'dart:isolate';

import 'cancel_token.dart';

class _Request<A, R> {
  final R Function(A) fn;
  final A arg;
  final SendPort reply;
  const _Request(this.fn, this.arg, this.reply);
}

void _entry<A, R>(_Request<A, R> r) {
  try {
    r.reply.send([true, r.fn(r.arg)]);
  } catch (e) {
    r.reply.send([false, '$e']);
  }
}

Future<R> runIsolated<A, R>(
  R Function(A) fn,
  A arg, {
  Duration timeout = const Duration(seconds: 20),
  CancelToken? token,
}) async {
  if (token != null && token.cancelled) throw const CancelledException();
  final port = ReceivePort();
  final done = Completer<R>();
  done.future.ignore();
  Isolate? isolate;
  late final Timer timer;

  void finish(void Function() how) {
    if (done.isCompleted) return;
    how();
    timer.cancel();
    port.close();
    isolate?.kill(priority: Isolate.immediate);
  }

  timer = Timer(
    timeout,
    () => finish(
      () => done.completeError(TimeoutException('Decode timed out', timeout)),
    ),
  );
  token?.onCancel(
    () => finish(() => done.completeError(const CancelledException())),
  );
  port.listen((m) {
    finish(() {
      if (m is List && m.isNotEmpty && m[0] == true) {
        done.complete(m[1] as R);
      } else if (m is List && m.length > 1) {
        done.completeError(StateError('${m[1]}'));
      } else {
        done.completeError(StateError('The worker stopped unexpectedly'));
      }
    });
  });
  try {
    isolate = await Isolate.spawn<_Request<A, R>>(
      _entry<A, R>,
      _Request<A, R>(fn, arg, port.sendPort),
      onExit: port.sendPort,
      errorsAreFatal: true,
    );
    if (done.isCompleted) isolate.kill(priority: Isolate.immediate);
  } catch (e) {
    finish(() => done.completeError(e));
  }
  return done.future;
}

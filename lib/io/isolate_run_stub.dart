import 'cancel_token.dart';

Future<R> runIsolated<A, R>(
  R Function(A) fn,
  A arg, {
  Duration timeout = const Duration(seconds: 20),
  CancelToken? token,
}) async {
  if (token != null && token.cancelled) throw const CancelledException();
  final r = fn(arg);
  if (token != null && token.cancelled) throw const CancelledException();
  return r;
}

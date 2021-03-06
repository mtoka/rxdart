import 'dart:async';

import 'package:rxdart/src/streams/utils.dart';
import 'package:rxdart/src/utils/error_and_stacktrace.dart';

/// Creates a [Stream] that will recreate and re-listen to the source
/// [Stream] the specified number of times until the [Stream] terminates
/// successfully.
///
/// If the retry count is not specified, it retries indefinitely. If the retry
/// count is met, but the Stream has not terminated successfully, a
/// [RetryError] will be thrown. The RetryError will contain all of the Errors
/// and StackTraces that caused the failure.
///
/// ### Example
///
///     RetryStream(() => Stream.value(1))
///         .listen((i) => print(i)); // Prints 1
///
///     RetryStream(
///       () => Stream.value(1).concatWith([Stream.error(Error())]),
///       1,
///     ).listen(print, onError: (e, s) => print(e)); // Prints 1, 1, RetryError
class RetryStream<T> extends Stream<T> {
  /// The factory method used at subscription time
  final Stream<T> Function() streamFactory;

  /// The amount of retry attempts that will be made
  /// If null, then an indefinite amount of attempts will be made.
  final int? count;
  int _retryStep = 0;
  StreamController<T>? _controller;
  late StreamSubscription<T> _subscription;
  final _errors = <ErrorAndStackTrace>[];

  /// Constructs a [Stream] that will recreate and re-listen to the source
  /// [Stream] (created by the provided factory method) the specified number
  /// of times until the [Stream] terminates successfully.
  /// If [count] is not specified, it retries indefinitely.
  RetryStream(this.streamFactory, [this.count]);

  @override
  StreamSubscription<T> listen(void Function(T event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    _controller ??= StreamController<T>(
        sync: true,
        onListen: _retry,
        onPause: () => _subscription.pause(),
        onResume: () => _subscription.resume(),
        onCancel: () => _subscription.cancel());

    return _controller!.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  void _retry() {
    final controller = _controller!;

    _subscription = streamFactory().listen(
      controller.add,
      onError: (Object e, StackTrace s) {
        _subscription.cancel();

        _errors.add(ErrorAndStackTrace(e, s));

        if (count == _retryStep) {
          controller
            ..addError(RetryError.withCount(count!, _errors))
            ..close();
        } else {
          ++_retryStep;
          _retry();
        }
      },
      onDone: controller.close,
      cancelOnError: false,
    );
  }
}

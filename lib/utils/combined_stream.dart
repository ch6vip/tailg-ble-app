import 'dart:async';

/// Creates a broadcast stream that emits a list of the latest values from
/// each source stream whenever any of them fires.
///
/// The first emission (via [scheduleMicrotask]) delivers [initialValues] so
/// consumers always see a snapshot on the first build frame, matching the
/// hand-rolled pattern previously duplicated across 5 widget classes.
Stream<List<dynamic>> combineLatestStreams(
  List<Stream<dynamic>> streams,
  List<dynamic> initialValues,
) {
  final controller = StreamController<List<dynamic>>.broadcast();
  final latest = List<dynamic>.from(initialValues);

  void emit() => controller.add(List<dynamic>.from(latest));
  scheduleMicrotask(emit);

  final subscriptions = <StreamSubscription>[];
  for (var i = 0; i < streams.length; i++) {
    subscriptions.add(
      streams[i].listen((value) {
        latest[i] = value;
        emit();
      }),
    );
  }

  controller.onCancel = () async {
    for (final sub in subscriptions) {
      await sub.cancel();
    }
  };

  return controller.stream;
}

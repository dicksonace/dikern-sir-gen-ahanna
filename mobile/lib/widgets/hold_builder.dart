import 'package:flutter/material.dart';

class HoldBuilder<T> extends StatefulWidget {
  final Future<T> future;
  final Widget loading;
  final Widget Function(Object error) error;
  final Widget Function(BuildContext context, T data) builder;

  const HoldBuilder({
    super.key,
    required this.future,
    required this.loading,
    required this.error,
    required this.builder,
  });

  @override
  State<HoldBuilder<T>> createState() => _HoldBuilderState<T>();
}

class _HoldBuilderState<T> extends State<HoldBuilder<T>> {
  T? last;
  Object? failure;
  Future<T>? seen;

  @override
  void initState() {
    super.initState();
    _listen(widget.future);
  }

  @override
  void didUpdateWidget(HoldBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.future != oldWidget.future) _listen(widget.future);
  }

  void _listen(Future<T> future) {
    seen = future;
    future.then((value) {
      if (!mounted || seen != future) return;
      setState(() {
        last = value;
        failure = null;
      });
    }).catchError((Object error) {
      if (!mounted || seen != future || last != null) return;
      setState(() => failure = error);
    });
  }

  @override
  Widget build(BuildContext context) {
    final value = last;
    if (value == null) {
      if (failure != null) return widget.error(failure!);
      return widget.loading;
    }
    return widget.builder(context, value);
  }
}

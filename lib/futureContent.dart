import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

abstract class _GenericFutureContent<T> extends StatefulWidget {
  final Future<T> _future;
  final bool _sliver;

  const _GenericFutureContent(
      {Key key, @required Future<T> future, @required bool sliver})
      : _future = future,
        _sliver = sliver,
        super(key: key);

  @override
  State<StatefulWidget> createState() => _GenericFutureContentState();

  Widget builder(BuildContext context, T data);
}

class _GenericFutureContentState<T> extends State<_GenericFutureContent<T>> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: widget._future,
      builder: (context, snapshot) {
        Widget child;
        if (snapshot.hasData) {
          return widget.builder(context, snapshot.data);
        } else if (snapshot.hasError) {
          child = Align(
            alignment: Alignment.center,
            child: Text(snapshot.error.toString()),
          );
        } else {
          child = Align(
            alignment: Alignment.center,
            child: CircularProgressIndicator(),
          );
        }

        if (widget._sliver) {
          return SliverFillRemaining(child: child);
        } else {
          return Expanded(child : child);
        }
      },
    );
  }
}

abstract class SliverFutureContent<T> extends _GenericFutureContent<T> {
  const SliverFutureContent({Key key, @required Future<T> future})
      : super(key: key, future: future, sliver: true);
}

abstract class FutureContent<T> extends _GenericFutureContent<T> {
  const FutureContent({Key key, @required Future<T> future})
      : super(key: key, future: future, sliver: false);
}

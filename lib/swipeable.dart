import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'util.dart';

enum SwipeEvent {
  select,
  addToQueue,
  playNext,
  playNow,
  delete,
  goToArtist,
  goToAlbum
}

class Swipeable extends StatefulWidget {
  final Widget Function(BuildContext context) _buildContent;
  final Widget Function(BuildContext context) _buildPopupContent;

  final double Function() _width, _height;
  final Color _foregroundColor, _backgroundColor;
  final double _opacity;

  final Map<SwipeEvent, void Function()> _callbacks;

  Swipeable(
      {Key key,
      @required Widget Function(BuildContext context) buildContent,
      @required double Function() width,
      @required double Function() height,
      Color foregroundColor,
      Color backgroundColor,
      double opacity = 1.0,
      Widget Function(BuildContext context) buildPopupContent,
      Map<SwipeEvent, void Function()> callbacks})
      : _buildContent = buildContent,
        _buildPopupContent = buildPopupContent,
        _width = width,
        _height = height,
        _foregroundColor = foregroundColor,
        _backgroundColor = backgroundColor,
        _opacity = opacity,
        _callbacks = callbacks ?? Map();

  bool hasCallback(SwipeEvent event) => _callbacks.containsKey(event);

  void invokeCallback(SwipeEvent event) => _callbacks[event]?.call();

  @override
  _SwipeableState createState() => _SwipeableState();
}

class _SwipeableState extends State<Swipeable> with TickerProviderStateMixin {
  double position, startPosition;

  bool isResetAnimating, isDeleteAnimating;
  AnimationController resetController, deleteController;
  Animation<Offset> resetAnimation;
  Animation<double> deleteAnimation;

  double get width => widget._width();

  double get height => widget._height();

  bool get queueSlide =>
      (widget.hasCallback(SwipeEvent.addToQueue)) &&
      position > 72.0 &&
      !playNowSlide;

  bool get playNowSlide =>
      (widget.hasCallback(SwipeEvent.playNow)) && position > 180.0;

  bool get deleteSlide =>
      (widget.hasCallback(SwipeEvent.delete)) && position < -180.0;

  @override
  void initState() {
    super.initState();

    position = 0;
    startPosition = 0;

    isResetAnimating = false;
    isDeleteAnimating = false;

    resetController =
        AnimationController(duration: Duration(milliseconds: 300), vsync: this)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed ||
                status == AnimationStatus.dismissed) {
              setState(() {
                isResetAnimating = false;
                if (!isDeleteAnimating) {
                  position = 0;
                }
              });
            }
          });
    deleteController =
        AnimationController(duration: Duration(milliseconds: 200), vsync: this)
          ..addStatusListener((status) {
            if (status == AnimationStatus.dismissed) {
              setState(() {
                isDeleteAnimating = false;
                position = 0;
              });
            }
          });
  }

  @override
  void dispose() {
    resetController.dispose();
    deleteController.dispose();
    super.dispose();
  }

  double clampPosition(double pos) {
    if (((widget.hasCallback(SwipeEvent.addToQueue)) ||
            (widget.hasCallback(SwipeEvent.playNow))) &&
        pos > 0) {
      return pos;
    } else if ((widget.hasCallback(SwipeEvent.delete)) && pos < 0) {
      return pos;
    } else {
      return pos / 8;
    }
  }

  List<Triple<String, IconData, void Function()>> getOptions(context) {
    var list = <Triple<String, IconData, void Function()>>[];

    if (widget.hasCallback(SwipeEvent.addToQueue)) {
      list.add(Triple("Add to queue", Icons.queue_music, () {
        Navigator.pop(context);
        widget.invokeCallback(SwipeEvent.addToQueue);
      }));
    }
    if (widget.hasCallback(SwipeEvent.playNext)) {
      list.add(Triple("Play next", Icons.queue_music, () {
        Navigator.pop(context);
        widget.invokeCallback(SwipeEvent.playNext);
      }));
    }
    if (widget.hasCallback(SwipeEvent.playNow)) {
      list.add(Triple("Play from here", Icons.play_circle_outline, () {
        Navigator.pop(context);
        widget.invokeCallback(SwipeEvent.playNow);
      }));
    }
    if (widget.hasCallback(SwipeEvent.delete)) {
      list.add(Triple("Remove", Icons.delete_outline, () {
        Navigator.pop(context);
        widget.invokeCallback(SwipeEvent.delete);
      }));
    }
    if (widget.hasCallback(SwipeEvent.goToArtist)) {
      list.add(Triple("Go to artist", Icons.library_music, () {
        Navigator.pop(context);
        widget.invokeCallback(SwipeEvent.goToArtist);
      }));
    }
    if (widget.hasCallback(SwipeEvent.goToAlbum)) {
      list.add(Triple("Go to album", Icons.album, () {
        Navigator.pop(context);
        widget.invokeCallback(SwipeEvent.goToAlbum);
      }));
    }
    if (widget.hasCallback(SwipeEvent.select)) {
      list.add(Triple("View details", Icons.info_outline, () {
        Navigator.pop(context);
        widget.invokeCallback(SwipeEvent.select);
      }));
    }

    return list;
  }

  void showOptions(context) {
    if (widget._buildPopupContent == null) {
      return;
    }

    // hide keyboard in search screen
    FocusScope.of(context).unfocus();

    showModalBottomSheet(
        context: context,
        builder: (context) => Wrap(
              children: <Widget>[
                widget._buildPopupContent(context),
                Divider(height: 0.0),
                Column(
                  children: getOptions(context)
                      .map((item) => ListTile(
                            title: Text(item.left),
                            leading: Icon(item.middle),
                            onTap: item.right,
                          ))
                      .toList(growable: false),
                ),
              ],
            ));
  }

  void handleDragEnd() {
    if (queueSlide) {
      widget.invokeCallback(SwipeEvent.addToQueue);
    } else if (playNowSlide) {
      widget.invokeCallback(SwipeEvent.playNow);
    }

    isDeleteAnimating = deleteSlide;

    // Start reset animation
    setState(() {
      isResetAnimating = true;

      var fromPosition = position.abs() / width;
      var anim = isDeleteAnimating
          ? resetController.forward(from: fromPosition)
          : resetController.reverse(from: fromPosition);

      anim.whenCompleteOrCancel(() {
        if (isDeleteAnimating) {
          widget.invokeCallback(SwipeEvent.delete);
        }
        setState(() {
          isResetAnimating = false;

          if (isDeleteAnimating) {
            position = -width;
            deleteController
                .reverse(from: 1.0)
                .whenCompleteOrCancel(() => setState(() {
                      isDeleteAnimating = false;
                      deleteAnimation = null;
                      position = 0;
                    }));
            deleteAnimation = Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: deleteController,
              curve: Curves.linear,
            ));
          } else {
            position = 0;
          }
        });
      });
      resetAnimation = Tween<Offset>(
        begin: Offset.zero,
        end: Offset(position < 0 ? -1.0 : 1.0, 0.0),
      ).animate(CurvedAnimation(
        parent: resetController,
        // we have to use a linear curve so that we can start at the right place
        curve: Curves.linear,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget foreground = Material(
      color: _withOpacity(
          widget._foregroundColor ?? Theme.of(context).backgroundColor),
      child: InkWell(
        onTap: () {
          FocusScope.of(context).unfocus();
          widget.invokeCallback(SwipeEvent.select);
        }, // this allows the splash to appear?
        child: SizedBox(
          width: width,
          height: height,
          child: widget._buildContent(context),
        ),
      ),
    );

    Widget backgroundContentsPositive = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: (widget.hasCallback(SwipeEvent.addToQueue)) ||
              (widget.hasCallback(SwipeEvent.playNow))
          ? <Widget>[
              Container(
                width: 36.0,
                height: 36.0,
                alignment: Alignment.center,
                child: Icon(
                  playNowSlide || !(widget.hasCallback(SwipeEvent.addToQueue))
                      ? Icons.play_circle_outline
                      : Icons.queue_music,
                  size: queueSlide || playNowSlide ? 28.0 : 24.0,
                  color: playNowSlide
                      ? Colors.white
                      : queueSlide
                          ? Theme.of(context).accentColor
                          : IconTheme.of(context).color,
                ),
              ),
            ]
          : <Widget>[],
    );

    Widget backgroundContentsNegative = Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: (widget.hasCallback(SwipeEvent.delete)) &&
                !(isDeleteAnimating && !isResetAnimating)
            ? <Widget>[
                Container(
                  width: 36.0,
                  height: 36.0,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.delete_outline,
                    size: deleteSlide ? 28.0 : 24.0,
                    color: deleteSlide
                        ? Colors.white
                        : IconTheme.of(context).color,
                  ),
                )
              ]
            : <Widget>[]);

    Color defaultBackgroundColor = Theme.of(context).cardColor;

    Widget background = Material(
        color: _withOpacity(position > 0
            ? (playNowSlide
                ? Theme.of(context).primaryColor
                : defaultBackgroundColor)
            : (deleteSlide
                ? Colors.red
                : (widget._backgroundColor ?? defaultBackgroundColor))),
        child: Container(
            width: width,
            height: height,
            child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: position >= 0
                    ? backgroundContentsPositive
                    : backgroundContentsNegative)));

    Widget stack = Stack(children: <Widget>[
      background,
      isResetAnimating
          ? SlideTransition(
              position: resetAnimation,
              child: foreground,
            )
          : FractionalTranslation(
              child: foreground,
              translation: Offset(position / width, 0),
            )
    ]);

    return GestureDetector(
      child: (deleteAnimation != null)
          ? SizeTransition(
              sizeFactor: deleteAnimation,
              axis: Axis.vertical,
              child: SizedBox(width: width, height: height, child: stack))
          : stack,
      onTap: () {
        FocusScope.of(context).unfocus();
        widget.invokeCallback(SwipeEvent.select);
      },
      onLongPress:
          widget._buildPopupContent != null ? () => showOptions(context) : null,
      onHorizontalDragStart: (details) =>
          setState(() => startPosition = details.globalPosition.dx),
      onHorizontalDragUpdate: (details) => setState(() =>
          position = clampPosition(details.globalPosition.dx - startPosition)),
      onHorizontalDragEnd: (details) => handleDragEnd(),
    );
  }

  Color _withOpacity(Color color) =>
      widget._opacity == 1.0 ? color : color.withOpacity(widget._opacity);
}

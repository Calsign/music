import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:provider/provider.dart';

import 'model.dart';
import 'mainAppBar.dart';
import 'coverArt.dart';

class QueueOverlay extends ModalRoute<void> {
  @override
  Color get barrierColor => Color(0xFF222222);

  @override
  bool get barrierDismissible => false;

  @override
  String get barrierLabel => null;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    Animation<double> curve = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOut,
    );

    return FadeTransition(
      opacity: curve,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: mainAppBar(context, elevated: false),
        body: SlideTransition(
          position: Tween(
            begin: Offset(0.0, 1.0),
            end: Offset.zero,
          ).animate(curve),
          child: QueueScreen(),
        ),
      ),
    );
  }

  @override
  bool get maintainState => true;

  @override
  bool get opaque => true;

  @override
  Duration get transitionDuration => Duration(milliseconds: 300);
}

class QueueScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<QueueModel>(
      builder: (context, model, child) => SizedBox(
        width: MediaQuery.of(context).size.width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: 100.0,
                minHeight: 100.0,
                maxWidth: MediaQuery.of(context).size.width,
                maxHeight: MediaQuery.of(context).size.width,
              ),
              child: Padding(
                padding: EdgeInsets.all(36.0),
                child: coverArt(
                    mainArt: model.currentTrack.coverArtData,
                    size: MediaQuery.of(context).size.width),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                model.currentTrack.title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22.0,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                model.currentTrack.artists
                    .map((artist) => artist.value)
                    .join(", "),
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18.0,
                ),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

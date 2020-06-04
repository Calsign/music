import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:music/swipeable.dart';
import 'package:music/util.dart';

import 'package:provider/provider.dart';

import 'support.dart';
import 'model.dart';
import 'listEntry.dart';
import 'mainAppBar.dart';
import 'coverArt.dart';

class QueueOverlay extends PageRoute<void> {
  final Color _barrierColor;

  QueueOverlay({@required Color barrierColor}) : _barrierColor = barrierColor;

  @override
  Color get barrierColor => _barrierColor;

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
        resizeToAvoidBottomInset: false,
        appBar: mainAppBar(
          context,
          elevated: false,
          backgroundColor: Theme.of(context).cardColor,
        ),
        body: SlideTransition(
          position: Tween(
            begin: Offset(0.0, 1.0),
            end: Offset.zero,
          ).animate(curve),
          child: NowPlayingQueuePager(),
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

class NowPlayingQueuePager extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _NowPlayingQueuePagerState();
  }
}

class _NowPlayingQueuePagerState extends State<NowPlayingQueuePager> {
  PageController _controller;

  _NowPlayingQueuePagerState() {
    _controller = PageController(
      initialPage: 0,
      keepPage: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: NoGlowScrollBehavior(),
      child: PageView(
        scrollDirection: Axis.vertical,
        controller: _controller,
        physics: ClampingScrollPhysics(),
        pageSnapping: true,
        dragStartBehavior: DragStartBehavior.start,
        children: <Widget>[
          NowPlayingScreen(),
          QueueScreen(
            goToNowPlaying: () => _controller.animateToPage(0,
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOutExpo),
          ),
        ],
      ),
    );
  }
}

class NowPlayingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<QueueModel>(
      builder: (context, model, child) => SizedBox(
        width: MediaQuery.of(context).size.width,
        child: Material(
          color: Theme.of(context).cardColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
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
                  child: Hero(
                    tag: "nowPlaying/coverArt",
                    child: coverArt(
                        mainArt: model.currentTrack.coverArtData,
                        size: MediaQuery.of(context).size.width),
                  ),
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
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Consumer<PlaybackProgressModel>(
                  builder: (context, progressModel, child) => Column(
                    children: <Widget>[
                      Slider(
                        value: progressModel.playbackFraction,
                        onChanged: (value) => null,
                        onChangeEnd: (value) => progressModel.skipTo(
                            (value * progressModel.totalDuration).round()),
                      ),
                      Row(
                        children: <Widget>[
                          SizedBox(width: 30.0),
                          Text(
                            millisToTimeString(progressModel.position),
                            style: TextStyle(
                              fontSize: 14.0,
                              color: Colors.white70,
                            ),
                          ),
                          Spacer(),
                          Text(
                            millisToTimeString(progressModel.totalDuration),
                            style: TextStyle(
                              fontSize: 14.0,
                              color: Colors.white70,
                            ),
                          ),
                          SizedBox(width: 30.0),
                        ],
                      )
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  IconButton(
                    icon: Icon(Icons.repeat),
                    iconSize: 24.0,
                    color: Colors.white70,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32.0, vertical: 6.0),
                    onPressed: () => null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_previous),
                    iconSize: 36.0,
                    padding: const EdgeInsets.all(8.0),
                    onPressed: () => model
                        .skipPrev(Provider.of<PlaybackProgressModel>(context)),
                  ),
                  Padding(
                    padding: EdgeInsets.all(12.0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                      ),
                      child: IconButton(
                        icon: Icon(
                            model.isPlaying ? Icons.pause : Icons.play_arrow),
                        iconSize: 56.0,
                        color: Theme.of(context).accentColor,
                        padding: const EdgeInsets.all(12.0),
                        onPressed: () => model.togglePlaying(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    iconSize: 36.0,
                    padding: const EdgeInsets.all(8.0),
                    onPressed: () => model.skipNext(),
                  ),
                  IconButton(
                    icon: Icon(Icons.more_vert),
                    iconSize: 24.0,
                    color: Colors.white70,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32.0, vertical: 6.0),
                    onPressed: () => null,
                  ),
                ],
              ),
              SizedBox(height: 30.0),
            ],
          ),
        ),
      ),
    );
  }
}

class QueueScreen extends StatelessWidget {
  final void Function() _goToNowPlaying;

  const QueueScreen({@required void Function() goToNowPlaying})
      : _goToNowPlaying = goToNowPlaying;

  @override
  Widget build(BuildContext context) {
    return Consumer<QueueModel>(
      builder: (context, model, child) => Column(
        children: <Widget>[
          Material(
            elevation: 16.0,
            child: InkWell(
              child: nowPlayingContents(context, model),
              onTap: _goToNowPlaying,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: model.queuedTracks.length,
              itemBuilder: (context, index) => ListEntry(
                ListEntryData.ofQueuedTrackInfo(model.queuedTracks[index]),
                foregroundColor: Theme.of(context).cardColor,
                backgroundColor: Color(0xFF111111),
                showNowPlaying: index == model.currentlyPlayingIndex,
                callbacks: {
                  SwipeEvent.addToQueue: () =>
                      model.addToQueue(model.queuedTracks[index]),
                  SwipeEvent.playNext: () =>
                      model.playNext(model.queuedTracks[index]),
                  SwipeEvent.playNow: () => model.skipTo(index),
                  SwipeEvent.delete: () => model.removeFromQueue(index),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget nowPlayingContents(BuildContext context, QueueModel model,
    {String heroTag}) {
  return Column(
    children: <Widget>[
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: ListEntryContents(
          ListEntryData.ofQueuedTrackInfo(model.currentTrack),
          showNowPlaying: false,
          heroTag: heroTag,
          secondData: ListEntrySecondData.releaseGroup,
          right: Row(
            children: <Widget>[
              IconButton(
                icon: Icon(model.isPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: () => model.togglePlaying(),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next),
                onPressed: () => model.skipNext(),
              ),
            ],
          ),
        ),
      ),
      SizedBox(
        height: 2.0,
        child: Consumer<PlaybackProgressModel>(
          builder: (context, progressModel, child) => LinearProgressIndicator(
            value: progressModel.playbackFraction,
            backgroundColor: Theme.of(context).cardColor,
          ),
        ),
      ),
    ],
  );
}

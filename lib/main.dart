import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:provider/provider.dart';

import 'support.dart';
import 'data.dart';
import 'model.dart';
import 'mainAppBar.dart';
import 'releaseGroupView.dart';
import 'queueScreen.dart';

void main() => runApp(MusicApp());

class MusicApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => DownloadedOnlyModel()),
        ChangeNotifierProvider(create: (context) => MainPageIndexModel()),
        ChangeNotifierProvider(create: (context) => QueueModel()),
        ChangeNotifierProvider(create: (context) => PlaybackProgressModel()),
        ChangeNotifierProvider(create: (context) => PlaybackDeviceModel()),
      ],
      child: MaterialApp(
        title: 'Music',
        theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: Colors.blue[900],
          accentColor: Colors.blue[700],
          backgroundColor: Colors.black,
          cardColor: Color(0xFF222222),
        ),
        home: MainPage(),
      ),
    );
  }
}

const double NOW_PLAYING_HEIGHT = 90.0;

class MainPage extends StatelessWidget {
  final Mbid _content;

  MainPage({Key key, Mbid content})
      : _content = content,
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getContent(context),
      backgroundColor: Theme.of(context).backgroundColor,
      resizeToAvoidBottomInset: false,
      bottomNavigationBar: Material(
        elevation: 16.0,
        child: Consumer<MainPageIndexModel>(
          builder: (context, model, child) => BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Theme.of(context).cardColor,
            onTap: (index) {
              model.mainPageIndex = index;
              Navigator.popUntil(
                  context, ModalRoute.withName(Navigator.defaultRouteName));
            },
            currentIndex: model.mainPageIndex,
            items: const <BottomNavigationBarItem>[
              const BottomNavigationBarItem(
                icon: const Icon(Icons.explore),
                title: const Text("Explore"),
              ),
              const BottomNavigationBarItem(
                icon: const Icon(Icons.history),
                title: const Text("Recent"),
              ),
              const BottomNavigationBarItem(
                icon: const Icon(Icons.library_music),
                title: const Text("Library"),
              ),
              const BottomNavigationBarItem(
                icon: const Icon(Icons.insert_chart),
                title: const Text("Stats"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getContent(BuildContext context) {
    if (_content != null) {
      switch (_content.mbidType) {
        case MbidType.artist:
          return null;
        case MbidType.releaseGroup:
          return _buildContent(
            context,
            ReleaseGroupView.musicbrainz(
              key: Key("album/${_content.mbid}"),
              mbid: _content.mbid,
            ),
          );
        case MbidType.release:
          return null;
        case MbidType.recording:
          return null;
      }
    }

    return Consumer<MainPageIndexModel>(builder: (context, model, child) {
      switch (model.mainPageIndex) {
        case 0:
          return _buildContent(
              context, SliverFillRemaining(child: Placeholder()));
        case 1:
          return _buildContent(
              context, SliverFillRemaining(child: Placeholder()));
        case 2:
          return _buildContent(
              context, SliverFillRemaining(child: Placeholder()));
        case 3:
          return _buildContent(
              context, SliverFillRemaining(child: Placeholder()));
        default:
          return null;
      }
    });
  }

  Widget _buildContent(BuildContext context, Widget content, {Widget title}) {
    return Stack(
      children: <Widget>[
        ScrollConfiguration(
          behavior: NoGlowScrollBehavior(),
          child: CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: <Widget>[
              sliverAppBar(context, title: title),
              content,
              SliverToBoxAdapter(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: NOW_PLAYING_HEIGHT,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 0.0,
          child: _nowPlaying(context),
        ),
      ],
    );
  }

  Widget _nowPlaying(BuildContext context) {
    return Consumer<QueueModel>(
        builder: (context, model, child) => model.hasQueue
            ? Container(
                width: MediaQuery.of(context).size.width,
                height: NOW_PLAYING_HEIGHT,
                padding: EdgeInsets.all(12.0),
                child: Material(
                  elevation: 24.0,
                  color: Theme.of(context).cardColor,
                  child: InkWell(
                    child: nowPlayingContents(context, model, heroTag: "nowPlaying/coverArt"),
                    onTap: () => Navigator.of(context).push(QueueOverlay(
                        barrierColor: Theme.of(context).cardColor)),
                  ),
                ),
              )
            : SizedBox(width: 0.0, height: 0.0));
  }
}

class MainOverlay extends PageRoute<void> {
  Mbid _content;

  MainOverlay(Mbid content)
      : _content = content,
        super();

  @override
  Color get barrierColor => Colors.black;

  @override
  bool get barrierDismissible => false;

  @override
  String get barrierLabel => null;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return FadeTransition(
      opacity: animation,
      child: MainPage(content: _content),
    );
  }

  @override
  bool get maintainState => true;

  @override
  bool get opaque => true;

  @override
  Duration get transitionDuration => Duration(milliseconds: 300);
}

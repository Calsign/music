import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:provider/provider.dart';

import 'support.dart';
import 'data.dart';
import 'model.dart';
import 'albumView.dart';
import 'searchScreen.dart';

void main() => runApp(MusicApp());

class MusicApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => DownloadedOnlyModel()),
        ChangeNotifierProvider(create: (context) => MainPageIndexModel()),
      ],
      child: MaterialApp(
        title: 'Music',
        theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: Colors.blue[900],
          accentColor: Colors.blue[700],
          backgroundColor: Colors.black,
        ),
        home: MainPage(),
      ),
    );
  }
}

const double NOW_PLAYING_HEIGHT = 80.0;

class MainPage extends StatelessWidget {
  Content _content;

  MainPage({Key key, Content content})
      : _content = content,
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getContent(context),
      backgroundColor: Theme.of(context).backgroundColor,
      bottomNavigationBar: Material(
        elevation: 16.0,
        child: Consumer<MainPageIndexModel>(
          builder: (context, model, child) => BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
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
      switch (_content.type) {
        case ContentType.artist:
          return null;
        case ContentType.album:
          return _buildContent(
            context,
            AlbumView(
              key: Key("album/${_content.artist}/${_content.album}"),
              albumName: _content.album,
              artist: _content.artist,
            ),
          );
        case ContentType.track:
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
              _appBar(context, title),
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

  SliverAppBar _appBar(BuildContext context, Widget title) {
    return SliverAppBar(
      elevation: 10.0,
      title: title,
      primary: true,
      floating: true,
      snap: true,
      backgroundColor: Colors.transparent,
      actions: <Widget>[
        Consumer<DownloadedOnlyModel>(
          builder: (context, model, child) => IconButton(
            icon: Icon(Icons.file_download,
                color: model.downloadedOnly
                    ? Theme.of(context).accentColor
                    : IconTheme.of(context).color),
            tooltip: "Offline Mode",
            onPressed: () => model.toggle(),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.cast),
          tooltip: "Playback Devices",
          onPressed: () => null,
        ),
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: "Search",
          onPressed: () => Navigator.of(context).push(SearchOverlay()),
        )
      ],
    );
  }

  Widget _nowPlaying(BuildContext context) {
    return Container(
        width: MediaQuery.of(context).size.width,
        height: NOW_PLAYING_HEIGHT,
        padding: EdgeInsets.all(16.0),
        child: Material(
          elevation: 24.0,
          child: Placeholder(),
        ));
  }
}

class MainOverlay extends ModalRoute<void> {
  Content _content;

  MainOverlay(Content content)
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

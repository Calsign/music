import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'support.dart';
import 'albumView.dart';
import 'searchScreen.dart';

void main() => runApp(MusicApp());

class MusicApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.blue[900],
        accentColor: Colors.blue[700],
        backgroundColor: Colors.black,
      ),
      home: MainPage(),
    );
  }
}

const double NOW_PLAYING_HEIGHT = 80.0;

class MainPage extends StatefulWidget {
  MainPage({Key key}) : super(key: key);

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _mainPageIndex = 0;
  bool _offlineMode = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _content(context),
      backgroundColor: Theme.of(context).backgroundColor,
      bottomNavigationBar: Material(
        elevation: 16.0,
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          onTap: (index) => setState(() => _mainPageIndex = index),
          currentIndex: _mainPageIndex,
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: const Icon(Icons.explore),
              title: const Text("Explore"),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.history),
              title: const Text("Recent"),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.library_music),
              title: const Text("Library"),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.insert_chart),
              title: const Text("Stats"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    switch (_mainPageIndex) {
      case 0:
        return _buildContent(
          AlbumView(
            key: Key("explore"),
            albumName: "OK Computer OKNOTOK 1997 2017",
            artist: "Radiohead",
          ),
        );
      case 1:
        return _buildContent(
          AlbumView(
            key: Key("recent"),
            albumName: "Crime of the Century (Remastered)",
            artist: "Supertramp",
          ),
        );
      case 2:
        return _buildContent(
          AlbumView(
            key: Key("library"),
            albumName: "In Rainbows",
            artist: "Radiohead",
          ),
        );
      case 3:
        return _buildContent(
          AlbumView(
            key: Key("stats"),
            albumName: "Hail to the Thief",
            artist: "Radiohead",
          ),
        );
      default:
        return null;
    }
  }

  Widget _buildContent(Widget content, {Widget title}) {
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
        IconButton(
          icon: Icon(Icons.file_download,
              color: _offlineMode
                  ? Theme.of(context).accentColor
                  : IconTheme.of(context).color),
          tooltip: "Offline Mode",
          onPressed: () => setState(() => _offlineMode = !_offlineMode),
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

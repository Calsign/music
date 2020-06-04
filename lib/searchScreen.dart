import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:provider/provider.dart';

import 'musicbrainz.dart' as musicbrainz;

import 'support.dart';
import 'data.dart';
import 'model.dart';
import 'swipeable.dart';
import 'listEntry.dart';
import 'search.dart';
import 'main.dart';

class SearchOverlay extends ModalRoute<void> {
  @override
  Color get barrierColor => Colors.black.withOpacity(0.8);

  @override
  bool get barrierDismissible => false;

  @override
  String get barrierLabel => null;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return FadeTransition(
      opacity: animation,
      child: SearchScreen(),
    );
  }

  @override
  bool get maintainState => true;

  @override
  bool get opaque => false;

  @override
  Duration get transitionDuration => Duration(milliseconds: 300);
}

class SearchScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _SearchScreenState();
  }
}

class _SearchScreenState extends State<SearchScreen> {
  TextEditingController queryTextController;
  StreamController<String> queryStreamController;
  Stream<List<ReleaseGroupSearchResult>> searchResultStream;

  @override
  void initState() {
    super.initState();

    queryTextController = TextEditingController();
    queryStreamController = StreamController();
    searchResultStream = searchStream(queryStreamController.stream)
        .map((results) => results.sortedByBest());
  }

  @override
  void dispose() {
    queryTextController.dispose();
    queryStreamController.close();
    super.dispose();
  }

  void _updateQuery(String query, {bool updateController = false}) {
    setState(() {
      if (updateController) {
        queryTextController.text = query;
      }
      queryStreamController.add(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        title: TextField(
          autofocus: true,
          style: TextStyle(fontSize: 20.0),
          decoration: null,
          controller: queryTextController,
          onChanged: (query) => _updateQuery(query),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: <Widget>[
          IconButton(
              icon: Icon(Icons.close),
              onPressed: () => _updateQuery("", updateController: true)),
        ],
      ),
      body: ScrollConfiguration(
        behavior: NoGlowScrollBehavior(),
        child: NotificationListener<ScrollStartNotification>(
          child: StreamBuilder<List<ReleaseGroupSearchResult>>(
            initialData: [],
            stream: searchResultStream,
            builder: (context, snapshot) => ListView.builder(
              padding: EdgeInsets.all(0.0),
              itemBuilder: (context, index) {
                if (snapshot.hasData && index < snapshot.data.length) {
                  return ListEntry(
                    ListEntryData.ofReleaseGroupSearchResult(
                        snapshot.data[index]),
                    foregroundColor: Color(0xFF111111),
                    opacity: 0.6,
                    heroTag:
                        "releaseGroup/${snapshot.data[index].mbid}/coverArt",
                    callbacks: {
                      SwipeEvent.addToQueue: () =>
                          _buildQueue(snapshot.data[index]).then((tracks) =>
                              Provider.of<QueueModel>(context, listen: false)
                                  .addAllToQueue(tracks)),
                      SwipeEvent.playNext: () =>
                          _buildQueue(snapshot.data[index]).then((tracks) =>
                              Provider.of<QueueModel>(context, listen: false)
                                  .playAllNext(tracks)),
                      SwipeEvent.playNow: () =>
                          _buildQueue(snapshot.data[index]).then((tracks) =>
                              Provider.of<QueueModel>(context, listen: false)
                                  .setQueue(tracks)),
                      SwipeEvent.select: () {
                        Navigator.of(context)
                            .push(MainOverlay(snapshot.data[index]));
                      },
                    },
                  );
                } else if (snapshot.hasError && index == 0) {
                  return ListTile(title: Text(snapshot.error.toString()));
                } else {
                  return null;
                }
              },
            ),
          ),
          onNotification: (notification) {
            // hide keyboard when user starts scrolling
            FocusScope.of(context).unfocus();
            return false;
          },
        ),
      ),
    );
  }

  Future<Iterable<QueuedTrackInfo>> _buildQueue(
      ReleaseGroupSearchResult releaseGroup) {
    return musicbrainz.fetchReleaseGroupInfo(releaseGroup.mbid).then(
        (releaseGroup) => musicbrainz
            .fetchReleaseInfo(releaseGroup.selectBestRelease().mbid)
            .then((release) => release.tracks.map<QueuedTrackInfo>((track) =>
                QueuedTrackInfo.ofReleaseTrackInfo(releaseGroup, track))));
  }
}

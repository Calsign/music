import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'futureContent.dart';

import 'util.dart';
import 'data.dart';
import 'swipeable.dart';
import 'listEntry.dart';
import 'lastfm.dart' as lastfm;

class AlbumView extends SliverFutureContent<AlbumInfo> {
  AlbumView({Key key, @required String artist, @required String albumName})
      : super(key: key, future: lastfm.fetchAlbumInfo(artist, albumName));

  @override
  Widget builder(BuildContext context, AlbumInfo albumInfo) {
    var width = MediaQuery.of(context).size.width;
    var padding = 16.0;
    var albumArtSize = min(width * 2 / 5, 300.0);
    var swipeableHeight = albumArtSize + padding * 2;

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == 0) {
            return Swipeable(
              width: () => MediaQuery.of(context).size.width,
              height: () => swipeableHeight,
              buildContent: (context) => Container(
                padding: EdgeInsets.all(padding),
                alignment: Alignment.center,
                child: Row(
                  children: <Widget>[
                    Image.network(albumInfo.albumArtUri.toString(),
                        width: albumArtSize, height: albumArtSize),
                    SizedBox(width: padding),
                    Flexible(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            albumInfo.title,
                            style: TextStyle(fontSize: 20.0),
                          ),
                          SizedBox(height: 6.0),
                          Text(
                            albumInfo.artists.join(", "),
                            style: TextStyle(fontSize: 16.0),
                          ),
                          SizedBox(height: 24.0),
                          Text(
                            "${albumInfo.tracks.length} tracks \u{00b7} ${secondsToString(albumInfo.duration)}",
                            style: TextStyle(fontSize: 12.0),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // enable bottom sheet, but don't show a header
              buildPopupContent: (context) => SizedBox(height: 0.0),
              callbacks: {
                SwipeEvent.addToQueue: () => print("adding album to queue"),
                SwipeEvent.playNow: () => print("playing album now"),
                SwipeEvent.playNext: () => print("playing album next"),
                SwipeEvent.goToArtist: () => print("going to album artist"),
              },
            );
          } else if (index > albumInfo.tracks.length) {
            return null;
          } else {
            ListEntryData entry =
                ListEntryData.ofAlbumTrackInfo(albumInfo, albumInfo.tracks[index - 1]);
            return ListEntry(
              entry,
              showTrackNumber: true,
              callbacks: {
                SwipeEvent.addToQueue: () =>
                    print("adding ${entry.title} to queue"),
                SwipeEvent.playNext: () => print("playing ${entry.title} next"),
                SwipeEvent.playNow: () => print("playing ${entry.title}"),
                SwipeEvent.goToAlbum: () =>
                    print("going to album ${entry.album}"),
                SwipeEvent.goToArtist: () =>
                    print("going to artist ${entry.artists}"),
              },
            );
          }
        },
      ),
    );
  }
}

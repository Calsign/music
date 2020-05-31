import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'futureContent.dart';

import 'util.dart';
import 'data.dart';
import 'swipeable.dart';
import 'listEntry.dart';
import 'musicbrainz.dart' as musicbrainz;

class ReleaseGroupView
    extends SliverFutureContent<Pair<ReleaseGroupInfo, ReleaseInfo>> {
  ReleaseGroupView.musicbrainz({Key key, @required String mbid})
      : super(
            key: key,
            future: musicbrainz.fetchReleaseGroupInfo(mbid).then(
                (releaseGroup) => musicbrainz
                    .fetchReleaseInfo(releaseGroup.selectBestRelease().mbid)
                    .then((release) => Pair(releaseGroup, release))));

  @override
  Widget builder(
      BuildContext context, Pair<ReleaseGroupInfo, ReleaseInfo> releaseInfo) {
    var width = MediaQuery.of(context).size.width;
    var padding = 20.0;
    var albumArtSize = min(width * 3 / 7, 300.0);
    var swipeableHeight = albumArtSize + padding * 2;

    print('title: ${releaseInfo.left.title}');

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
                    Image.network(
                      releaseInfo.right.coverArtUri.toString(),
                      errorBuilder: (context, obj, stackTrace) => Image.network(
                        releaseInfo.left.coverArtUri.toString(),
                        errorBuilder: (context, obj, stackTrace) => Icon(
                            Icons.album,
                            size: albumArtSize,
                            color: Colors.white70),
                        width: albumArtSize,
                        height: albumArtSize,
                      ),
                      width: albumArtSize,
                      height: albumArtSize,
                    ),
                    SizedBox(width: padding),
                    Flexible(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            releaseInfo.left.title,
                            style: const TextStyle(fontSize: 20.0),
                          ),
                          SizedBox(height: 6.0),
                          Text(
                            releaseInfo.left.artists
                                .map((artist) => artist.value)
                                .join(", "),
                            style: const TextStyle(fontSize: 16.0),
                          ),
                          SizedBox(height: 24.0),
                          Text(
                            "${releaseInfo.right.tracks.length} tracks \u{00b7} ${durationToString(releaseInfo.right.duration)}",
                            style: const TextStyle(fontSize: 12.0),
                          ),
                          SizedBox(height: 6.0),
                          Text(
                            "${releaseInfo.left.releaseDate?.year ?? ""}",
                            style: const TextStyle(fontSize: 12.0),
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
          } else if (index > releaseInfo.right.tracks.length) {
            return null;
          } else {
            ListEntryData entry = ListEntryData.ofAlbumTrackInfo(
                releaseInfo.right, releaseInfo.right.tracks[index - 1]);
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
                SwipeEvent.goToArtist: () => print(
                    "going to artist ${entry.artists.map((artist) => artist.value).join(", ")}"),
              },
            );
          }
        },
      ),
    );
  }
}

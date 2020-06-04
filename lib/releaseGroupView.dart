import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:provider/provider.dart';

import 'util.dart';
import 'data.dart';
import 'futureContent.dart';
import 'swipeable.dart';
import 'coverArt.dart';
import 'listEntry.dart';
import 'musicbrainz.dart' as musicbrainz;
import 'model.dart';

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

    Iterable<QueuedTrackInfo> releaseQueue = releaseInfo.right.tracks
        .map<QueuedTrackInfo>((track) =>
            QueuedTrackInfo.ofReleaseTrackInfo(releaseInfo.left, track));

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == 0) {
            String extraInfo = <String>[
              "${releaseInfo.right.tracks.length} tracks",
              durationToString(releaseInfo.right.duration),
              releaseInfo.left.releaseDate?.year?.toString(),
            ].where((element) => element != null).join(" \u{00b7} ");

            return Swipeable(
              width: () => MediaQuery.of(context).size.width,
              height: () => swipeableHeight,
              buildContent: (context) => Container(
                padding: EdgeInsets.all(padding),
                alignment: Alignment.center,
                child: Row(
                  children: <Widget>[
                    Hero(
                      tag: "releaseGroup/${releaseInfo.left.mbid}/coverArt",
                      child: coverArt(
                          mainArt: releaseInfo.right.coverArtData,
                          backupArt: releaseInfo.left.coverArtData,
                          size: albumArtSize),
                    ),
                    SizedBox(width: padding),
                    Flexible(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            releaseInfo.left.title,
                            style: const TextStyle(
                                fontSize: 20.0, fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 6.0),
                          Text(
                            releaseInfo.left.artists
                                .map((artist) => artist.value)
                                .join(", "),
                            style: const TextStyle(fontSize: 14.0),
                          ),
                          SizedBox(height: 20.0),
                          Text(
                            extraInfo,
                            style: const TextStyle(
                              fontSize: 11.0,
                              color: Colors.white70,
                            ),
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
                SwipeEvent.addToQueue: () =>
                    Provider.of<QueueModel>(context, listen: false)
                        .addAllToQueue(releaseQueue),
                SwipeEvent.playNow: () =>
                    Provider.of<QueueModel>(context, listen: false)
                        .setQueue(releaseQueue),
                SwipeEvent.playNext: () =>
                    Provider.of<QueueModel>(context, listen: false)
                        .playAllNext(releaseQueue),
              },
            );
          } else if (index > releaseInfo.right.tracks.length) {
            return null;
          } else {
            ListEntryData entry = ListEntryData.ofAlbumTrackInfo(
                releaseInfo.right, releaseInfo.right.tracks[index - 1]);
            QueuedTrackInfo trackInfo = QueuedTrackInfo.ofReleaseTrackInfo(
                releaseInfo.left, releaseInfo.right.tracks[index - 1]);
            return ListEntry(
              entry,
              showTrackNumber: true,
              callbacks: {
                SwipeEvent.addToQueue: () =>
                    Provider.of<QueueModel>(context, listen: false)
                        .addToQueue(trackInfo),
                SwipeEvent.playNext: () =>
                    Provider.of<QueueModel>(context, listen: false)
                        .playNext(trackInfo),
                SwipeEvent.playNow: () =>
                    Provider.of<QueueModel>(context, listen: false).setQueue(
                      releaseQueue,
                      startIndex: index - 1,
                    ),
              },
            );
          }
        },
      ),
    );
  }
}

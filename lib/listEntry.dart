import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:provider/provider.dart';

import 'util.dart';
import 'data.dart';
import 'model.dart';
import 'swipeable.dart';
import 'coverArt.dart';

const double LIST_ENTRY_HEIGHT = 60.0;

enum ListEntryType { track, album, playlist }

class ListEntryData extends Mbid {
  final ListEntryType type;
  final String title;
  final MbidOf<String> album;
  final int trackNumber;
  final List<MbidOf<String>> artists;
  final CoverArtData coverArtData;
  final int year;
  final Duration duration;

  ListEntryData.ofAlbumTrackInfo(ReleaseInfo album, ReleaseTrackInfo track)
      : type = ListEntryType.track,
        title = track.title,
        album = MbidOf.copy(album, album.title),
        trackNumber = track.trackNumber,
        artists = track.artists,
        coverArtData = album.coverArtData,
        year = album.releaseDate != null ? album.releaseDate.year : null,
        duration = track.duration,
        super.copy(track);

  ListEntryData.ofReleaseGroupSearchResult(
      ReleaseGroupSearchResult releaseGroup)
      : type = ListEntryType.album,
        title = releaseGroup.title,
        album = null,
        trackNumber = null,
        artists = releaseGroup.artists,
        coverArtData = releaseGroup.coverArtData,
        year = null,
        duration = null,
        super.copy(releaseGroup);

  ListEntryData.ofQueuedTrackInfo(QueuedTrackInfo trackInfo)
      : type = ListEntryType.track,
        title = trackInfo.title,
        album = trackInfo.releaseGroup,
        trackNumber = null,
        artists = trackInfo.artists,
        coverArtData = trackInfo.coverArtData,
        year = trackInfo.releaseDate?.year,
        duration = trackInfo.duration,
        super.copy(trackInfo);
}

class ListEntry extends StatelessWidget {
  final ListEntryData _data;
  final Map<SwipeEvent, void Function()> _callbacks;
  final Color _foregroundColor, _backgroundColor;
  final double _opacity;
  final bool _showTrackNumber, _showNowPlaying;

  ListEntry(ListEntryData data,
      {Map<SwipeEvent, void Function()> callbacks,
      Color foregroundColor,
      Color backgroundColor,
      double opacity = 1.0,
      bool showTrackNumber = false,
      bool showNowPlaying = true})
      : _data = data,
        _callbacks = callbacks ?? Map(),
        _foregroundColor = foregroundColor,
        _backgroundColor = backgroundColor,
        _opacity = opacity,
        _showTrackNumber = showTrackNumber,
        _showNowPlaying = showNowPlaying;

  @override
  Widget build(BuildContext context) {
    return Swipeable(
      foregroundColor: _foregroundColor,
      backgroundColor: _backgroundColor,
      opacity: _opacity,
      buildContent: (context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
        child: ListEntryContents(
          _data,
          showTrackNumber: _showTrackNumber,
          showNowPlaying: _showNowPlaying,
        ),
      ),
      buildPopupContent: (context) => Padding(
        padding: EdgeInsets.all(16.0),
        child: ListEntryContents(_data),
      ),
      width: () => MediaQuery.of(context).size.width,
      height: () => LIST_ENTRY_HEIGHT,
      callbacks: _callbacks,
    );
  }
}

class ListEntryContents extends StatelessWidget {
  final ListEntryData _data;
  final bool _showTrackNumber, _showNowPlaying;
  final Widget _right;

  ListEntryContents(ListEntryData data,
      {bool showTrackNumber = false, bool showNowPlaying = true, Widget right})
      : _data = data,
        _showTrackNumber = showTrackNumber,
        _showNowPlaying = showNowPlaying,
        _right = right;

  Widget _icon(BuildContext context) {
    if (_data.type == ListEntryType.track &&
        _data.trackNumber != null &&
        _showTrackNumber) {
      return Container(
        width: 42.0,
        height: 42.0,
        alignment: Alignment(0.0, 0.0),
        child: Text(
          "${_data.trackNumber}",
          style: TextStyle(
            fontSize: 15.0,
            color: Color(0xFFBBBBBB),
          ),
        ),
      );
    } else if (_data.coverArtData != null) {
      return coverArt(mainArt: _data.coverArtData, size: 42.0);
    } else {
      return const Icon(Icons.album, size: 42.0, color: Color(0xFFBBBBBB));
    }
  }

  @override
  Widget build(BuildContext context) {
    var secondData = _data.type == ListEntryType.track
        ? (_data.trackNumber == null
            ? _data.album.value
            : durationToString(_data.duration))
        : _data.year;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Consumer<QueueModel>(
          builder: (context, model, child) {
            if (_showNowPlaying &&
                model.currentTrack != null &&
                model.isPlaying) {
              var testMbid;
              switch (_data.mbidType) {
                case MbidType.recording:
                  testMbid = model.currentTrack.mbid;
                  break;
                case MbidType.release:
                  // TODO nullable because this part is currently unimplemented on the QueuedTrackInfo side
                  testMbid = model.currentTrack.release?.mbid;
                  break;
                case MbidType.releaseGroup:
                  testMbid = model.currentTrack.releaseGroup.mbid;
                  break;
                case MbidType.artist:
                  testMbid = model.currentTrack.artists.first.mbid;
                  break;
              }

              return testMbid == _data.mbid
                  ? const Icon(Icons.equalizer, size: 42.0)
                  : child;
            } else {
              return child;
            }
          },
          child: _icon(context),
        ),
        SizedBox(width: 16.0),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                _data.title,
                style: const TextStyle(
                  fontSize: 15.0,
                ),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
              ),
              SizedBox(height: 4.0),
              Text(
                secondData == null
                    ? _data.artists.map((artist) => artist.value).join(",")
                    : "${_data.artists.map((artist) => artist.value).join(",")}  \u{00b7}  $secondData",
                style: const TextStyle(
                  fontSize: 12.0,
                  color: Color(0xFFBBBBBB),
                ),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
              ),
            ],
          ),
        ),
        _right != null ? _right : SizedBox(width: 0.0),
      ],
    );
  }
}

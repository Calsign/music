import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'util.dart';
import 'data.dart';
import 'swipeable.dart';

const double LIST_ENTRY_HEIGHT = 60.0;

enum ListEntryType { track, album, playlist }

class ListEntryData extends Mbid {
  final ListEntryType type;
  final String title;
  final MbidOf<String> album;
  final int trackNumber;
  final List<MbidOf<String>> artists;
  final Uri coverArtUri;
  final int year;
  final Duration duration;

  ListEntryData.ofAlbumTrackInfo(ReleaseInfo album, ReleaseTrackInfo track)
      : type = ListEntryType.track,
        title = track.title,
        album = MbidOf.copy(album, album.title),
        trackNumber = track.trackNumber,
        artists = track.artists,
        coverArtUri = album.coverArtUri,
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
        coverArtUri = releaseGroup.coverArtUri,
        year = null,
        duration = null,
        super.copy(releaseGroup);
}

class ListEntry extends StatelessWidget {
  final ListEntryData _data;
  final Map<SwipeEvent, void Function()> _callbacks;
  final Color _foregroundColor, _backgroundColor;
  final bool _showTrackNumber;

  ListEntry(ListEntryData data,
      {Map<SwipeEvent, void Function()> callbacks,
      Color foregroundColor,
      Color backgroundColor,
      bool showTrackNumber = false})
      : _data = data,
        _callbacks = callbacks ?? Map(),
        _foregroundColor = foregroundColor,
        _backgroundColor = backgroundColor,
        _showTrackNumber = showTrackNumber;

  @override
  Widget build(BuildContext context) {
    return Swipeable(
      foregroundColor: _foregroundColor,
      backgroundColor: _backgroundColor,
      buildContent: (context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
        child: _itemContents(context),
      ),
      buildPopupContent: (context) => Padding(
        padding: EdgeInsets.all(16.0),
        child: _itemContents(context, forceAlbumArt: true),
      ),
      width: () => MediaQuery.of(context).size.width,
      height: () => LIST_ENTRY_HEIGHT,
      callbacks: _callbacks,
    );
  }

  Widget _itemContents(context, {bool forceAlbumArt = false}) {
    var secondData = _data.type == ListEntryType.track
        ? (_data.trackNumber == null
            ? _data.album
            : durationToString(_data.duration))
        : _data.year;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        _data.type == ListEntryType.track &&
                _data.trackNumber != null &&
                _showTrackNumber &&
                !forceAlbumArt
            ? Container(
                width: 42.0,
                height: 42.0,
                alignment: Alignment(0.0, 0.0),
                child: Text(
                  "${_data.trackNumber}",
                  style: TextStyle(
                    fontSize: 15.0,
                    color: Colors.white70,
                  ),
                ),
              )
            : (_data.coverArtUri != null)
                ? Image.network(
                    _data.coverArtUri.toString(),
                    errorBuilder: (context, obj, stackTrace) => const Icon(
                        Icons.album,
                        size: 42.0,
                        color: Colors.white70),
                    width: 42.0,
                    height: 42.0,
                  ) //Icon(widget._data.albumArt, size: 42.0, color: Colors.white70)
                : const Icon(Icons.album, size: 42.0, color: Colors.white70),
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
                  color: Colors.white70,
                ),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'util.dart';
import 'data.dart';
import 'swipeable.dart';

const double LIST_ENTRY_HEIGHT = 60.0;

enum ListEntryType { track, album, playlist }

class ListEntryData {
  final ListEntryType type;
  final String title;
  final String album;
  final int trackNumber;
  final List<String> artists;
  final Uri albumArtUri;
  final int year;
  final double duration;

  ListEntryData.ofAlbumTrackInfo(AlbumInfo album, AlbumTrackInfo track)
      : type = ListEntryType.track,
        title = track.title,
        album = album.title,
        trackNumber = track.trackNumber,
        artists = track.artists,
        albumArtUri = album.albumArtUri,
        year = album.year,
        duration = track.duration;

  ListEntryData.ofAlbumSearchResult(AlbumSearchResult album)
      : type = ListEntryType.track,
        title = album.title,
        album = null,
        trackNumber = null,
        artists = album.artists,
        albumArtUri = album.albumArtUri,
        year = null,
        duration = null;

  const ListEntryData.track(
      {@required String title,
      @required List<String> artists,
      @required String album,
      int trackNumber,
      Uri albumArtUri,
      int year,
      double duration})
      : type = ListEntryType.track,
        title = title,
        artists = artists,
        album = album,
        trackNumber = trackNumber,
        albumArtUri = albumArtUri,
        year = year,
        duration = duration;

  const ListEntryData.album(
      {@required String title,
      @required List<String> artists,
      Uri albumArtUri,
      int year})
      : type = ListEntryType.album,
        title = title,
        artists = artists,
        album = null,
        trackNumber = null,
        albumArtUri = albumArtUri,
        year = year,
        duration = null;
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
            : secondsToString(_data.duration))
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
            : (_data.albumArtUri != null)
                ? Image.network(
                    _data.albumArtUri.toString(),
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
                    ? _data.artists.join(",")
                    : "${_data.artists.join(",")}  \u{00b7}  $secondData",
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

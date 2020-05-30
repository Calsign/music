import 'package:meta/meta.dart';

class AlbumTrackInfo {
  final String title;
  final int trackNumber;
  final List<String> artists;
  final double duration;

  const AlbumTrackInfo(
      {@required String title,
      @required List<String> artists,
      int trackNumber,
      double duration})
      : title = title,
        artists = artists,
        trackNumber = trackNumber,
        duration = duration;
}

class AlbumInfo {
  final String title;
  final List<String> artists;
  final List<AlbumTrackInfo> tracks;
  final Uri albumArtUri;
  final double duration;
  final String description;
  final int year;

  const AlbumInfo(
      {@required String title,
      @required List<String> artists,
      @required List<AlbumTrackInfo> tracks,
      Uri albumArtUri,
      double duration,
      String description,
      int year})
      : title = title,
        artists = artists,
        tracks = tracks,
        albumArtUri = albumArtUri,
        duration = duration,
        description = description,
        year = year;
}

class AlbumSearchResult {
  final String title;
  final List<String> artists;
  final Uri albumArtUri;

  const AlbumSearchResult(
      {@required String title, @required List<String> artists, Uri albumArtUri})
      : title = title,
        artists = artists,
        albumArtUri = albumArtUri;
}
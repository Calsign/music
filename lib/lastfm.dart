import 'package:meta/meta.dart';
import 'package:intl/intl.dart';

import 'dart:convert' as convert;
import 'package:http/http.dart' as http;

import 'data.dart';
import 'secret.dart';
import 'util.dart';

String domain = "ws.audioscrobbler.com";
String apiPath = "/2.0/";

Uri formUri(String method, Map<String, String> params) {
  Map<String, String> map = Map();
  map.addAll(params);

  map["method"] = method;
  map["format"] = "json";
  map["api_key"] = lastfm_api_key;

  return Uri.https(domain, apiPath, map);
}

Uri extractAlbumArt(List data) {
  Map<String, String> imageSizes = Map();
  for (var item in data) {
    imageSizes[item["size"]] = item["#text"];
  }
  List<String> prefs = ["mega", "extraLarge", "large", "medium", "small"];
  for (String pref in prefs) {
    if (imageSizes.containsKey(pref)) {
      return Uri.parse(imageSizes[pref]);
    }
  }
  if (imageSizes.isNotEmpty) {
    return Uri.parse(imageSizes[imageSizes.keys.first]);
  } else {
    return null;
  }
}

DateTime parseDate(String dateStr) {
  DateFormat format = DateFormat("dd MMM yyyy, hh:mm");
  return format.parse(dateStr);
}

Future<ReleaseInfo> fetchReleaseInfo(String artist, String album) {
  return http
      .get(formUri("album.getinfo", {
    "artist": artist,
    "album": album,
  }))
      .then((response) {
    if (response.statusCode == 200) {
      var data = convert.jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        Uri albumArtUri = extractAlbumArt(data["album"]["image"]);

        List<ReleaseTrackInfo> tracks = data["album"]["tracks"]["track"]
            .map<ReleaseTrackInfo>((track) => ReleaseTrackInfo(
                  mbid: null,
                  title: track["name"],
                  artists: <MbidOf<String>>[
                    MbidOf.empty(track["artist"]["name"])
                  ],
                  trackNumber: int.parse(track["@attr"]["rank"]),
                  duration: Duration(
                      milliseconds:
                          ((double.parse(track["duration"]) * 1000).round())),
                ))
            .toList();

        Duration duration = tracks.fold(Duration.zero,
            (acc, track) => (track.duration ?? Duration.zero) + acc);

        String description = data["album"]["wiki"] != null
            ? data["album"]["wiki"]["summary"]
            : null;

        return ReleaseInfo(
          mbid: data["album"]["mbid"],
          title: data["album"]["name"],
          artists: <MbidOf<String>>[MbidOf.empty(data["album"]["artist"])],
          tracks: tracks,
          coverArtData: CoverArtData([Pair(albumArtUri, 200.0)]), // 200.0 is guessed
          duration: duration,
          description: description,
        );
      }
    }

    throw Exception("failed to fetch album info"); // TODO
  });
}

class AlbumSearchResult extends Mbid {
  final String title;
  final List<MbidOf<String>> artists;
  final Uri albumArtUri;

  const AlbumSearchResult(
      {@required String mbid,
        @required String title,
        @required List<MbidOf<String>> artists,
        Uri albumArtUri})
      : title = title,
        artists = artists,
        albumArtUri = albumArtUri,
        super(mbid, MbidType.release);
}

Future<List<AlbumSearchResult>> searchAlbum(String query) {
  return http
      .get(formUri("album.search", {
    "album": query,
  }))
      .then((response) {
    if (response.statusCode == 200) {
      var data = convert.jsonDecode(response.body);
      return data["results"]["albummatches"]["album"]
          .map<AlbumSearchResult>((album) => AlbumSearchResult(
                mbid: album["mbid"],
                title: album["name"],
                artists: <MbidOf<String>>[MbidOf.empty(album["artist"])],
                albumArtUri: extractAlbumArt(album["image"]),
              ))
          .toList();
    }

    return <AlbumSearchResult>[];
    //throw Exception("failed to search for album");
  });
}

import 'package:intl/intl.dart';

import 'dart:convert' as convert;
import 'package:http/http.dart' as http;

import 'data.dart';
import 'secret.dart';

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

Future<AlbumInfo> fetchAlbumInfo(String artist, String album) {
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
        int year;

        List<AlbumTrackInfo> tracks = data["album"]["tracks"]["track"]
            .map<AlbumTrackInfo>((track) => AlbumTrackInfo(
                  title: track["name"],
                  artists: [track["artist"]["name"]],
                  trackNumber: int.parse(track["@attr"]["rank"]),
                  duration: double.parse(track["duration"]),
                ))
            .toList();

        double duration =
            tracks.fold(0.0, (acc, track) => (track.duration ?? 0.0) + acc);

        String description = data["album"]["wiki"] != null
            ? data["album"]["wiki"]["summary"]
            : null;

        return AlbumInfo(
          title: data["album"]["name"],
          artists: [data["album"]["artist"]],
          tracks: tracks,
          albumArtUri: albumArtUri,
          duration: duration,
          description: description,
          year: year,
        );
      }
    }

    throw Exception("failed to fetch album info"); // TODO
  });
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
                title: album["name"],
                artists: [album["artist"]],
                albumArtUri: extractAlbumArt(album["image"]),
              ))
          .toList();
    }

    return <AlbumSearchResult>[];
    //throw Exception("failed to search for album");
  });
}

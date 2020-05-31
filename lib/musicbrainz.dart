import 'package:meta/meta.dart';

import 'dart:convert' as convert;
import 'package:http/http.dart' as http;

import 'data.dart';

enum _Entity { artist, recording, release, releaseGroup }

extension _EntityToStr on _Entity {
  String toStr() {
    switch (this) {
      case _Entity.artist:
        return "artist";
      case _Entity.recording:
        return "recording";
      case _Entity.release:
        return "release";
      case _Entity.releaseGroup:
        return "release-group";
      default:
        throw Exception();
    }
  }
}

enum _Inc { artists, recordings, releases, releaseGroups, labels }

extension _IncToStr on _Inc {
  String toStr() {
    switch (this) {
      case _Inc.artists:
        return "artists";
      case _Inc.recordings:
        return "recordings";
      case _Inc.releases:
        return "releases";
      case _Inc.releaseGroups:
        return "release-groups";
      case _Inc.labels:
        return "labels";
      default:
        throw Exception();
    }
  }
}

extension _EntityValidIncs on _Entity {
  List<_Inc> validIncs() {
    switch (this) {
      case _Entity.artist:
        return const <_Inc>[_Inc.recordings, _Inc.releases, _Inc.releaseGroups];
      case _Entity.recording:
        return const <_Inc>[_Inc.artists, _Inc.releases];
      case _Entity.release:
        return const <_Inc>[
          _Inc.artists,
          _Inc.labels,
          _Inc.recordings,
          _Inc.releaseGroups
        ];
      case _Entity.releaseGroup:
        return const <_Inc>[_Inc.artists, _Inc.releases];
      default:
        throw Exception();
    }
  }
}

enum CoverArtSize { small, large, huge }

extension CoverArtSizeToInt on CoverArtSize {
  int toInt() {
    switch (this) {
      case CoverArtSize.small:
        return 250;
      case CoverArtSize.large:
        return 500;
      case CoverArtSize.huge:
        return 1200;
      default:
        throw Exception();
    }
  }
}

Uri formCoverArtUri<T>(
    {@required _Entity entity,
    @required String mbid,
    CoverArtSize size = CoverArtSize.small}) {
  switch (entity) {
    case _Entity.release:
    case _Entity.releaseGroup:
      break;
    default:
      throw Exception("trying to get cover art of ${entity.toStr()}");
  }

  return Uri.https(
      "coverartarchive.org", "${entity.toStr()}/$mbid/front-${size.toInt()}");
}

Uri formLookupUri(
    {@required _Entity entity, @required String mbid, List<_Inc> incs}) {
  return Uri.https(
      "musicbrainz.org",
      "ws/2/${entity.toStr()}/$mbid",
      incs != null
          ? {
              "fmt": "json",
              "inc": incs.map<String>((inc) => inc.toStr()).join("+"),
            }
          : {"fmt": "json"});
}

Uri formSearchUri({@required _Entity entity, @required String query}) {
  return Uri.https("musicbrainz.org", "ws/2/${entity.toStr()}", {
    "fmt": "json",
    "query": query,
    "limit": "100",
  });
}

List<MbidOf<String>> extractArtists(dynamic data) {
  return data
      .map<MbidOf<String>>((artist) => MbidOf<String>(artist["artist"]["id"],
          MbidType.artist, artist["name"] ?? artist["artist"]["name"]))
      .toList();
}

DateTime extractDate(String dateStr) {
  if (dateStr == null) {
    return null;
  }
  var date = DateTime.tryParse(dateStr);
  if (date != null) {
    return date;
  }
  var year = int.tryParse(dateStr);
  if (year != null) {
    return DateTime(year);
  }
  return null;
}

Future<http.Response> handleRateLimiting(Uri uri, {times = 1}) {
  return Future.any(<Future<dynamic>>[
    http.get(uri),
    Future.delayed(Duration(seconds: 5), null)
  ]).then((response) {
    if (response == null) {
      // Timeout
      return http.Response("Timed out", 408);
    }
    if (response.statusCode == 503) {
      print("Rate limited! Waiting ${times * 500} milliseconds...");
      return Future.delayed(Duration(milliseconds: times * 500),
          () => handleRateLimiting(uri, times: times + 1));
    } else {
      return Future.value(response);
    }
  });
}

Future<ReleaseInfo> fetchReleaseInfo(String mbid) {
  Uri uri = formLookupUri(
      entity: _Entity.release,
      mbid: mbid,
      incs: <_Inc>[_Inc.artists, _Inc.recordings]);

  return handleRateLimiting(uri).then((response) {
    switch (response.statusCode) {
      case 200:
        var data = convert.jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          String mbid = data["id"];
          List<MbidOf<String>> artists = extractArtists(data["artist-credit"]);

          List<ReleaseTrackInfo> tracks = data["media"]
              .map<List<ReleaseTrackInfo>>(
                  (media) => (media["tracks"] as List<dynamic>)
                      .map<ReleaseTrackInfo>((track) => ReleaseTrackInfo(
                            mbid: track["recording"]["id"],
                            title: track["title"],
                            artists: artists,
                            duration: track["length"] != null
                                ? Duration(milliseconds: track["length"])
                                : null,
                            trackNumber: track["position"],
                          ))
                      .toList())
              .expand<ReleaseTrackInfo>((id) => id as List<ReleaseTrackInfo>)
              .toList();

          Duration duration = tracks.fold(Duration.zero,
              (acc, track) => (track.duration ?? Duration.zero) + acc);

          return ReleaseInfo(
            mbid: mbid,
            title: data["title"],
            artists: artists,
            releaseDate: extractDate(data["date"]),
            albumArtUri: formCoverArtUri(entity: _Entity.release, mbid: mbid),
            tracks: tracks,
            duration: duration,
          );
        }
    }

    throw Exception(
        "failed to fetch release info; status code: ${response.statusCode}, body: ${response.body}, uri: $uri");
  });
}

ReleaseGroupType extractReleaseType(String string) {
  switch (string?.toLowerCase()) {
    case "album":
      return ReleaseGroupType.album;
    case "single":
      return ReleaseGroupType.single;
    case "ep":
      return ReleaseGroupType.ep;
    case "broadcast":
      return ReleaseGroupType.broadcast;
    default:
      return ReleaseGroupType.other;
  }
}

Future<ReleaseGroupInfo> fetchReleaseGroupInfo(String mbid) {
  Uri uri = formLookupUri(
      entity: _Entity.releaseGroup,
      mbid: mbid,
      incs: <_Inc>[_Inc.artists, _Inc.releases]);

  return handleRateLimiting(uri).then((response) {
    switch (response.statusCode) {
      case 200:
        var data = convert.jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          String mbid = data["id"];
          return ReleaseGroupInfo(
            mbid: mbid,
            title: data["title"],
            artists: extractArtists(data["artist-credit"]),
            type: extractReleaseType(data["primary-type"]),
            releaseDate: extractDate(data["first-release-date"]),
            releases: data["releases"]
                .map<ReleaseGroupReleaseInfo>(
                    (release) => ReleaseGroupReleaseInfo(
                          mbid: release["id"],
                          title: release["title"],
                          releaseDate: extractDate(release["date"]),
                          country: release["country"],
                          packaging: release["packaging"],
                          status: release["status"],
                        ))
                .toList(),
            coverArtUri:
                formCoverArtUri(entity: _Entity.releaseGroup, mbid: mbid),
          );
        }
    }

    throw Exception(
        "failed to fetch release group info; status code: ${response.statusCode}, body: ${response.body}, uri: $uri");
  });
}

Future<List<ReleaseGroupSearchResult>> searchReleaseGroup(String query) {
  if (query.isEmpty) {
    return Future.value(<ReleaseGroupSearchResult>[]);
  }

  Uri uri = formSearchUri(entity: _Entity.releaseGroup, query: query);
  return handleRateLimiting(uri).then((response) {
    switch (response.statusCode) {
      case 200:
        var data = convert.jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return data["release-groups"]
              .map<ReleaseGroupSearchResult>((releaseGroup) {
            String mbid = releaseGroup["id"];

            return ReleaseGroupSearchResult(
              mbid: mbid,
              title: releaseGroup["title"],
              artists: extractArtists(releaseGroup["artist-credit"]),
              releaseMbids: releaseGroup["releases"]
                  ?.map<Mbid>((release) => Mbid(release["id"], MbidType.release))
                  ?.toList() ?? List(),
              coverArtUri:
                  formCoverArtUri(entity: _Entity.releaseGroup, mbid: mbid),
              primaryType: extractReleaseType(releaseGroup["primary-type"]),
              searchScore: releaseGroup["score"],
            );
          }).toList();
        }
    }

    throw Exception(
        "failed to search; status code: ${response.statusCode}, body: ${response.body}, uri: $uri");
  });
}

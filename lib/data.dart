import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import 'util.dart';

enum MbidType { artist, releaseGroup, release, recording }

class Mbid {
  final MbidType mbidType;
  final String mbid;

  const Mbid(String mbid, MbidType type)
      : mbid = mbid,
        mbidType = type;

  const Mbid.empty()
      : mbid = null,
        mbidType = null;

  Mbid.copy(Mbid source)
      : mbid = source.mbid,
        mbidType = source.mbidType;
}

class MbidOf<T> extends Mbid {
  final T value;

  const MbidOf(String mbid, MbidType type, T value)
      : value = value,
        super(mbid, type);

  const MbidOf.empty(T value)
      : value = value,
        super.empty();

  MbidOf.copy(Mbid source, T value)
      : value = value,
        super.copy(source);
}

enum ReleaseGroupType { album, single, ep, broadcast, other }

extension ReleaseGroupTypeToPrettyStr on ReleaseGroupType {
  String toPrettyStr() {
    switch (this) {
      case ReleaseGroupType.album:
        return "Album";
      case ReleaseGroupType.single:
        return "Single";
      case ReleaseGroupType.ep:
        return "EP";
      case ReleaseGroupType.broadcast:
        return "Broadcast";
      case ReleaseGroupType.other:
        return "Other";
      default:
        throw Exception();
    }
  }
}

class CoverArtData {
  List<Pair<Uri, double>> _data;

  CoverArtData(List<Pair<Uri, double>> data) {
    _data = data;
    _data.sort((pairA, pairB) {
      double diff = pairA.right - pairB.right;
      return diff < 0 ? -1 : diff > 0 ? 1 : 0;
    });
  }

  Uri findSize(double size) {
    for (var pair in _data) {
      if (pair.right >= size) {
        return pair.left;
      }
    }
    return _data.last.left;
  }

  Uri get largestSize => _data.last.left;
}

class QueuedTrackInfo extends Mbid {
  final String title;
  final List<MbidOf<String>> artists;
  final MbidOf<String> releaseGroup;
  final MbidOf<String> release;
  final Duration duration;
  final CoverArtData coverArtData;
  final DateTime releaseDate;

  const QueuedTrackInfo({
    @required String mbid,
    @required this.title,
    @required this.artists,
    @required this.releaseGroup,
    @required this.release,
    this.duration,
    @required this.coverArtData,
    this.releaseDate,
  }) : super(mbid, MbidType.recording);

  QueuedTrackInfo.ofReleaseTrackInfo(ReleaseGroupInfo releaseInfo,
      ReleaseTrackInfo trackInfo)
      : this(
    mbid: trackInfo.mbid,
    title: trackInfo.title,
    artists: trackInfo.artists,
    releaseGroup: MbidOf.copy(releaseInfo, releaseInfo.title),
    release: null,
    // TODO
    duration: trackInfo.duration,
    coverArtData: releaseInfo.coverArtData,
    releaseDate: releaseInfo.releaseDate,
  );
}

class ReleaseTrackInfo extends Mbid {
  final String title;
  final int trackNumber;
  final List<MbidOf<String>> artists;
  final Duration duration;

  const ReleaseTrackInfo({@required String mbid,
    @required String title,
    @required List<MbidOf<String>> artists,
    int trackNumber,
    Duration duration})
      : title = title,
        artists = artists,
        trackNumber = trackNumber,
        duration = duration,
        super(mbid, MbidType.recording);
}

class ReleaseInfo extends Mbid {
  final String title;
  final List<MbidOf<String>> artists;
  final List<ReleaseTrackInfo> tracks;
  final CoverArtData coverArtData;
  final Duration duration;
  final String description;
  final DateTime releaseDate;

  const ReleaseInfo({@required String mbid,
    @required String title,
    @required List<MbidOf<String>> artists,
    @required List<ReleaseTrackInfo> tracks,
    @required CoverArtData coverArtData,
    Duration duration,
    String description,
    DateTime releaseDate})
      : title = title,
        artists = artists,
        tracks = tracks,
        coverArtData = coverArtData,
        duration = duration,
        description = description,
        releaseDate = releaseDate,
        super(mbid, MbidType.release);
}

class ReleaseGroupReleaseInfo extends Mbid {
  final String title;
  final String status;
  final String packaging;
  final String country;
  final DateTime releaseDate;

  const ReleaseGroupReleaseInfo({@required String mbid,
    @required String title,
    @required String status,
    @required String packaging,
    @required String country,
    @required DateTime releaseDate})
      : title = title,
        status = status,
        packaging = packaging,
        country = country,
        releaseDate = releaseDate,
        super(mbid, MbidType.release);
}

class ReleaseGroupInfo extends Mbid {
  final String title;
  final ReleaseGroupType type;
  final DateTime releaseDate;
  final List<MbidOf<String>> artists;
  final List<ReleaseGroupReleaseInfo> releases;
  final CoverArtData coverArtData;

  const ReleaseGroupInfo({@required String mbid,
    @required String title,
    @required ReleaseGroupType type,
    @required DateTime releaseDate,
    @required List<MbidOf<String>> artists,
    @required List<ReleaseGroupReleaseInfo> releases,
    @required CoverArtData coverArtData})
      : title = title,
        type = type,
        releaseDate = releaseDate,
        artists = artists,
        releases = releases,
        coverArtData = coverArtData,
        super(mbid, MbidType.releaseGroup);

  int mapStatus(ReleaseGroupReleaseInfo release) {
    return -(const <String>[
      "pseudo-release",
      "bootleg",
      "promotion",
      "official",
    ]).indexOf(release.status?.toLowerCase());
  }

  int mapTitle(ReleaseGroupReleaseInfo release) {
    return release.title == title ? 0 : 1;
  }

  int mapCountry(ReleaseGroupReleaseInfo release) {
    return -(const <String>[
      "JP",
      "XE",
      "GB",
      "US",
      "XW",
    ]).indexOf(release.country?.toUpperCase());
  }

  int mapReleaseDate(ReleaseGroupReleaseInfo release) {
    return release.releaseDate?.millisecondsSinceEpoch ?? 9223372036854775807;
  }

  ReleaseGroupReleaseInfo selectBestRelease() {
    List<ReleaseGroupReleaseInfo> listClone = List.from(releases);
    listClone.sort((a, b) {
      for (var mapper in <int Function(ReleaseGroupReleaseInfo)>[
        mapStatus,
        mapTitle,
        mapCountry,
        mapReleaseDate,
      ]) {
        int mapA = mapper.call(a),
            mapB = mapper.call(b);
        if (mapA != mapB) {
          return mapA - mapB;
        }
      }
      return 0;
    });
    return listClone.isNotEmpty ? listClone[0] : null;
  }
}

class ReleaseGroupSearchResult extends Mbid {
  final String title;
  final List<MbidOf<String>> artists;
  final List<Mbid> releaseMbids;
  final CoverArtData coverArtData;
  final ReleaseGroupType primaryType;
  final List<String> secondaryTypes;
  final int searchScore;

  ReleaseGroupSearchResult({@required String mbid,
    @required String title,
    @required List<MbidOf<String>> artists,
    @required List<Mbid> releaseMbids,
    @required CoverArtData coverArtData,
    ReleaseGroupType primaryType,
    List<String> secondaryTypes,
    int searchScore})
      : title = title,
        artists = artists,
        releaseMbids = releaseMbids,
        coverArtData = coverArtData,
        primaryType = primaryType,
        secondaryTypes = secondaryTypes ?? List(),
        searchScore = searchScore,
        super(mbid, MbidType.releaseGroup);
}

extension ReleaseGroupSearchResultBestSorter on List<ReleaseGroupSearchResult> {
  int _mapDiscardOtherBroadcast(ReleaseGroupSearchResult result) {
    return result.primaryType == ReleaseGroupType.other ||
        result.primaryType == ReleaseGroupType.broadcast
        ? 1
        : 0;
  }

  int _mapSearchScore(ReleaseGroupSearchResult result) {
    return -result.searchScore;
  }

  int _mapReleaseCount(ReleaseGroupSearchResult result) {
    return -result.releaseMbids.length;
  }

  int _mapPrimaryReleaseType(ReleaseGroupSearchResult result) {
    return -(const <ReleaseGroupType>[
      ReleaseGroupType.other,
      ReleaseGroupType.broadcast,
      ReleaseGroupType.single,
      ReleaseGroupType.ep,
      ReleaseGroupType.album,
    ].indexOf(result.primaryType));
  }

  List<ReleaseGroupSearchResult> _sorted(
      List<ReleaseGroupSearchResult> results) {
    List<ReleaseGroupSearchResult> listClone = List.from(results);
    listClone.sort((a, b) {
      for (var mapper in <int Function(ReleaseGroupSearchResult)>[
        _mapDiscardOtherBroadcast,
        _mapReleaseCount,
        _mapSearchScore,
        _mapPrimaryReleaseType,
      ]) {
        int mapA = mapper.call(a),
            mapB = mapper.call(b);
        if (mapA != mapB) {
          return mapA - mapB;
        }
      }
      return 0;
    });
    return listClone;
  }

  List<ReleaseGroupSearchResult> sortedByBest() {
    return _sorted(this);
  }
}

class YoutubeSearchResult {
  String title, uri, uploader;
  int duration, views, rank;

  YoutubeSearchResult({this.title,
    this.uri,
    this.duration,
    this.views,
    this.uploader,
    this.rank});

  YoutubeSearchResult.fromJson(dynamic json, int rank)
      : this(
      title: json["title"],
      uri: json["uri"],
      duration: json["duration"],
      views: json["views"],
      uploader: json["uploader"],
      rank: rank);
}

extension YoutubeSearchResultBestSorter on List<YoutubeSearchResult> {
  int _mapRemovePlaylists(YoutubeSearchResult result,
      QueuedTrackInfo trackInfo) {
    return result.uri.contains("/playlist") ? 1 : 0;
  }

  int _mapUploader(YoutubeSearchResult result, QueuedTrackInfo trackInfo) {
    if (result.uploader == trackInfo.artists.first.value) {
      return 0;
    } else if (result.uploader.contains(trackInfo.artists.first.value)) {
      return 1;
    } else {
      return 2;
    }
  }

  int _mapRemoveDerivatives(YoutubeSearchResult result,
      QueuedTrackInfo trackInfo) {
    int count = 0;
    for (String keyword in const <String>[
      "mix", // also gets "remix"
      "instrumental",
      "clean",
      "live",
      "at", // live shows
      "@", // also live shows
      "cover",
      "video", // mostly here for "music video"
    ]) {
      if (!trackInfo.title.toLowerCase().contains(keyword) &&
          !trackInfo.artists.first.value.toLowerCase().contains(keyword) &&
          !trackInfo.releaseGroup.value.toLowerCase().contains(keyword)) {
        if (result.title.toLowerCase().contains(keyword)) {
          count++;
        }
      }
    }
    return count;
  }

  int _mapDuration(YoutubeSearchResult result, QueuedTrackInfo trackInfo) {
    return ((result.duration - trackInfo.duration.inSeconds).abs() / 5).round();
  }

  List<YoutubeSearchResult> _sorted(List<YoutubeSearchResult> results,
      QueuedTrackInfo trackInfo) {
    List<YoutubeSearchResult> listClone = List.from(results);
    listClone.sort((a, b) {
      for (var mapper in <int Function(YoutubeSearchResult, QueuedTrackInfo)>[
        _mapRemovePlaylists,
        _mapRemoveDerivatives,
        _mapDuration,
        _mapUploader,
      ]) {
        int mapA = mapper.call(a, trackInfo),
            mapB = mapper.call(b, trackInfo);
        if (mapA != mapB) {
          return mapA - mapB;
        }
      }
      return 0;
    });
    return listClone;
  }

  YoutubeSearchResult selectBest(QueuedTrackInfo trackInfo) {
//    for (YoutubeSearchResult result in this) {
//      print("regular search result: ${result.title}, ${result.uri}");
//    }
    List<YoutubeSearchResult> sorted = _sorted(this, trackInfo);
//    for (YoutubeSearchResult result in sorted) {
//      print("sorted search result: ${result.title}, ${result.uri}");
//    }

    return sorted.isNotEmpty ? sorted[0] : null;
  }
}

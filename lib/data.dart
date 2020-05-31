import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

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

class ReleaseTrackInfo extends Mbid {
  final String title;
  final int trackNumber;
  final List<MbidOf<String>> artists;
  final Duration duration;

  const ReleaseTrackInfo(
      {@required String mbid,
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
  final Uri coverArtUri;
  final Duration duration;
  final String description;
  final DateTime releaseDate;

  const ReleaseInfo(
      {@required String mbid,
      @required String title,
      @required List<MbidOf<String>> artists,
      @required List<ReleaseTrackInfo> tracks,
      Uri albumArtUri,
      Duration duration,
      String description,
      DateTime releaseDate})
      : title = title,
        artists = artists,
        tracks = tracks,
        coverArtUri = albumArtUri,
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

  const ReleaseGroupReleaseInfo(
      {@required String mbid,
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
  final Uri coverArtUri;

  const ReleaseGroupInfo(
      {@required String mbid,
      @required String title,
      @required ReleaseGroupType type,
      @required DateTime releaseDate,
      @required List<MbidOf<String>> artists,
      @required List<ReleaseGroupReleaseInfo> releases,
      Uri coverArtUri})
      : title = title,
        type = type,
        releaseDate = releaseDate,
        artists = artists,
        releases = releases,
        coverArtUri = coverArtUri,
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
        int mapA = mapper.call(a), mapB = mapper.call(b);
        if (mapA != mapB) {
          return mapA - mapB;
        }
      }
      return 0;
    });
    return listClone[0];
  }
}

class ReleaseGroupSearchResult extends Mbid {
  final String title;
  final List<MbidOf<String>> artists;
  final List<Mbid> releaseMbids;
  final Uri coverArtUri;
  final ReleaseGroupType primaryType;
  final List<String> secondaryTypes;
  final int searchScore;

  ReleaseGroupSearchResult(
      {@required String mbid,
      @required String title,
      @required List<MbidOf<String>> artists,
      @required List<Mbid> releaseMbids,
      Uri coverArtUri,
      ReleaseGroupType primaryType,
      List<String> secondaryTypes,
      int searchScore})
      : title = title,
        artists = artists,
        releaseMbids = releaseMbids,
        coverArtUri = coverArtUri,
        primaryType = primaryType,
        secondaryTypes = secondaryTypes ?? List(),
        searchScore = searchScore,
        super(mbid, MbidType.releaseGroup);
}

class ReleaseGroupSearchResultSorter {}

extension ReleaseGroupSearhResultBestSorter on List<ReleaseGroupSearchResult> {
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
        int mapA = mapper.call(a), mapB = mapper.call(b);
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

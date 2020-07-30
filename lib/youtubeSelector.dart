import 'util.dart';
import 'data.dart';

extension YoutubeSorterMach1 on List<YoutubeSearchResult> {
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

  List<YoutubeSearchResult> sortedMach1(QueuedTrackInfo trackInfo) {
    List<YoutubeSearchResult> listClone = List.from(this);
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
}

List<String> _findWords(String text) {
  return text.split(new RegExp(r"\W+"));
}

extension YoutubeSorterMach2 on List<YoutubeSearchResult> {
  double _durationHeuristic(YoutubeSearchResult result,
      QueuedTrackInfo trackInfo) {
    return (result.duration - trackInfo.duration.inSeconds).abs().toDouble();
  }

  double _derivativesHeuristic(YoutubeSearchResult result, QueuedTrackInfo trackInfo) {
    return <Pair<String, double>>[
      Pair("mix", 1), // also gets "remix"
      Pair("instrumental", 1),
      Pair("clean", 1),
      Pair("live", 1),
      Pair("at", 1), // live shows
      Pair("@", 1), // also live shows
      Pair("cover", 1),
      Pair("video", 1), // mostly here for "music video"
    ].map<double>((pair) {
      if (!trackInfo.title.toLowerCase().contains(pair.left) &&
          !trackInfo.artists.first.value.toLowerCase().contains(pair.left) &&
          !trackInfo.releaseGroup.value.toLowerCase().contains(pair.left)) {
        if (result.title.toLowerCase().contains(pair.left)) {
         return pair.right;
        }
      }
      return 0.0;
    }).fold(0.0, (acc, next) => acc + next);
  }

  double _compositeHeuristic(YoutubeSearchResult result,
      QueuedTrackInfo trackInfo) {
    return <
        Pair<double Function(YoutubeSearchResult, QueuedTrackInfo), double>>[
      Pair(_durationHeuristic, 1),
      Pair(_derivativesHeuristic, 1),
    ]
        .fold(
        0, (acc, pair) => acc + pair.right * pair.left(result, trackInfo));
  }

  List<YoutubeSearchResult> sortedMach2(QueuedTrackInfo trackInfo) {
    List<YoutubeSearchResult> listClone = List.from(this);
    listClone.sort((a, b) {
      var diff =
          _compositeHeuristic(a, trackInfo) - _compositeHeuristic(b, trackInfo);
      return diff < 0 ? -1 : diff > 0 ? 1 : 0;
    });
    return listClone;
  }
}

extension YoutubeSearchResultBestSorter on List<YoutubeSearchResult> {
  YoutubeSearchResult selectBest(QueuedTrackInfo trackInfo) {
//    for (YoutubeSearchResult result in this) {
//      print("regular search result: ${result.title}, ${result.uri}");
//    }
    List<YoutubeSearchResult> sorted = sortedMach1(trackInfo);
//    for (YoutubeSearchResult result in sorted) {
//      print("sorted search result: ${result.title}, ${result.uri}");
//    }

    return sorted.isNotEmpty ? sorted[0] : null;
  }
}

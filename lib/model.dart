import 'dart:collection';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data.dart';

/// Number of tracks to buffer in advance. Must be >= 2.
const int BUFFER_AHEAD = 5;

class DownloadedOnlyModel extends ChangeNotifier {
  bool _downloadedOnly = false;

  bool get downloadedOnly => _downloadedOnly;

  set downloadedOnly(bool value) {
    _downloadedOnly = value;
    notifyListeners();
  }

  void toggle() {
    downloadedOnly = !_downloadedOnly;
  }
}

class MainPageIndexModel extends ChangeNotifier {
  int _mainPageIndex = 0;

  int get mainPageIndex => _mainPageIndex;

  set mainPageIndex(int value) {
    _mainPageIndex = value;
    notifyListeners();
  }
}

class QueueModel extends ChangeNotifier {
  List<QueuedTrackInfo> _queuedTracks;
  int _currentlyPlayingIndex;
  bool _isPlaying;

  Map<String, Future<String>> _streamUris;

  bool get isPlaying => _isPlaying;

  bool get hasQueue => _queuedTracks.isNotEmpty;

  QueuedTrackInfo get currentTrack =>
      hasQueue ? _queuedTracks[_currentlyPlayingIndex] : null;

  QueueModel() {
    _queuedTracks = List();
    _currentlyPlayingIndex = 0;
    _isPlaying = false;

    _streamUris = Map();

    _PlaybackManager().setCallbacks({
      "onPlay": () {
        _isPlaying = true;
        notifyListeners();
      },
      "onPause": () {
        _isPlaying = false;
        notifyListeners();
      },
      "onNextTrack": () {
        _currentlyPlayingIndex++;
        notifyListeners();
        _updatePlaybackManagerQueue();
      },
    });
  }

  set isPlaying(bool playing) {
    if (_queuedTracks.isNotEmpty) {
      if (!_isPlaying && playing) {
        _PlaybackManager().play();
      } else if (_isPlaying && !playing) {
        _PlaybackManager().pause();
      }
    }
  }

  int get currentlyPlayingIndex => _currentlyPlayingIndex;

  void togglePlaying() {
    isPlaying = !_isPlaying;
  }

  List<QueuedTrackInfo> get queuedTracks => UnmodifiableListView(_queuedTracks);

  Future<void> _updatePlaybackManagerQueue({resetCurrent: false}) {
    List<QueuedTrackInfo> toSubmit = _queuedTracks.sublist(
        _currentlyPlayingIndex,
        math.min(_currentlyPlayingIndex + BUFFER_AHEAD, _queuedTracks.length));

    for (var trackInfo in toSubmit) {
      if (!_streamUris.containsKey(trackInfo)) {
        _streamUris[trackInfo.mbid] = _PlaybackManager()
            .searchYoutube(
                "${trackInfo.title} ${trackInfo.artists.first.value} ${trackInfo.releaseGroup.value}")
            .then((results) => results.selectBest(trackInfo).uri);
      }
    }

    for (var staleTrack in Set<String>.from(_streamUris.keys).difference(
        Set<String>.from(
            toSubmit.map((trackInfo) => trackInfo.mbid)))) {
      _streamUris.remove(staleTrack);
    }

    Iterable<Future<String>> futures = toSubmit
        .map<Future<String>>((trackInfo) => _streamUris[trackInfo.mbid]);

    Future<void> all =
        Future.wait(futures).then((uris) => _PlaybackManager().setQueue(uris));

    if (toSubmit.isNotEmpty) {
      // load the first track, then come back and load the subsequent tracks
      return futures.first.then((firstUri) => _PlaybackManager().setQueue(
          [firstUri],
          sweep: false, resetCurrent: resetCurrent).then((_) => all));
    } else {
      return all;
    }
  }

  Future<void> addAllToQueue(Iterable<QueuedTrackInfo> trackInfo,
      {startIndex = 0}) {
    _queuedTracks.addAll(trackInfo);
    _currentlyPlayingIndex = startIndex;
    notifyListeners();
    return _updatePlaybackManagerQueue();
  }

  Future<void> addToQueue(QueuedTrackInfo trackInfo) {
    return addAllToQueue([trackInfo]);
  }

  Future<void> playAllNext(Iterable<QueuedTrackInfo> trackInfo) {
    _queuedTracks.insertAll(_currentlyPlayingIndex + 1, trackInfo);
    notifyListeners();
    return _updatePlaybackManagerQueue();
  }

  Future<void> playNext(QueuedTrackInfo trackInfo) {
    return playAllNext([trackInfo]);
  }

  Future<void> clearQueue() {
    _queuedTracks.clear();
    _currentlyPlayingIndex = 0;
    notifyListeners();
    return _updatePlaybackManagerQueue();
  }

  Future<void> setQueue(Iterable<QueuedTrackInfo> trackInfo, {startIndex = 0}) {
    var trackInfoList = trackInfo.toList();
    var resetCurrent = _queuedTracks.isNotEmpty &&
        _queuedTracks[_currentlyPlayingIndex].mbid ==
            trackInfoList[startIndex].mbid;
    _queuedTracks.clear();
    _queuedTracks.addAll(trackInfoList);
    _currentlyPlayingIndex = startIndex;
    notifyListeners();
    return _updatePlaybackManagerQueue(resetCurrent: resetCurrent);
//    return clearQueue()
//        .then((_) => addAllToQueue(trackInfo, startIndex: startIndex));
  }
}

class _PlaybackManager {
  static const _platform =
      const MethodChannel("com.calsignlabs.music/playback");
  static const _status = const MethodChannel("com.calsignlabs.music/status");

  static _PlaybackManager _instance;

  int statusCounter = 0;

  factory _PlaybackManager() {
    if (_instance == null) {
      _instance = _PlaybackManager._();
    }
    return _instance;
  }

  _PlaybackManager._();

  void setCallbacks(Map<String, void Function()> callbacks) {
    _status.setMethodCallHandler((call) {
      // not sure if this bit is necessary
      int newCounter = call.arguments as int;
      if (newCounter > statusCounter) {
        statusCounter = newCounter;
        void Function() callback = callbacks[call.method];
        if (callback != null) {
          callback();
        } else {
          throw Exception(
              "Tried to invoke non-existent status method: ${call.method}");
        }
      }
      return Future.value(null);
    });
  }

  Future<T> _invokePlatformMethod<T>(String method, [dynamic arguments]) async {
    try {
      return await _platform.invokeMethod(method, arguments);
    } on PlatformException catch (e) {
      print("Failed to invoke method $method, exception: ${e.message}");
      return null;
    }
  }

  // not currently used
  Future<String> getYoutubeStreamUri(String youtubeUri) =>
      _invokePlatformMethod("getYoutubeStreamUri", {"uri": youtubeUri});

  Future<void> setQueue(List<String> queue,
          {bool sweep = true, bool resetCurrent = false}) =>
      _invokePlatformMethod("setQueue",
          {"queue": queue, "sweep": sweep, "resetCurrent": resetCurrent});

  Future<List<YoutubeSearchResult>> searchYoutube(String query) {
    return _invokePlatformMethod("searchYoutube", {"query": query}).then(
        (results) => results
            ?.asMap()
            ?.entries
            ?.map<YoutubeSearchResult>(
                (entry) => YoutubeSearchResult.fromJson(entry.value, entry.key))
            ?.toList());
  }

  Future<void> play() => _invokePlatformMethod("play");

  Future<void> pause() => _invokePlatformMethod("pause");
}

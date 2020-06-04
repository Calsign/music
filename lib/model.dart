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

    _PlaybackManager().setCallbacks("queueModel", {
      "onPlay": (args) {
        _isPlaying = true;
        notifyListeners();
      },
      "onPause": (args) {
        _isPlaying = false;
        notifyListeners();
      },
      "onNextTrack": (args) {
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

  Future<void> _updatePlaybackManagerQueue(
      {resetCurrent: false, startIfPaused: true}) {
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
        Set<String>.from(toSubmit.map((trackInfo) => trackInfo.mbid)))) {
      _streamUris.remove(staleTrack);
    }

    Iterable<Future<String>> futures = toSubmit
        .map<Future<String>>((trackInfo) => _streamUris[trackInfo.mbid]);

    Future<void> all = Future.wait(futures).then((uris) =>
        _PlaybackManager().setQueue(uris, startIfPaused: startIfPaused));

    if (toSubmit.isNotEmpty) {
      // load the first track, then come back and load the subsequent tracks
      return futures.first.then((firstUri) => _PlaybackManager().setQueue(
          [firstUri],
          sweep: false,
          resetCurrent: resetCurrent,
          startIfPaused: startIfPaused).then((_) => all));
    } else {
      return all;
    }
  }

  Future<void> addAllToQueue(Iterable<QueuedTrackInfo> trackInfo) {
    _queuedTracks.addAll(trackInfo);
    notifyListeners();
    return _updatePlaybackManagerQueue(
        resetCurrent: false, startIfPaused: false);
  }

  Future<void> addToQueue(QueuedTrackInfo trackInfo) {
    return addAllToQueue([trackInfo]);
  }

  Future<void> playAllNext(Iterable<QueuedTrackInfo> trackInfo) {
    _queuedTracks.insertAll(_currentlyPlayingIndex + 1, trackInfo);
    notifyListeners();
    return _updatePlaybackManagerQueue(
        resetCurrent: false, startIfPaused: false);
  }

  Future<void> playNext(QueuedTrackInfo trackInfo) {
    return playAllNext([trackInfo]);
  }

  Future<void> skipTo(int pos) {
    if (pos >= 0 && pos < _queuedTracks.length) {
      _currentlyPlayingIndex = pos;
      notifyListeners();
      return _updatePlaybackManagerQueue(
          resetCurrent: true, startIfPaused: true);
    } else {
      return Future.value(null);
    }
  }

  Future<void> skipNext() {
    return skipTo(_currentlyPlayingIndex + 1);
  }

  Future<void> skipPrev(PlaybackProgressModel progressModel) {
    if (progressModel.position < 5000 && _currentlyPlayingIndex > 0) {
      // if in the first 5 seconds
      return skipTo(_currentlyPlayingIndex - 1);
    } else {
      return progressModel.skipTo(0);
    }
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
  }

  Future<void> removeFromQueue(int removeIndex) {
    if (removeIndex >= 0 && removeIndex < _queuedTracks.length) {
      _queuedTracks.removeAt(removeIndex);
      if (removeIndex < _currentlyPlayingIndex) {
        _currentlyPlayingIndex--;
      }
      if (_queuedTracks.isEmpty) {
        _isPlaying = false;
      }
      notifyListeners();
      return _updatePlaybackManagerQueue(
          resetCurrent: false, startIfPaused: false);
    } else {
      return Future.value(null);
    }
  }
}

class PlaybackProgressModel extends ChangeNotifier {
  int _position, _totalDuration;

  int get position => _position;

  int get totalDuration => _totalDuration;

  double get playbackFraction => totalDuration == 0
      ? 0.0
      : math.max(math.min(position / totalDuration, 1.0), 0.0);

  PlaybackProgressModel() {
    _position = 0;
    _totalDuration = 0;

    _PlaybackManager().setCallbacks("playbackProgressModel", {
      "playbackProgressUpdate": (args) {
        _position = args["position"];
        _totalDuration = args["totalDuration"];
        if (_position == -1 || _totalDuration == -1) {
          _position = 0;
          _totalDuration = 0;
        }
        notifyListeners();
      },
    });
  }

  Future<void> skipTo(int position) {
    _position = position;
    return _PlaybackManager().skipTo(position);
  }
}

class PlaybackDeviceModel extends ChangeNotifier {
  List<PlaybackDevice> _devices;
  String _selectedDevice;

  List<PlaybackDevice> get devices => _devices;

  String get selectedDevice => _selectedDevice;

  PlaybackDeviceModel() {
    _devices = List();

    _PlaybackManager().setCallbacks("playbackDeviceModel", {
      "playbackDevices": (devices) {
        _devices = devices
            .map<PlaybackDevice>((json) => PlaybackDevice.fromJson(json)).toList();
        notifyListeners();
      },
      "selectedPlaybackDevice": (selectedDevice) {
        _selectedDevice = selectedDevice;
        notifyListeners();
      },
    });
  }

  Future<void> startSearch() => _PlaybackManager().startDeviceSearch();

  Future<void> stopSearch() => _PlaybackManager().stopDeviceSearch();

  Future<void> selectDevice(String deviceId) =>
      _PlaybackManager().selectDevice(deviceId);
}

class _PlaybackManager {
  static const _platform =
      const MethodChannel("com.calsignlabs.music/playback");
  static const _status = const MethodChannel("com.calsignlabs.music/status");

  static _PlaybackManager _instance;

  Map<String, Map<String, void Function(dynamic)>> _callbacks;

  factory _PlaybackManager() {
    if (_instance == null) {
      _instance = _PlaybackManager._();
    }
    return _instance;
  }

  _PlaybackManager._() {
    _callbacks = {};
    _status.setMethodCallHandler((call) {
      void Function(dynamic) callback;
      for (var map in _callbacks.values) {
        callback = map[call.method];
        if (callback != null) {
          break;
        }
      }
      if (callback != null) {
        callback(call.arguments);
      } else {
        throw Exception(
            "Tried to invoke non-existent status method: ${call.method}");
      }
      return Future.value(null);
    });
  }

  void setCallbacks(String key, Map<String, void Function(dynamic)> callbacks) {
    this._callbacks[key] = callbacks;
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
          {bool sweep = true,
          bool resetCurrent = false,
          bool startIfPaused = true}) =>
      _invokePlatformMethod("setQueue", {
        "queue": queue,
        "sweep": sweep,
        "resetCurrent": resetCurrent,
        "startIfPaused": startIfPaused
      });

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

  Future<void> skipTo(int position) =>
      _invokePlatformMethod("skipTo", {"position": position});

  Future<void> startDeviceSearch() =>
      _invokePlatformMethod("startPlaybackDeviceSearch");

  Future<void> stopDeviceSearch() =>
      _invokePlatformMethod("stopPlaybackDeviceSearch");

  Future<void> selectDevice(String deviceId) =>
      _invokePlatformMethod("selectPlaybackDevice", {"device": deviceId});
}

import 'dart:collection';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'util.dart';
import 'data.dart';
import 'youtubeSelector.dart';

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
  bool _isPlaying, _isBuffering;

  Map<String, Future<String>> _streamUris;

  bool get isPlaying => _isPlaying;

  bool get isBuffering => _isBuffering;

  bool get hasQueue => _queuedTracks.isNotEmpty;

  QueuedTrackInfo get currentTrack => hasQueue && _currentlyPlayingIndex != -1
      ? _queuedTracks[_currentlyPlayingIndex]
      : null;

  QueueModel() {
    _queuedTracks = List();
    _currentlyPlayingIndex = 0;
    _isPlaying = false;
    _isBuffering = false;

    _streamUris = Map();

    _PlaybackManager().setCallbacks("queueModel", {
      "onPlay": (args) {
        _isPlaying = true;
        _isBuffering = false;
        notifyListeners();
      },
      "onPause": (args) {
        _isPlaying = false;
        _isBuffering = false;
        notifyListeners();
      },
      "onBuffering": (args) {
        _isBuffering = true;
        notifyListeners();
      },
      "onTrackChange": (args) {
        var newTrack = args as String;
        // TODO this seems highly error prone
        if (queuedTracks.isEmpty ||
            newTrack != queuedTracks[_currentlyPlayingIndex].mbid) {
          _currentlyPlayingIndex = queuedTracks
              .indexWhere((trackInfo) => trackInfo.mbid == newTrack);
          notifyListeners();
          //_updatePlaybackManagerQueue();
        }
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

  Future<Pair<String, String>> fetchStreamUri(QueuedTrackInfo trackInfo) {
    return _PlaybackManager()
        .searchYoutube(
            "${trackInfo.title} ${trackInfo.artists.first.value} ${trackInfo.releaseGroup.value}")
        .then((results) => _PlaybackManager()
            .getYoutubeStreamUri(results.selectBest(trackInfo).uri)
            .then((remoteUri) => Pair(trackInfo.mbid, remoteUri)));
  }

  Future<void> _performSet(
      Iterable<QueuedTrackInfo> trackInfo, int startIndex) {
    // TODO implement startIndex
    if (trackInfo.length == 0) {
      return _PlaybackManager().queueSet([], startIndex);
    } else {
      // set the first one and insert the rest when they are loaded
      return fetchStreamUri(trackInfo.first).then((pair) => _PlaybackManager()
          .queueSet(
              [pair], 0).then((_) => _performInsert(trackInfo.skip(1), 1)));
    }
  }

  Future<void> _performInsert(Iterable<QueuedTrackInfo> trackInfo, int index) {
    if (trackInfo.isEmpty) {
      return Future.value(null);
    } else {
      return fetchStreamUri(trackInfo.first).then((pair) => _PlaybackManager()
          .queueInsert([pair], index).then(
              (_) => _performInsert(trackInfo.skip(1), index + 1)));
    }
  }

  Future<void> addAllToQueue(Iterable<QueuedTrackInfo> trackInfo) {
    _queuedTracks.addAll(trackInfo);
    notifyListeners();
    return _performInsert(trackInfo, _queuedTracks.length - trackInfo.length);
  }

  Future<void> addToQueue(QueuedTrackInfo trackInfo) {
    return addAllToQueue([trackInfo]);
  }

  Future<void> playAllNext(Iterable<QueuedTrackInfo> trackInfo) {
    _queuedTracks.insertAll(_currentlyPlayingIndex + 1, trackInfo);
    notifyListeners();
    return _performInsert(trackInfo, _currentlyPlayingIndex + 1);
  }

  Future<void> playNext(QueuedTrackInfo trackInfo) {
    return playAllNext([trackInfo]);
  }

  Future<void> skipTo(int pos) {
    if (pos >= 0 && pos < _queuedTracks.length) {
      _currentlyPlayingIndex = pos;
      notifyListeners();
      return _PlaybackManager().queueSelect(pos);
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
    return _performSet(<QueuedTrackInfo>[], 0);
  }

  Future<void> setQueue(Iterable<QueuedTrackInfo> trackInfo, {startIndex = 0}) {
    _queuedTracks.clear();
    _queuedTracks.addAll(trackInfo);
    _currentlyPlayingIndex = startIndex;
    notifyListeners();
    return _performSet(trackInfo, startIndex);
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
      return _PlaybackManager().queueRemove(removeIndex, 1);
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
            .map<PlaybackDevice>((json) => PlaybackDevice.fromJson(json))
            .toList();
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

  Future<List<YoutubeSearchResult>> searchYoutube(String query) {
    return _invokePlatformMethod("searchYoutube", {"query": query}).then(
        (results) => results
            ?.asMap()
            ?.entries
            ?.map<YoutubeSearchResult>(
                (entry) => YoutubeSearchResult.fromJson(entry.value, entry.key))
            ?.toList());
  }

  /// note: returned URI has expiration time (in seconds since the epoch)
  /// encoded; appears to be six hours after the URI was obtained.
  /// we may want to fetch a new URI before the expiration.
  Future<String> getYoutubeStreamUri(String youtubeUri) =>
      _invokePlatformMethod("getYoutubeStreamUri", {"uri": youtubeUri});

  List<Map<String, dynamic>> packQueueItems(
      Iterable<Pair<String, String>> items) {
    return items
        .map<Map<String, dynamic>>((item) => {
              "id": item.left,
              "localUri": null,
              "remoteUri": item.right,
            })
        .toList();
  }

  Future<void> queueSet(Iterable<Pair<String, String>> items, int startIndex) {
    return _invokePlatformMethod(
        "queueSet", {"items": packQueueItems(items), "startIndex": startIndex});
  }

  Future<void> queueInsert(Iterable<Pair<String, String>> items, int index) {
    return _invokePlatformMethod(
        "queueInsert", {"items": packQueueItems(items), "index": index});
  }

  Future<void> queueRemove(int startIndex, int length) {
    return _invokePlatformMethod(
        "queueRemove", {"startIndex": startIndex, "length": length});
  }

  Future<void> queueMove(int fromIndex, int toIndex) {
    return _invokePlatformMethod(
        "queueMove", {"fromIndex": fromIndex, "toIndex": toIndex});
  }

  Future<void> queueSelect(int index) {
    return _invokePlatformMethod("queueSelect", {"index": index});
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

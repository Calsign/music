import 'package:flutter/material.dart';

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

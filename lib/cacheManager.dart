import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CustomCacheManager extends BaseCacheManager {
  static const key = "customCache";

  static CustomCacheManager _instance;

  factory CustomCacheManager() {
    if (_instance == null) {
      _instance = CustomCacheManager._();
    }
    return _instance;
  }

  CustomCacheManager._()
      : super(key,
      maxAgeCacheObject: Duration(days: 7),
      maxNrOfCacheObjects: 200,
      fileFetcher: _customHttpGetter);

  @override
  Future<String> getFilePath() async {
    var directory = await getTemporaryDirectory();
    return path.join(directory.path, key);
  }

  static Future<FileFetcherResponse> _customHttpGetter(String url, {Map<String, String> headers}) async {
    try {
      var res;
      var times = 0;
      while (res == null || res.statusCode == 503) {
        if (times > 0) {
          print("Rate limited! Waiting ${times * 500} milliseconds...");
          await Future.delayed(Duration(milliseconds: 500 * times));
        }
        res = await http.get(url, headers: headers);
        times += 1;
      }
      res.headers.addAll({"cache-control": "private, max-age=120"});
      return HttpFileFetcherResponse(res);
    } on SocketException {
      print("Socket exception, no internet?");
      return null;
    }
  }
}

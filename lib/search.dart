import 'dart:async';
import 'dart:isolate';

import 'util.dart';
import 'data.dart';
import 'lastfm.dart';

void performSearch(Triple<String, int, SendPort> message) {
  searchAlbum(message.left)
      .then((result) => message.right.send(Pair(result, message.middle)));
}

Stream<List<AlbumSearchResult>> searchStream(Stream<String> queryStream) {
  StreamController<List<AlbumSearchResult>> controller = StreamController();

  int counter = 0;
  Pair<List<AlbumSearchResult>, int> latest;

  ReceivePort receivePort = ReceivePort();
  receivePort.listen((pair) {
    if (pair is Pair<List<AlbumSearchResult>, int> &&
        (latest == null || pair.right > latest.right)) {
      latest = pair;
      controller.add(latest.left);
    }
  });

  queryStream.listen(
      (query) => Isolate.spawn(
          performSearch, Triple(query, counter++, receivePort.sendPort)),
      onDone: () => controller.close());

  return controller.stream;
}

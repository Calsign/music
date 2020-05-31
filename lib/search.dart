import 'dart:async';
import 'dart:isolate';

import 'util.dart';
import 'data.dart';
import 'musicbrainz.dart';

void performSearch(Triple<String, int, SendPort> message) {
  searchReleaseGroup(message.left)
      .then((result) => message.right.send(Pair(result, message.middle)));
}

Stream<List<ReleaseGroupSearchResult>> searchStream(Stream<String> queryStream) {
  StreamController<List<ReleaseGroupSearchResult>> controller = StreamController();

  int counter = 0;
  Pair<List<ReleaseGroupSearchResult>, int> latest;

  ReceivePort receivePort = ReceivePort();
  receivePort.listen((pair) {
    if (pair is Pair<List<ReleaseGroupSearchResult>, int> &&
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

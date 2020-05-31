class Pair<L, R> {
  final L left;
  final R right;

  const Pair(L left, R right)
      : left = left,
        right = right;
}

class Triple<L, M, R> {
  final L left;
  final M middle;
  final R right;

  const Triple(L left, M middle, R right)
      : left = left,
        middle = middle,
        right = right;
}

String durationToString(Duration duration) {
  if (duration == null) {
    return null;
  } else {
    double seconds = duration.inMilliseconds / 1000.0;
    int sec = (seconds % 60).round();
    int min = (seconds / 60).floor();
    if (min < 60) {
      return "$min:${sec.toString().padLeft(2, "0")}";
    } else {
      return "${(min / 60).floor()}:${(min % 60).toString().padLeft(2, "0")}:${sec.toString().padLeft(2, "0")}";
    }
  }
}

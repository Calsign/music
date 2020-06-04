import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'model.dart';
import 'searchScreen.dart';
import 'playbackDeviceSelector.dart';

Iterable<Widget> _actions(BuildContext context) {
  return <Widget>[
    Consumer<DownloadedOnlyModel>(
      builder: (context, model, child) => IconButton(
        icon: Icon(Icons.file_download,
            color: model.downloadedOnly
                ? Theme.of(context).accentColor
                : IconTheme.of(context).color),
        tooltip: "Offline Mode",
        onPressed: () => model.toggle(),
      ),
    ),
    IconButton(
      icon: const Icon(Icons.cast),
      tooltip: "Playback Devices",
      onPressed: () => showPlaybackDevicesSelector(context),
    ),
    IconButton(
      icon: const Icon(Icons.search),
      tooltip: "Search",
      onPressed: () => Navigator.of(context).push(SearchOverlay()),
    )
  ];
}

SliverAppBar sliverAppBar(BuildContext context, {Widget title, bool elevated = true}) {
  return SliverAppBar(
    elevation: elevated ? 10.0 : 0.0,
    title: title,
    primary: true,
    floating: true,
    snap: true,
    backgroundColor: Colors.transparent,
    actions: _actions(context),
  );
}

AppBar mainAppBar(BuildContext context, {Widget title, bool elevated = true, Color backgroundColor}) {
  return AppBar(
    elevation: elevated ? 10.0 : 0,
    title: title,
    backgroundColor: backgroundColor ?? Colors.transparent,
    actions: _actions(context),
  );
}

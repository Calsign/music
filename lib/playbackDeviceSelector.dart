import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'support.dart';
import 'model.dart';

class PlaybackDeviceSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 24.0),
        child: Wrap(
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 24.0),
              child: Text(
                "Playback devices",
                style: TextStyle(
                  fontSize: 24.0,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Consumer<PlaybackDeviceModel>(
              builder: (context, model, child) => ScrollConfiguration(
                behavior: NoGlowScrollBehavior(),
                child: Container(
                  height: 400.0, // TODO fix this
                  child: ListView.builder(
                    itemCount: model.devices.length,
                    shrinkWrap: true,
                    itemBuilder: (context, index) => ListTile(
                      title: Text(model.devices[index].name),
                      subtitle: model.devices[index].description != null
                          ? Text(model.devices[index].description)
                          : null,
                      leading: Text(model.devices[index].deviceType.toString()),
                      selected: model.selectedDevice == model.devices[index].id,
                      onTap: () => model.selectDevice(model.devices[index].id),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showPlaybackDevicesSelector(BuildContext context) {
  PlaybackDeviceModel model =
      Provider.of<PlaybackDeviceModel>(context, listen: false);
  model.startSearch();
  return showDialog(
    context: context,
    child: PlaybackDeviceSelector(),
    barrierDismissible: true,
  ).then((_) => model.stopSearch());
}

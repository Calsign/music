import 'package:flutter/material.dart';
import 'package:music/data.dart';

import 'package:provider/provider.dart';

import 'support.dart';
import 'model.dart';

class PlaybackDeviceSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: NoGlowScrollBehavior(),
      child: Consumer<PlaybackDeviceModel>(
        builder: (context, model, child) => SimpleDialog(
            title: Text("Playback devices"),
            children: model.devices
                .map<Widget>((device) => _buildDeviceItem(
                    context: context,
                    device: device,
                    selected: model.selectedDevice == device.id,
                    onSelect: () => model.selectDevice(device.id)))
                .toList()),
      ),
    );
  }
}

IconData _buildDeviceIcon(PlaybackDevice device) {
  switch (device.deviceType) {
    case 0:
      if (device?.description?.contains("Google Cast Group") == true) {
        return Icons.speaker_group;
      } else {
        return Icons.smartphone;
      }
      break;
    case 2:
      return Icons.speaker;
    case 3:
      return Icons.bluetooth_audio;
    default:
      return Icons.device_unknown;
  }
}

Widget _buildDeviceItem(
    {@required BuildContext context,
    @required PlaybackDevice device,
    @required bool selected,
    void Function() onSelect}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onSelect,
      child: Row(
        children: <Widget>[
          Container(
            height: 36.0,
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            alignment: Alignment.center,
            child: Icon(_buildDeviceIcon(device)),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: TextStyle(
                        fontSize: 16.0,
                        color: selected
                            ? Theme.of(context).accentColor
                            : Colors.white),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                  ),
                  SizedBox(height: 4.0),
                  device.description != null
                      ? Text(
                          device.description,
                          style: const TextStyle(
                            fontSize: 14.0,
                            color: Color(0xFFBBBBBB),
                          ),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.fade,
                        )
                      : SizedBox(height: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
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

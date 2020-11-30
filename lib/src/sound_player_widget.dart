import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:provider/provider.dart';

import 'sound_player_model.dart';

class SoundPlayerWidget extends StatefulWidget {
  final String filePath;
  final String fileName;
  final double duration;
  final Codec codec;

  SoundPlayerWidget({@required this.filePath, @required this.fileName, @required this.duration, this.codec: Codec.amrNB});

  @override
  _SoundPlayerWidgetState createState() => _SoundPlayerWidgetState();
}

class _SoundPlayerWidgetState extends State<SoundPlayerWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 35,
      width: 80 + widget.duration * 10.0,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => Provider.of<SoundPlayerModel>(context, listen: false).startOrStopPlayer(
          filePath: widget.filePath,
          fileName: widget.fileName,
          codec: widget.codec,
        ),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Visibility(
              visible: Provider.of<SoundPlayerModel>(context).isCurrentPlaying(filePath: widget.filePath),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 35,
                  value: Provider.of<SoundPlayerModel>(context).currentPlayTime / widget.duration,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade300),
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            Row(
              children: [
                SizedBox(
                  width: 6,
                ),
                Icon(Provider.of<SoundPlayerModel>(context).isCurrentPlaying(filePath: widget.filePath) ? Icons.stop : Icons.play_arrow),
                SizedBox(
                  width: 6,
                ),
                Text('${widget.duration}s'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

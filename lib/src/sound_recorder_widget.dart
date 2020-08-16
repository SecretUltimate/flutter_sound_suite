import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

typedef RecordCompleteObserver = Function(String filePath, String fileName, double length);

///                 AAC_ADS Opus_OGG  Opus_CAF  MP3  Vorbis_OGG  PCM_raw  PCM_WAV  PCM_AIFF  PCM_CAF  FLAC  AAC_MP4 AMR-NB  AMR-WB
///iOS encoder      Yes     Yes(*)    Yes       No   No          No       Yes      No        Yes      Yes   Yes     NO      NO
///iOS decoder      Yes     Yes(*)    Yes       Yes  No          No       Yes      Yes       Yes      Yes   Yes     NO      NO
///Android encoder  Yes     No        No        No   No          Yes      Yes      No        No       No    No      YES     YES
///Android decoder  Yes     Yes       Yes(*)    Yes  Yes         Yes      Yes      Yes(*)    Yes(*)   Yes   Yes     YES     YES

class SoundRecorderWidget extends StatefulWidget {
  final RecordCompleteObserver recordComplete;
  final Codec codec;

  SoundRecorderWidget({@required this.recordComplete, this.codec: Codec.amrNB});

  @override
  _SoundRecorderWidgetState createState() => new _SoundRecorderWidgetState();
}

class _SoundRecorderWidgetState extends State<SoundRecorderWidget> {
  double startY = 0.0;
  double offset = 0.0;
  bool isCancel = false;
  String _buttonHint = '按住 说话';
  String _overLayHint = '上滑 取消';
  String _voiceImage = 'assets/voice/volume_1.png';
  OverlayEntry overlayEntry;
  String _recordTime = '00:00:00';
  bool _isRecording = false;

  FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  StreamSubscription _recorderSubscription;
  double _decibels;
  Codec _codec = Codec.aacADTS;
  String _currentFilePath;
  String _currentFileName;

  init() async {
    _codec = widget.codec;
    await _recorder.openAudioSession(
      focus: AudioFocus.requestFocusTransient,
      category: SessionCategory.playAndRecord,
      mode: SessionMode.modeDefault,
      device: AudioDevice.speaker,
    );
    await _recorder.setSubscriptionDuration(Duration(milliseconds: 10));
    initializeDateFormatting();
  }

  @override
  initState() {
    super.initState();
    init();
  }

  @override
  dispose() {
    super.dispose();
    releaseRecorderSubscriptions();
    releaseRecorder();
  }

  releaseRecorderSubscriptions() {
    if (_recorderSubscription != null) {
      _recorderSubscription.cancel();
      _recorderSubscription = null;
    }
  }

  releaseRecorder() async {
    try {
      await _recorder.closeAudioSession();
    } catch (e) {
      debugPrint('Released unsuccessful');
      debugPrint(e);
    }
  }

  startRecorder() async {
    try {
      PermissionStatus status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw RecordingPermissionException("Microphone permission not granted");
      }

      Directory tempDir = await getTemporaryDirectory();
      _currentFileName = '${Uuid().v4()}${ext[_codec.index]}';
      _currentFilePath = '${tempDir.path}/$_currentFileName';
      await _recorder.startRecorder(
        toFile: _currentFilePath,
        codec: _codec,
      );
      debugPrint('startRecorder');

      _recorderSubscription = _recorder.onProgress.listen((event) {
        if (event != null && event.duration != null) {
          DateTime date = new DateTime.fromMillisecondsSinceEpoch(event.duration.inMilliseconds, isUtc: true);
          String txt = DateFormat('mm:ss:SS', 'en_GB').format(date);
          this.setState(() {
            _recordTime = txt.substring(0, 8);
            _decibels = event.decibels;
            if (_decibels > 0.0 && _decibels <= 10.0) {
              _voiceImage = 'assets/voice/volume_1.png';
            } else if (_decibels > 10.0 && _decibels <= 20.0) {
              _voiceImage = 'assets/voice/volume_2.png';
            } else if (_decibels > 20.0 && _decibels <= 30.0) {
              _voiceImage = 'assets/voice/volume_3.png';
            } else if (_decibels > 30.0 && _decibels <= 40.0) {
              _voiceImage = 'assets/voice/volume_4.png';
            } else if (_decibels > 40.0 && _decibels <= 50.0) {
              _voiceImage = 'assets/voice/volume_5.png';
            } else if (_decibels > 50.0 && _decibels <= 60.0) {
              _voiceImage = 'assets/voice/volume_6.png';
            } else if (_decibels > 60.0 && _decibels <= 70.0) {
              _voiceImage = 'assets/voice/volume_7.png';
            } else if (_decibels > 70.0) {
              _voiceImage = 'assets/voice/volume_7.png';
            } else {
              _voiceImage = 'assets/voice/volume_1.png';
            }
            if (overlayEntry != null) {
              overlayEntry.markNeedsBuild();
            }
          });
        }
      });

      this.setState(() {
        this._isRecording = true;
      });
    } catch (err) {
      debugPrint('startRecorder error: $err');
      setState(() {
        stopRecorder();
        this._isRecording = false;
        if (_recorderSubscription != null) {
          _recorderSubscription.cancel();
          _recorderSubscription = null;
        }
      });
    }
  }

  stopRecorder() async {
    try {
      await _recorder.stopRecorder();
      debugPrint('stopRecorder');
      releaseRecorderSubscriptions();
      Duration duration = await flutterSoundHelper.duration(_currentFilePath);
      if (widget.recordComplete != null && !isCancel) {
        widget.recordComplete.call(_currentFilePath, _currentFileName, (duration?.inMilliseconds ?? 0) / 1000.0);
      }
    } catch (err) {
      debugPrint('stopRecorder error: $err');
    }
    this.setState(() {
      this._isRecording = false;
    });
  }

  startStopRecorder() {
    if (_recorder.isRecording || _recorder.isPaused) {
      stopRecorder();
    } else {
      startRecorder();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (details) {
        startY = details.globalPosition.dy;
        showOverlay();
      },
      onLongPressEnd: (details) {
        hideOverlay();
      },
      onLongPressMoveUpdate: (details) {
        offset = details.globalPosition.dy;
        updateStatus();
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 7, bottom: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            '$_buttonHint${_isRecording ? _recordTime : ''}',
            style: TextStyle(
              fontSize: 18.0,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  showOverlay() {
    setState(() {
      _buttonHint = '松开 结束';
    });
    insertOverLay(context);
    startRecorder();
  }

  hideOverlay() {
    setState(() {
      _buttonHint = '按住 说话';
    });

    stopRecorder();
    if (overlayEntry != null) {
      overlayEntry.remove();
      overlayEntry = null;
    }
  }

  insertOverLay(BuildContext context) {
    if (overlayEntry == null) {
      overlayEntry = OverlayEntry(builder: (content) {
        return Positioned(
          top: MediaQuery.of(context).size.height * 0.5 - 80,
          left: MediaQuery.of(context).size.width * 0.5 - 80,
          child: Material(
            type: MaterialType.transparency,
            child: Center(
              child: Opacity(
                opacity: 0.8,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Color(0xff77797A),
                    borderRadius: BorderRadius.all(Radius.circular(20.0)),
                  ),
                  child: Column(
                    children: <Widget>[
                      Container(
                        margin: EdgeInsets.only(top: 10),
                        child: Image.asset(
                          _voiceImage,
                          width: 100,
                          height: 100,
                          package: 'flutter_sound_suite',
                        ),
                      ),
                      Container(
                        child: Text(
                          _overLayHint,
                          style: TextStyle(
                            fontStyle: FontStyle.normal,
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      });
      Overlay.of(context).insert(overlayEntry);
    }
  }

  updateStatus() {
    setState(() {
      isCancel = startY - offset > 100 ? true : false;
      if (isCancel) {
        _buttonHint = '松开 取消';
        _overLayHint = '下滑 继续';
        if (_recorder.isRecording) {
          _recorder.pauseRecorder();
        }
      } else {
        _buttonHint = '松开 结束';
        _overLayHint = '上滑 暂停';
        if (_recorder.isPaused) {
          _recorder.resumeRecorder();
        }
      }
    });
  }
}

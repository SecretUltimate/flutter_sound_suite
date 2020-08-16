import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';

class SoundPlayerModel with ChangeNotifier {
  Dio dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10).inMilliseconds,
    receiveTimeout: const Duration(minutes: 60).inMilliseconds,
  ));
  FlutterSoundPlayer _player = FlutterSoundPlayer();
  StreamSubscription _playerSubscription;
  double _currentPlayTime = 0.0;
  double _currentDuration = 0.0;

  double get currentPlayTime => _currentPlayTime;

  double get currentDuration => _currentDuration;

  SoundPlayerModel() {
    init();
  }

  init() async {
    await _player.closeAudioSession();
    await _player.openAudioSession(
        focus: AudioFocus.requestFocusTransient, category: SessionCategory.playAndRecord, mode: SessionMode.modeDefault, device: AudioDevice.speaker);
    await _player.setSubscriptionDuration(Duration(milliseconds: 10));
  }

  @override
  dispose() {
    super.dispose();
    releasePlayerSubscriptions();
    releasePlayer();
    dio.close(force: true);
  }

  bool _isLoading = false;

  String _currentPlayingPath;

  bool isCurrentPlaying({@required String path}) => _player.isPlaying && _currentPlayingPath == path;

  bool isPlayerStopped() => _player.isStopped;

  bool get isLoading => _isLoading;

  startOrStopPlayer({String filePath, String fileName}) async {
    _currentPlayingPath = filePath;
    Directory tempDir = await getTemporaryDirectory();
    String localPath = '${tempDir.path}/$fileName';
    File localFile = File(localPath);
    debugPrint('startOrStopPlayer $_currentPlayingPath local_exists ${localFile.existsSync()}');
    if (!localFile.existsSync()) {
      await dio.download(_currentPlayingPath, localPath);
    }
    if (localFile.existsSync()) {
      Duration duration = await flutterSoundHelper.duration(localPath);
      _currentDuration = (duration?.inMilliseconds ?? 0) / 1000.0;
      debugPrint('startOrStopPlayer $_currentPlayingPath download to $localPath _currentDuration $_currentDuration');
      if (_player.isStopped) {
        startPlayer(path: localPath);
      } else {
        stopPlayer();
      }
    }
  }

  releasePlayerSubscriptions() {
    if (_playerSubscription != null) {
      _playerSubscription.cancel();
      _playerSubscription = null;
    }
  }

  releasePlayer() async {
    try {
      await _player.closeAudioSession();
    } catch (e) {
      debugPrint('Released unsuccessful');
      debugPrint(e);
    }
  }

  _addListeners() {
    releasePlayerSubscriptions();
    _playerSubscription = _player.onProgress.listen((event) {
      if (event != null) {
        _currentPlayTime = event.position.inMilliseconds / 1000.0;
        notifyListeners();
      }
    });
  }

  startPlayer({@required String path, Codec codec: Codec.amrNB}) async {
    try {
      await _player.startPlayer(
          fromURI: path,
          codec: codec,
          whenFinished: () {
            debugPrint('Play finished');
            notifyListeners();
          });
      _addListeners();
      debugPrint('startPlayer');
    } catch (err) {
      debugPrint('error: $err');
    }
    notifyListeners();
  }

  stopPlayer() async {
    try {
      await _player.stopPlayer();
      debugPrint('stopPlayer');
      if (_playerSubscription != null) {
        _playerSubscription.cancel();
        _playerSubscription = null;
      }
    } catch (err) {
      debugPrint('error: $err');
    }
    notifyListeners();
  }

  pauseResumePlayer() {
    if (_player.isPlaying) {
      _player.pausePlayer();
    } else {
      _player.resumePlayer();
    }
  }

  seekToPlayer(int milliSecs) async => await _player.seekToPlayer(Duration(milliseconds: milliSecs));

  onPauseResumePlayer() => (_player.isPlaying || _player.isPaused) ? pauseResumePlayer : null;

  onStopPlayer() => (_player.isPlaying || _player.isPaused) ? stopPlayer : null;

  onStartPlayer() => (_player.isStopped) ? startPlayer : null;
}

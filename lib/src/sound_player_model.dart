import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';

class SoundPlayerModel with ChangeNotifier {
  FlutterSoundPlayer _player = FlutterSoundPlayer();
  StreamSubscription? _playerSubscription;
  double _currentPlayTime = 0.0;

  double get currentPlayTime => _currentPlayTime;

  ///maybe remote or local file path
  String? _currentPlayingPath;

  Dio dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10).inMilliseconds,
    receiveTimeout: const Duration(minutes: 60).inMilliseconds,
  ));
  bool _isDownloading = false;

  bool get isDownloading => _isDownloading;

  SoundPlayerModel() {
    init();
  }

  init() async {
    await _player.closeAudioSession();
    await _player.openAudioSession(
      focus: AudioFocus.requestFocusTransient,
      category: SessionCategory.playAndRecord,
      mode: SessionMode.modeDefault,
    );
    await _player.setSubscriptionDuration(Duration(milliseconds: 10));
  }

  @override
  dispose() {
    super.dispose();
    _releasePlayerSubscriptions();
    _releasePlayer();
    dio.close(force: true);
  }

  bool isCurrentPlaying({required String filePath}) =>
      _player.isPlaying && _currentPlayingPath == filePath;

  bool isPlayerStopped() => _player.isStopped;

  startOrStopPlayer(
      {required String filePath,
      required String fileName,
      required Codec codec}) async {
    _currentPlayingPath = filePath;
    Directory tempDir = await getTemporaryDirectory();
    String localPath = '${tempDir.path}/$fileName';
    File localFile = File(localPath);
    debugPrint(
        'startOrStopPlayer $_currentPlayingPath local_exists ${localFile.existsSync()}');
    if (!localFile.existsSync()) {
      _isDownloading = true;
      notifyListeners();
      await dio.download(_currentPlayingPath!, localPath);
      _isDownloading = false;
      notifyListeners();
    }
    if (localFile.existsSync()) {
      debugPrint(
          'startOrStopPlayer $_currentPlayingPath download to $localPath');
      if (_player.isStopped) {
        startPlayer(path: localPath, codec: codec);
      } else {
        stopPlayer();
      }
    }
  }

  _releasePlayerSubscriptions() {
    _playerSubscription?.cancel();
    _playerSubscription = null;
  }

  _releasePlayer() async {
    try {
      await _player.closeAudioSession();
    } catch (e) {
      debugPrint('Released unsuccessful');
      debugPrint(e.toString());
    }
  }

  _addListeners() {
    _releasePlayerSubscriptions();
    _playerSubscription = _player.onProgress!.listen((event) {
      _currentPlayTime = event.position.inMilliseconds / 1000.0;
      notifyListeners();
    });
  }

  startPlayer({required String path, Codec codec: Codec.amrNB}) async {
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
      _releasePlayerSubscriptions();
    } catch (err) {
      debugPrint('error: $err');
    }
    notifyListeners();
  }

  pauseResumePlayer() async {
    if (_player.isPlaying) {
      await _player.pausePlayer();
    } else {
      await _player.resumePlayer();
    }
    notifyListeners();
  }

  seekToPlayer(int milliSeconds) async =>
      await _player.seekToPlayer(Duration(milliseconds: milliSeconds));
}

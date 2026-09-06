import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class LiveAudioService {
  final AudioPlayer _player = AudioPlayer();

  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isBufferingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String?> currentUrlNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<double> volumeNotifier = ValueNotifier<double>(1.0);

  LiveAudioService() {
    _player.playerStateStream.listen((state) {
      isPlayingNotifier.value = state.playing;
      isBufferingNotifier.value = state.processingState == ProcessingState.buffering ||
          state.processingState == ProcessingState.loading;
    });

    _player.volumeStream.listen((vol) {
      volumeNotifier.value = vol;
    });
  }

  bool get isPlaying => isPlayingNotifier.value;
  bool get isBuffering => isBufferingNotifier.value;
  String? get currentUrl => currentUrlNotifier.value;

  Future<void> playStream(String streamUrl) async {
    if (streamUrl.isEmpty) return;
    try {
      if (currentUrlNotifier.value == streamUrl && isPlaying) {
        return;
      }
      currentUrlNotifier.value = streamUrl;
      await _player.setUrl(streamUrl);
      await _player.play();
    } catch (e) {
      debugPrint("LiveAudioService play error: $e");
      isPlayingNotifier.value = false;
    }
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> resume() async {
    await _player.play();
  }

  Future<void> togglePlay(String streamUrl) async {
    if (isPlaying) {
      await pause();
    } else {
      await playStream(streamUrl);
    }
  }

  Future<void> stop() async {
    await _player.stop();
    currentUrlNotifier.value = null;
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume.clamp(0.0, 1.0));
  }

  void dispose() {
    _player.dispose();
    isPlayingNotifier.dispose();
    isBufferingNotifier.dispose();
    currentUrlNotifier.dispose();
    volumeNotifier.dispose();
  }
}

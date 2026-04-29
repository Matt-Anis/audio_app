import 'package:audio_app/models/audio_track.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();

  AudioPlayer get player => _player;

  Future<void> playTrack(AudioTrack track) async {
    final source = AudioSource.uri(
      Uri.parse(track.url),
      tag: MediaItem(
        id: track.id,
        title: track.title,
        album: track.category,
      ),
    );

    await _player.setAudioSource(source);
    await _player.play();
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> toggleRepeat() async {
    final current = _player.loopMode;
    if (current == LoopMode.one) {
      await _player.setLoopMode(LoopMode.off);
    } else {
      await _player.setLoopMode(LoopMode.one);
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}

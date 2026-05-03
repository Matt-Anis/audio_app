import 'package:audio_app/main.dart';
import 'package:audio_app/models/audio_track.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_service/audio_service.dart';

class AudioPlayerService {
  // Access the global audio handler via the public getter
  AudioPlayerHandler? get _handler => getAudioHandler();
  
  // Expose the underlying player for UI access
  AudioPlayer? get player => _handler?.player;

  // Stream for playback state changes
  Stream<PlaybackState> get playbackStateStream =>
      _handler!.playbackState.stream;

  Future<void> playTrack(AudioTrack track) async {
    final source = AudioSource.uri(
      Uri.parse(track.url),
      tag: MediaItem(
        id: track.id,
        title: track.title,
        album: track.category,
        artUri: track.artwork != null ? Uri.parse(track.artwork!) : null,
      ),
    );
    // Use the handler to set the audio source and play
    await _handler?.setAudioSource(source);
    await _handler?.play();
  }

  Future<void> togglePlayPause() async {
    final playing = _handler?.playbackState.value.playing ?? false;
    if (playing) {
      await _handler?.pause();
    } else {
      await _handler?.play();
    }
  }

  Future<void> toggleRepeat() async {
    // This logic needs to be implemented in the AudioPlayerHandler
    // For now, we'll leave it out to fix the main issue.
  }

  Future<void> dispose() async {
    // The handler will be disposed by the audio_service plugin.
  }
}

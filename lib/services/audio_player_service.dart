import 'dart:async';

import 'package:audio_app/main.dart';
import 'package:audio_app/models/audio_track.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';

class AudioPlayerService {
  // Access the global audio handler via the public getter
  AudioPlayerHandler? get _handler => getAudioHandler();
  
  // Expose the underlying player for UI access
  AudioPlayer? get player => _handler?.player;

  // Stream for playback state changes
  Stream<PlaybackState> get playbackStateStream async* {
    final handler = _handler ?? await ensureAudioHandler();
    yield* handler.playbackState.stream;
  }

  Stream<MediaItem?> get mediaItemStream async* {
    final handler = _handler ?? await ensureAudioHandler();
    yield* handler.mediaItem.stream;
  }

  MediaItem? get currentMediaItem => _handler?.mediaItem.value;

  Future<void> playTrack(AudioTrack track) async {
    final handler = _handler ?? await ensureAudioHandler();

    final source = AudioSource.uri(
      Uri.parse(track.url),
      tag: MediaItem(
        id: track.id,
        title: track.title,
        album: track.category,
        artUri: track.artwork != null ? Uri.parse(track.artwork!) : null,
      ),
    );

    await handler.player.setAudioSource(source);
    await handler.player.play();
  }

  Future<void> togglePlayPause() async {
    final handler = _handler ?? await ensureAudioHandler();

    final playing = handler.player.playing;
    if (playing) {
      await handler.player.pause();
    } else {
      await handler.player.play();
    }
  }

  Future<void> stop() async {
    await _handler?.player.stop();
  }

  Future<void> seek(Duration position) async {
    await _handler?.player.seek(position);
  }

  Future<void> seekBy(Duration offset) async {
    final player = _handler?.player;
    if (player == null) return;
    final current = player.position;
    final next = current + offset;
    final duration = player.duration ?? Duration.zero;
    final clamped = Duration(
      milliseconds: next.inMilliseconds.clamp(0, duration.inMilliseconds),
    );
    await player.seek(clamped);
  }

  Future<void> toggleRepeat() async {
    final player = _handler?.player;
    if (player == null) return;
    final current = player.loopMode;
    final next = current == LoopMode.one ? LoopMode.off : LoopMode.one;
    await player.setLoopMode(next);
  }

  Future<void> dispose() async {
    // The handler will be disposed by the audio_service plugin.
  }
}

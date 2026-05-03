import 'dart:async';

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

    Stream<MediaItem?> get mediaItemStream =>
      _handler?.mediaItem.stream ?? const Stream.empty();

    MediaItem? get currentMediaItem => _handler?.mediaItem.value;

  Future<void> playTrack(AudioTrack track) async {
    final mediaItem = MediaItem(
      id: track.id,
      title: track.title,
      album: track.category,
      artUri: track.artwork != null ? Uri.parse(track.artwork!) : null,
      extras: {
        'url': track.url,
        'artwork': track.artwork,
      },
    );
    final source = AudioSource.uri(
      Uri.parse(track.url),
      tag: mediaItem,
    );
    _handler?.mediaItem.add(mediaItem);
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

  Future<void> stop() async {
    await _handler?.stop();
  }

  Future<void> seek(Duration position) async {
    await _handler?.seek(position);
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

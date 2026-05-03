import 'dart:async';

import 'package:audio_app/models/audio_track.dart';
import 'package:audio_app/services/audio_catalog_service.dart';
import 'package:audio_app/services/audio_player_service.dart';
import 'package:audio_app/services/favorites_service.dart';
import 'package:audio_app/services/local_stats_service.dart';
import 'package:audio_app/utils/dialog_helper.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:developer' as developer;

class PlayerTab extends StatefulWidget {
  final String uid;
  final VoidCallback onStatsUpdated;

  const PlayerTab({
    super.key,
    required this.uid,
    required this.onStatsUpdated,
  });

  @override
  State<PlayerTab> createState() => _PlayerTabState();
}

class _PlayerTabState extends State<PlayerTab> {
  final _catalogService = AudioCatalogService();
  final _playerService = AudioPlayerService();
  final _favoritesService = FavoritesService();
  final _statsService = LocalStatsService();

  bool _loading = true;
  String? _error;
  Map<String, List<AudioTrack>> _catalog = {};

  AudioTrack? _currentTrack;
  bool _isCurrentFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _catalogService.fetchTracksByCategory();
      if (data.isEmpty) {
        throw Exception('Catalogue indisponible pour le moment.');
      }
      if (!mounted) return;
      setState(() {
        _catalog = data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _playTrack(AudioTrack track) async {
    try {
      await _playerService.playTrack(track);
      await _statsService.recordListening(trackTitle: track.title, minutes: 4);
      widget.onStatsUpdated();

      final isFav = await _favoritesService.isFavorite(widget.uid, track.id);
      if (!mounted) return;

      setState(() {
        _currentTrack = track;
        _isCurrentFavorite = isFav;
      });
      
      developer.log('Playing track: ${track.title}');
    } catch (e) {
      developer.log('Error playing track: $e');
      if (!mounted) return;
      await DialogHelper.showErrorDialog(
        context,
        title: 'Erreur de lecture',
        message: 'Impossible de lire la piste: $e',
      );
    }
  }

  Future<void> _toggleFavorite() async {
    final track = _currentTrack;
    if (track == null) return;

    try {
      if (_isCurrentFavorite) {
        await _favoritesService.removeFavorite(widget.uid, track.id);
      } else {
        await _favoritesService.addFavorite(widget.uid, track);
      }

      if (!mounted) return;
      setState(() {
        _isCurrentFavorite = !_isCurrentFavorite;
      });

      if (!mounted) return;
      await DialogHelper.showSuccessDialog(
        context,
        title: 'Succès',
        message: _isCurrentFavorite
            ? 'Ajouté aux favoris'
            : 'Retiré des favoris',
      );
    } catch (e) {
      developer.log('Error toggling favorite: $e');
      if (!mounted) return;
      await DialogHelper.showErrorDialog(
        context,
        title: 'Erreur',
        message: 'Erreur lors de la gestion du favori: $e',
      );
    }
  }

  @override
  void dispose() {
    _playerService.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  Future<void> _openNowPlaying() async {
    final track = _currentTrack;
    if (track == null) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _NowPlayingSheet(
          track: track,
          playerService: _playerService,
          isFavorite: _isCurrentFavorite,
          onToggleFavorite: _toggleFavorite,
          formatDuration: _formatDuration,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loadCatalog,
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadCatalog,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Bibliotheque',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Recitations organisees par type de sourate.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
                ),
                const SizedBox(height: 16),
                ..._catalog.entries.map(
                  (entry) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: ExpansionTile(
                      collapsedIconColor: colorScheme.onSurface,
                      iconColor: colorScheme.primary,
                      title: Text(
                        entry.key,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      children: entry.value
                          .map(
                            (track) => ListTile(
                              title: Text(track.title),
                              subtitle: Text(track.category),
                              trailing: IconButton(
                                onPressed: () => _playTrack(track),
                                icon: Icon(Icons.play_circle_fill, color: colorScheme.primary),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_currentTrack != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _MiniPlayerBar(
              track: _currentTrack!,
              playerService: _playerService,
              isFavorite: _isCurrentFavorite,
              onToggleFavorite: _toggleFavorite,
              onExpand: _openNowPlaying,
              formatDuration: _formatDuration,
            ),
          ),
      ],
    );
  }
}

class _MiniPlayerBar extends StatelessWidget {
  final AudioTrack track;
  final AudioPlayerService playerService;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onExpand;
  final String Function(Duration) formatDuration;

  const _MiniPlayerBar({
    required this.track,
    required this.playerService,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onExpand,
    required this.formatDuration,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(track.category, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              IconButton(
                onPressed: onExpand,
                icon: Icon(Icons.expand_less, color: colorScheme.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ProgressBar(
            playerService: playerService,
            formatDuration: formatDuration,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              StreamBuilder<LoopMode>(
                stream: playerService.player?.loopModeStream ?? const Stream.empty(),
                builder: (context, snapshot) {
                  final repeatOne = snapshot.data == LoopMode.one;
                  return IconButton(
                    onPressed: playerService.toggleRepeat,
                    icon: Icon(
                      Icons.repeat_one,
                      color: repeatOne ? colorScheme.primary : colorScheme.onSurface,
                    ),
                  );
                },
              ),
              IconButton(
                onPressed: playerService.stop,
                icon: Icon(Icons.stop_circle, color: colorScheme.onSurface),
              ),
              StreamBuilder<PlayerState>(
                stream: playerService.player?.playerStateStream ?? const Stream.empty(),
                builder: (context, snapshot) {
                  final playing = snapshot.data?.playing ?? false;
                  return IconButton(
                    onPressed: playerService.togglePlayPause,
                    icon: Icon(
                      playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                      color: colorScheme.primary,
                      size: 34,
                    ),
                  );
                },
              ),
              IconButton(
                onPressed: onToggleFavorite,
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? colorScheme.primary : colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final AudioPlayerService playerService;
  final String Function(Duration) formatDuration;

  const _ProgressBar({
    required this.playerService,
    required this.formatDuration,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration?>(
      stream: playerService.player?.durationStream ?? const Stream.empty(),
      builder: (context, durationSnapshot) {
        final total = durationSnapshot.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: playerService.player?.positionStream ?? const Stream.empty(),
          builder: (context, positionSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            final maxMs = total.inMilliseconds > 0 ? total.inMilliseconds : 1;
            final valueMs = position.inMilliseconds.clamp(0, maxMs);

            return Column(
              children: [
                Slider(
                  value: valueMs.toDouble(),
                  min: 0,
                  max: maxMs.toDouble(),
                  onChanged: (value) {
                    playerService.seek(Duration(milliseconds: value.toInt()));
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(formatDuration(position), style: Theme.of(context).textTheme.bodySmall),
                    Text(formatDuration(total), style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _NowPlayingSheet extends StatelessWidget {
  final AudioTrack track;
  final AudioPlayerService playerService;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final String Function(Duration) formatDuration;

  const _NowPlayingSheet({
    required this.track,
    required this.playerService,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.formatDuration,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.92,
      minChildSize: 0.7,
      builder: (context, controller) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0F151D),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: ListView(
            controller: controller,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Lecture en cours',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.expand_more, color: colorScheme.onSurface),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(track.category),
                    const SizedBox(height: 16),
                    _ProgressBar(
                      playerService: playerService,
                      formatDuration: formatDuration,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          onPressed: () => playerService.seekBy(const Duration(seconds: -15)),
                          icon: Icon(Icons.replay_10, color: colorScheme.onSurface),
                        ),
                        StreamBuilder<PlayerState>(
                          stream: playerService.player?.playerStateStream ?? const Stream.empty(),
                          builder: (context, snapshot) {
                            final playing = snapshot.data?.playing ?? false;
                            return IconButton(
                              onPressed: playerService.togglePlayPause,
                              icon: Icon(
                                playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                size: 48,
                                color: colorScheme.primary,
                              ),
                            );
                          },
                        ),
                        IconButton(
                          onPressed: () => playerService.seekBy(const Duration(seconds: 15)),
                          icon: Icon(Icons.forward_10, color: colorScheme.onSurface),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        StreamBuilder<LoopMode>(
                          stream: playerService.player?.loopModeStream ?? const Stream.empty(),
                          builder: (context, snapshot) {
                            final repeatOne = snapshot.data == LoopMode.one;
                            return IconButton(
                              onPressed: playerService.toggleRepeat,
                              icon: Icon(
                                Icons.repeat_one,
                                color: repeatOne ? colorScheme.primary : colorScheme.onSurface,
                              ),
                            );
                          },
                        ),
                        IconButton(
                          onPressed: playerService.stop,
                          icon: Icon(Icons.stop_circle, color: colorScheme.onSurface),
                        ),
                        IconButton(
                          onPressed: onToggleFavorite,
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? colorScheme.primary : colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

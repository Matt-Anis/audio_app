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
  final _searchController = TextEditingController();
  Timer? _searchTimer;

  bool _loading = true;
  String? _error;
  Map<String, List<AudioTrack>> _catalog = {};
  _LibraryViewMode _viewMode = _LibraryViewMode.titles;

  AudioTrack? _currentTrack;
  bool _isCurrentFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog({String? query}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rawQuery = query ?? _searchController.text;
      final data = rawQuery.trim().isEmpty
          ? await _catalogService.fetchTracksByCategory()
          : await _catalogService.fetchTracksByCategory(query: rawQuery);
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
      if (mounted) {
        setState(() {
          _currentTrack = track;
        });
      }

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
    _searchTimer?.cancel();
    _searchController.dispose();
    _playerService.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 350), () {
      _loadCatalog(query: value);
    });
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

    final allTracks = _catalog.values.expand((e) => e).toList();
    final query = _searchController.text.trim().toLowerCase();
    final filteredTracks = query.isEmpty
        ? allTracks
        : allTracks
            .where(
              (track) =>
                  track.title.toLowerCase().contains(query) ||
                  track.category.toLowerCase().contains(query),
            )
            .toList();

    final groupedByArtist = <String, List<AudioTrack>>{};
    for (final track in filteredTracks) {
      groupedByArtist.putIfAbsent(track.category, () => <AudioTrack>[]).add(track);
    }
    for (final list in groupedByArtist.values) {
      list.sort((a, b) => a.title.compareTo(b.title));
    }

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
                  'Recherchez par titre, artiste ou couverture.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un titre ou un artiste',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<_LibraryViewMode>(
                  segments: const [
                    ButtonSegment(
                      value: _LibraryViewMode.titles,
                      label: Text('Titres'),
                      icon: Icon(Icons.list_alt),
                    ),
                    ButtonSegment(
                      value: _LibraryViewMode.covers,
                      label: Text('Covers'),
                      icon: Icon(Icons.grid_view),
                    ),
                    ButtonSegment(
                      value: _LibraryViewMode.authors,
                      label: Text('Artistes'),
                      icon: Icon(Icons.person),
                    ),
                  ],
                  selected: {_viewMode},
                  onSelectionChanged: (value) {
                    setState(() {
                      _viewMode = value.first;
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (filteredTracks.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: const Text('Aucun resultat pour cette recherche.'),
                  )
                else if (_viewMode == _LibraryViewMode.covers)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: filteredTracks.length,
                    itemBuilder: (context, index) {
                      final track = filteredTracks[index];
                      return _CoverCard(
                        track: track,
                        onPlay: () => _playTrack(track),
                      );
                    },
                  )
                else if (_viewMode == _LibraryViewMode.authors)
                  ...groupedByArtist.entries.map(
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
                              (track) => _TrackBadge(
                                track: track,
                                onPlay: () => _playTrack(track),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  )
                else
                  ...filteredTracks.map(
                    (track) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TrackBadge(
                        track: track,
                        onPlay: () => _playTrack(track),
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
              _ArtworkThumb(url: track.artwork, size: 44),
              const SizedBox(width: 10),
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
              if (track.artwork != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Image.network(
                      track.artwork!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.white.withOpacity(0.08),
                        child: const Icon(Icons.music_note, size: 48),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.music_note, size: 48),
                ),
              const SizedBox(height: 16),
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

class _ArtworkThumb extends StatelessWidget {
  final String? url;
  final double size;

  const _ArtworkThumb({required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.music_note, size: 18),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url!,
        height: size,
        width: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: size,
          width: size,
          color: Colors.white.withOpacity(0.08),
          child: const Icon(Icons.music_note, size: 18),
        ),
      ),
    );
  }
}

class _TrackBadge extends StatelessWidget {
  final AudioTrack track;
  final VoidCallback onPlay;

  const _TrackBadge({required this.track, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onPlay,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            _ArtworkThumb(url: track.artwork, size: 44),
            const SizedBox(width: 12),
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
              onPressed: onPlay,
              icon: Icon(Icons.play_circle_fill, color: colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverCard extends StatelessWidget {
  final AudioTrack track;
  final VoidCallback onPlay;

  const _CoverCard({required this.track, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onPlay,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: track.artwork == null
                    ? Container(
                        color: Colors.white.withOpacity(0.08),
                        child: const Icon(Icons.music_note, size: 36),
                      )
                    : Image.network(
                        track.artwork!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.white.withOpacity(0.08),
                          child: const Icon(Icons.music_note, size: 36),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              track.category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Icon(Icons.play_circle_fill, color: colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}

enum _LibraryViewMode {
  titles,
  covers,
  authors,
}

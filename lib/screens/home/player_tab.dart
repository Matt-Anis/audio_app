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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.white)));
    }

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadCatalog,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: _catalog.entries
                  .map(
                    (entry) => Card(
                      color: const Color(0xFF1C1C1C),
                      child: ExpansionTile(
                        collapsedIconColor: Colors.white,
                        iconColor: const Color(0xFF1DB954),
                        title: Text(
                          entry.key,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        children: entry.value
                            .map(
                              (track) => ListTile(
                                title: Text(track.title, style: const TextStyle(color: Colors.white)),
                                subtitle: Text(track.category, style: const TextStyle(color: Colors.white70)),
                                trailing: IconButton(
                                  onPressed: () => _playTrack(track),
                                  icon: const Icon(Icons.play_circle_fill, color: Color(0xFF1DB954)),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        if (_currentTrack != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF181818),
              border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentTrack!.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _currentTrack!.category,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                StreamBuilder<LoopMode>(
                  stream: _playerService.player?.loopModeStream ?? const Stream.empty(),
                  builder: (context, snapshot) {
                    final repeatOne = snapshot.data == LoopMode.one;
                    return IconButton(
                      onPressed: _playerService.toggleRepeat,
                      icon: Icon(
                        Icons.repeat_one,
                        color: repeatOne ? const Color(0xFF1DB954) : Colors.white,
                      ),
                    );
                  },
                ),
                StreamBuilder<PlayerState>(
                  stream: _playerService.player?.playerStateStream ?? const Stream.empty(),
                  builder: (context, snapshot) {
                    final playing = snapshot.data?.playing ?? false;
                    return IconButton(
                      onPressed: _playerService.togglePlayPause,
                      icon: Icon(
                        playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
                        color: const Color(0xFF1DB954),
                        size: 34,
                      ),
                    );
                  },
                ),
                IconButton(
                  onPressed: _toggleFavorite,
                  icon: Icon(
                    _isCurrentFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isCurrentFavorite ? const Color(0xFF1DB954) : Colors.white,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

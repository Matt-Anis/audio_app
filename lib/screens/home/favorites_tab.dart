import 'package:audio_app/services/biometric_service.dart';
import 'package:audio_app/services/favorites_service.dart';
import 'package:flutter/material.dart';

class FavoritesTab extends StatefulWidget {
  final String uid;

  const FavoritesTab({super.key, required this.uid});

  @override
  State<FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends State<FavoritesTab> {
  final _favoritesService = FavoritesService();
  final _biometricService = BiometricService();

  Future<void> _deleteFavorite(String trackId) async {
    final ok = await _biometricService.authenticate(
      reason: 'Authentifiez-vous pour supprimer ce favori.',
    );

    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Suppression annulee: empreinte requise.')),
      );
      return;
    }

    await _favoritesService.removeFavorite(widget.uid, trackId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _favoritesService.streamFavorites(widget.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Erreur: ${snapshot.error}',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        final favorites = snapshot.data ?? [];
        if (favorites.isEmpty) {
          return const Center(
            child: Text('Aucun favori pour le moment.', style: TextStyle(color: Colors.white70)),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: favorites.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final track = favorites[index];
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1C),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                title: Text(track.title, style: const TextStyle(color: Colors.white)),
                subtitle: Text(track.category, style: const TextStyle(color: Colors.white70)),
                trailing: IconButton(
                  onPressed: () => _deleteFavorite(track.id),
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

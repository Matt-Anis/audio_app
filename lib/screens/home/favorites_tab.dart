import 'package:audio_app/services/biometric_service.dart';
import 'package:audio_app/services/favorites_service.dart';
import 'package:audio_app/utils/dialog_helper.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;

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
      await DialogHelper.showErrorDialog(
        context,
        title: 'Authentification échouée',
        message: 'Vous devez vous authentifier pour supprimer un favori.',
      );
      return;
    }

    try {
      await _favoritesService.removeFavorite(widget.uid, trackId);
      if (!mounted) return;
      await DialogHelper.showSuccessDialog(
        context,
        title: 'Succès',
        message: 'Favori supprimé avec succès.',
      );
    } catch (e) {
      developer.log('Error deleting favorite: $e');
      if (!mounted) return;
      await DialogHelper.showErrorDialog(
        context,
        title: 'Erreur',
        message: 'Erreur lors de la suppression du favori: $e',
      );
    }
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
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 56, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    Text(
                      'Erreur: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final favorites = snapshot.data ?? [];
        if (favorites.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_border, size: 56, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 12),
                  const Text('Aucun favori pour le moment.'),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: favorites.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final track = favorites[index];
            return Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: ListTile(
                title: Text(track.title),
                subtitle: Text(track.category),
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

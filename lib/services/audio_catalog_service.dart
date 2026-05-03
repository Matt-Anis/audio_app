import 'dart:convert';

import 'package:audio_app/models/audio_track.dart';
import 'package:http/http.dart' as http;

class AudioCatalogService {
  Future<Map<String, List<AudioTrack>>> fetchTracksByCategory({
    String query = 'quran recitation',
  }) async {
    final encoded = Uri.encodeComponent(query.trim().isEmpty ? 'quran' : query.trim());
    final url =
        'https://itunes.apple.com/search?term=$encoded&entity=song&limit=50';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('iTunes API error: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (decoded['results'] as List<dynamic>?) ?? [];
    if (results.isEmpty) {
      throw Exception('Aucun resultat pour "$query"');
    }

    final Map<String, List<AudioTrack>> grouped = {};
    for (final entry in results) {
      final data = entry as Map<String, dynamic>;
      final previewUrl = data['previewUrl'] as String?;
      if (previewUrl == null || previewUrl.isEmpty) continue;

      final trackId = data['trackId']?.toString() ?? previewUrl;
      final title = (data['trackName'] as String?) ?? 'Titre inconnu';
      final artist = (data['artistName'] as String?) ?? 'Artiste inconnu';
      final artwork100 = data['artworkUrl100'] as String?;
      final artwork = artwork100?.replaceAll('100x100bb.jpg', '600x600bb.jpg');

      grouped.putIfAbsent(artist, () => <AudioTrack>[]).add(
            AudioTrack(
              id: trackId,
              title: title,
              category: artist,
              url: previewUrl,
              artwork: artwork,
            ),
          );
    }

    grouped.removeWhere((_, value) => value.isEmpty);
    if (grouped.isEmpty) {
      throw Exception('Aucun audio disponible pour "$query"');
    }

    return grouped;
  }
}

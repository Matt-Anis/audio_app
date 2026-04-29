import 'dart:convert';

import 'package:audio_app/models/audio_track.dart';
import 'package:http/http.dart' as http;

class AudioCatalogService {
  Future<Map<String, List<AudioTrack>>> fetchTracksByCategory() async {
    const url = 'https://mp3quran.net/api/v3/reciters?language=eng';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        return _fallbackCatalog();
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final reciters = (decoded['reciters'] as List<dynamic>?) ?? [];

      final Map<String, List<AudioTrack>> result = {};
      for (final reciter in reciters.take(6)) {
        final reciterMap = reciter as Map<String, dynamic>;
        final reciterName = (reciterMap['name'] as String?) ?? 'Unknown';
        final moshaf = (reciterMap['moshaf'] as List<dynamic>?) ?? [];
        if (moshaf.isEmpty) continue;

        final firstMoshaf = moshaf.first as Map<String, dynamic>;
        final server = (firstMoshaf['server'] as String?) ?? '';
        final surahListText = (firstMoshaf['surah_list'] as String?) ?? '';
        if (server.isEmpty || surahListText.isEmpty) continue;

        final normalizedServer = server.endsWith('/') ? server : '$server/';
        final surahs = surahListText.split(',').map((e) => e.trim()).toList();

        final tracks = <AudioTrack>[];
        for (final surah in surahs.take(8)) {
          final padded = surah.padLeft(3, '0');
          tracks.add(
            AudioTrack(
              id: '$reciterName-$surah',
              title: 'Surah $surah',
              category: reciterName,
              url: '$normalizedServer$padded.mp3',
            ),
          );
        }

        if (tracks.isNotEmpty) {
          result[reciterName] = tracks;
        }
      }

      return result.isEmpty ? _fallbackCatalog() : result;
    } catch (_) {
      return _fallbackCatalog();
    }
  }

  Map<String, List<AudioTrack>> _fallbackCatalog() {
    return {
      'Popular Recitations': [
        const AudioTrack(
          id: 'fallback-1',
          title: 'Sample Track 1',
          category: 'Popular Recitations',
          url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
        ),
        const AudioTrack(
          id: 'fallback-2',
          title: 'Sample Track 2',
          category: 'Popular Recitations',
          url: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
        ),
      ],
    };
  }
}

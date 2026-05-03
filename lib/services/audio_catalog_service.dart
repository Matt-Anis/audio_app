import 'dart:convert';

import 'package:audio_app/models/audio_track.dart';
import 'package:http/http.dart' as http;

class AudioCatalogService {
  Future<Map<String, List<AudioTrack>>> fetchTracksByCategory() async {
    const surahUrl = 'https://quran.yousefheiba.com/api/surahs';
    const reciterName = 'Yasser-Al-Dosari';

    try {
      final surahResponse = await http.get(Uri.parse(surahUrl));
      if (surahResponse.statusCode != 200) {
        throw Exception('Surah API error: ${surahResponse.statusCode}');
      }

      final surahList = jsonDecode(surahResponse.body) as List<dynamic>;
      final result = <String, List<AudioTrack>>{};

      for (final entry in surahList) {
        final data = entry as Map<String, dynamic>;
        final surahId = data['id']?.toString() ?? '';
        if (surahId.isEmpty) continue;

        final nameEn = (data['name_en'] as String?) ?? 'Surah $surahId';
        final nameAr = (data['name_ar'] as String?) ?? '';
        final type = (data['type'] as String?) ?? 'Meccan';

        final title = nameAr.isEmpty ? nameEn : '$nameEn • $nameAr';
        final audioUrl =
            'https://quran.yousefheiba.com/api/surahAudio?reciter=$reciterName&id=$surahId';

        result.putIfAbsent(type, () => <AudioTrack>[]).add(
              AudioTrack(
                id: 'reciter92-$surahId',
                title: title,
                category: type,
                url: audioUrl,
              ),
            );
      }

      result.removeWhere((_, value) => value.isEmpty);
      if (result.isEmpty) {
        throw Exception('Surah API returned empty list');
      }

      return result;
    } catch (e) {
      rethrow;
    }
  }
}

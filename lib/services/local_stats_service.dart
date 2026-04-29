import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalStatsService {
  static const _totalMinutesKey = 'stats_total_minutes';
  static const _goalHoursKey = 'monthly_goal_hours';
  static const _dailyMinutesKey = 'stats_daily_minutes';
  static const _topTracksKey = 'stats_top_tracks';

  Future<int> getTotalMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_totalMinutesKey) ?? 0;
  }

  Future<int> getGoalHours() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_goalHoursKey) ?? 20;
  }

  Future<void> setGoalHours(int hours) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_goalHoursKey, hours);
  }

  Future<Map<String, int>> getDailyMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_dailyMinutesKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((key, value) => MapEntry(key, value as int));
  }

  Future<Map<String, int>> getTopTracks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_topTracksKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((key, value) => MapEntry(key, value as int));
  }

  Future<void> recordListening({
    required String trackTitle,
    int minutes = 4,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final total = (prefs.getInt(_totalMinutesKey) ?? 0) + minutes;
    await prefs.setInt(_totalMinutesKey, total);

    final dateKey = DateTime.now().toIso8601String().split('T').first;
    final daily = await getDailyMinutes();
    daily[dateKey] = (daily[dateKey] ?? 0) + minutes;
    await prefs.setString(_dailyMinutesKey, jsonEncode(daily));

    final topTracks = await getTopTracks();
    topTracks[trackTitle] = (topTracks[trackTitle] ?? 0) + minutes;
    await prefs.setString(_topTracksKey, jsonEncode(topTracks));
  }
}

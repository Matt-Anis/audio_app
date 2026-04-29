import 'dart:math';

import 'package:audio_app/services/auth_service.dart';
import 'package:audio_app/services/local_stats_service.dart';
import 'package:flutter/material.dart';

class StatsTab extends StatefulWidget {
  final String uid;

  const StatsTab({super.key, required this.uid});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  final _authService = AuthService();
  final _statsService = LocalStatsService();

  bool _isLoading = true;
  String _fullName = 'Utilisateur';
  int _totalMinutes = 0;
  int _goalHours = 20;
  Map<String, int> _dailyMinutes = {};
  Map<String, int> _topTracks = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final profile = await _authService.getUserProfile(widget.uid);
    final totalMinutes = await _statsService.getTotalMinutes();
    final goalHours = await _statsService.getGoalHours();
    final dailyMinutes = await _statsService.getDailyMinutes();
    final topTracks = await _statsService.getTopTracks();

    final firstName = (profile?['firstName'] as String?) ?? '';
    final lastName = (profile?['lastName'] as String?) ?? '';

    if (!mounted) return;

    setState(() {
      _fullName = '$firstName $lastName'.trim().isEmpty ? 'Utilisateur' : '$firstName $lastName';
      _totalMinutes = totalMinutes;
      _goalHours = goalHours;
      _dailyMinutes = dailyMinutes;
      _topTracks = topTracks;
      _isLoading = false;
    });
  }

  Future<void> _updateGoal(int? value) async {
    if (value == null) return;
    await _statsService.setGoalHours(value);
    setState(() {
      _goalHours = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final hours = _totalMinutes ~/ 60;
    final minutes = _totalMinutes % 60;
    final goalMinutes = _goalHours * 60;
    final progress = goalMinutes == 0 ? 0.0 : (_totalMinutes / goalMinutes).clamp(0.0, 1.0);

    final sortedTracks = _topTracks.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 22, color: Colors.white),
              children: [
                const TextSpan(text: 'Bienvenue, '),
                TextSpan(
                  text: _fullName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Temps total ecoute', style: TextStyle(color: Colors.white70)),
                Text(
                  '${hours}h ${minutes}m',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Objectif mensuel (heures)',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                DropdownButton<int>(
                  dropdownColor: const Color(0xFF222222),
                  value: _goalHours,
                  isExpanded: true,
                  items: List.generate(10, (index) => (index + 1) * 5)
                      .map(
                        (h) => DropdownMenuItem<int>(
                          value: h,
                          child: Text(
                            '$h h',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _updateGoal,
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: const Color(0xFF3D3D3D),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF1DB954)),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}% atteint',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Minutes ecoutees par jour (mois actuel)',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                _MonthlyBarChart(dailyMinutes: _dailyMinutes),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Morceaux les plus ecoutes',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (sortedTracks.isEmpty)
                  const Text('Aucun morceau ecoute pour le moment.', style: TextStyle(color: Colors.white70))
                else
                  ...sortedTracks.take(5).map(
                    (entry) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.key, style: const TextStyle(color: Colors.white)),
                      trailing: Text('${entry.value} min', style: const TextStyle(color: Colors.white70)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: const Color(0xFF1C1C1C),
      borderRadius: BorderRadius.circular(14),
    );
  }
}

class _MonthlyBarChart extends StatelessWidget {
  final Map<String, int> dailyMinutes;

  const _MonthlyBarChart({required this.dailyMinutes});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);

    final values = List.generate(daysInMonth, (index) {
      final day = index + 1;
      final date = DateTime(now.year, now.month, day).toIso8601String().split('T').first;
      return dailyMinutes[date] ?? 0;
    });

    final maxValue = max(1, values.fold<int>(0, max));

    return SizedBox(
      height: 170,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: values.length,
        itemBuilder: (context, index) {
          final value = values[index];
          final barHeight = 10 + ((value / maxValue) * 110);
          return Container(
            width: 18,
            margin: const EdgeInsets.only(right: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DB954),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${index + 1}',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

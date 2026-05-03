import 'dart:math';

import 'package:audio_app/services/auth_service.dart';
import 'package:audio_app/services/local_stats_service.dart';
import 'package:audio_app/utils/dialog_helper.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;

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
    try {
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
    } catch (e) {
      developer.log('Error loading stats: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      await DialogHelper.showErrorDialog(
        context,
        title: 'Erreur',
        message: 'Erreur lors du chargement des données: $e',
      );
    }
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

    final colorScheme = Theme.of(context).colorScheme;
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
          Text.rich(
            TextSpan(
              text: 'Bienvenue, ',
              style: Theme.of(context).textTheme.titleLarge,
              children: [
                TextSpan(
                  text: _fullName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _GlassCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Temps total ecoute', style: Theme.of(context).textTheme.bodyMedium),
                Text(
                  '${hours}h ${minutes}m',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Objectif mensuel (heures)', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  dropdownColor: const Color(0xFF151B24),
                  value: _goalHours,
                  items: List.generate(10, (index) => (index + 1) * 5)
                      .map(
                        (h) => DropdownMenuItem<int>(
                          value: h,
                          child: Text('$h h'),
                        ),
                      )
                      .toList(),
                  onChanged: _updateGoal,
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                  ),
                ),
                const SizedBox(height: 8),
                Text('${(progress * 100).toStringAsFixed(0)}% atteint'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Minutes ecoutees par jour (mois actuel)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                _MonthlyBarChart(dailyMinutes: _dailyMinutes),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Morceaux les plus ecoutes',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (sortedTracks.isEmpty)
                  Text(
                    'Aucun morceau ecoute pour le moment.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                else
                  ...sortedTracks.take(5).map(
                    (entry) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.key),
                      trailing: Text('${entry.value} min'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: child,
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

    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 170,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: values.length,
        itemBuilder: (context, index) {
          final value = values[index];
          final barHeight = 8 + ((value / maxValue) * 110);
          return Container(
            width: 18,
            margin: const EdgeInsets.only(right: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
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

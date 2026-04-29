import 'package:audio_app/screens/home/favorites_tab.dart';
import 'package:audio_app/screens/home/player_tab.dart';
import 'package:audio_app/screens/home/stats_tab.dart';
import 'package:audio_app/services/auth_service.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  final String uid;

  const HomePage({super.key, required this.uid});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _authService = AuthService();
  int _currentIndex = 0;
  int _statsVersion = 0;

  void _refreshStats() {
    setState(() {
      _statsVersion++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      StatsTab(key: ValueKey(_statsVersion), uid: widget.uid),
      PlayerTab(uid: widget.uid, onStatsUpdated: _refreshStats),
      FavoritesTab(uid: widget.uid),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio App'),
        actions: [
          IconButton(
            onPressed: _authService.logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (value) {
          setState(() {
            _currentIndex = value;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Stats'),
          BottomNavigationBarItem(icon: Icon(Icons.library_music), label: 'Player'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favoris'),
        ],
      ),
    );
  }
}

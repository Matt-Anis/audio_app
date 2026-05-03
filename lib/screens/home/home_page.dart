import 'package:audio_app/screens/home/favorites_tab.dart';
import 'package:audio_app/screens/home/player_tab.dart';
import 'package:audio_app/screens/home/stats_tab.dart';
import 'package:audio_app/services/auth_service.dart';
import 'package:audio_app/utils/dialog_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:developer' as developer;

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

  Future<void> _handleLogout() async {
    final confirmed = await DialogHelper.showConfirmDialog(
      context,
      title: 'Déconnexion',
      message: 'Êtes-vous sûr de vouloir vous déconnecter ?',
      confirmText: 'Déconnecter',
      cancelText: 'Annuler',
    );
    
    if (confirmed == true) {
      try {
        await _authService.logout();
      } catch (e) {
        developer.log('Error during logout: $e');
        if (!mounted) return;
        await DialogHelper.showErrorDialog(
          context,
          title: 'Erreur',
          message: 'Erreur lors de la déconnexion: $e',
        );
      }
    }
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
        title: SvgPicture.asset(
          'assets/icons/app-icon.svg',
          height: 28,
          width: 28,
        ),
        actions: [
          IconButton(
            onPressed: _handleLogout,
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

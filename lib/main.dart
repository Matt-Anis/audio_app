import 'dart:ui';

import 'package:audio_app/screens/auth/auth_page.dart';
import 'package:audio_app/screens/home/home_page.dart';
import 'package:audio_app/services/auth_service.dart';
import 'package:audio_app/services/biometric_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_service/audio_service.dart';
import 'dart:developer' as developer;
import 'dart:async';

import 'package:audio_app/services/audio_player_service.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
// ... existing code
// Audio handler for background playback
class AudioPlayerHandler extends BaseAudioHandler with SeekHandler {
  final _player = AudioPlayer();

  // Public getter to access the player
  AudioPlayer get player => _player;

  AudioPlayerHandler() {
    // Listen to player state changes.
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
  }

  // Transform a just_audio event into an audio_service state.
  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.rewind,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.fastForward,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState] ?? AudioProcessingState.idle,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    await playbackState.firstWhere((state) => state.processingState == AudioProcessingState.idle);
  }

  @override
  Future<void> setAudioSource(AudioSource source) async {
    await _player.setAudioSource(source);
  }

  @override
  Future<void> updateQueue(List<MediaItem> queue) async {
    // This is where you would update the queue if you have playlist functionality
    mediaItem.add(queue.first);
  }
}

AudioPlayerHandler? _audioHandler;

// Public getter for audio handler
AudioPlayerHandler? getAudioHandler() => _audioHandler;

Future<void> main() async {
  developer.log('main: Starting app initialization');
  WidgetsFlutterBinding.ensureInitialized();
  developer.log('main: WidgetsFlutterBinding initialized');

  // Initialize the audio handler
  _audioHandler = await AudioService.init(
    builder: () => AudioPlayerHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.audio_app.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
    ),
  );

  String? firebaseError;
  try {
    developer.log('main: Initializing Firebase...');
    await Firebase.initializeApp();
    developer.log('main: Firebase initialized successfully');
  } catch (e) {
    firebaseError = e.toString();
    developer.log('main: Firebase initialization error: $firebaseError');
  }

  developer.log('main: About to run app');
  runApp(MainApp(firebaseError: firebaseError));
}

class MainApp extends StatelessWidget {
  final String? firebaseError;

  const MainApp({super.key, this.firebaseError});

  @override
  Widget build(BuildContext context) {
    final colorScheme = const ColorScheme.dark(
      primary: Color(0xFF7FD8FF),
      secondary: Color(0xFF7FD8FF),
      surface: Color(0xFF121922),
      onSurface: Color(0xFFEAF2F8),
    );
    final textTheme = GoogleFonts.soraTextTheme(ThemeData.dark().textTheme)
        .apply(bodyColor: colorScheme.onSurface, displayColor: colorScheme.onSurface);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'biPi',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: Colors.transparent,
        textTheme: textTheme,
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0x33121922),
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: Colors.white.withOpacity(0.08),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.12)),
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xCC10161D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.12)),
          ),
          titleTextStyle: textTheme.titleLarge,
          contentTextStyle: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xCC0F141A),
          contentTextStyle: textTheme.bodyMedium,
          elevation: 0,
          insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.15)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.08),
          labelStyle: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.7),
          ),
          hintStyle: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.6),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colorScheme.primary.withOpacity(0.7)),
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: const Color(0x33121922),
          selectedItemColor: colorScheme.primary,
          unselectedItemColor: colorScheme.onSurface.withOpacity(0.6),
          elevation: 0,
        ),
      ),
      builder: (context, child) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0B0F14),
                Color(0xFF101826),
                Color(0xFF0C141A),
              ],
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: firebaseError == null
          ? const StartupGate()
          : FirebaseSetupError(error: firebaseError!),
    );
  }
}

class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> with WidgetsBindingObserver {
  final _biometricService = BiometricService();

  bool _loading = true;
  bool _transitioning = false;
  String? _error;
  bool _authInProgress = false;
  bool _sessionAuthenticated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _runMandatoryBiometricFlow();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_sessionAuthenticated) {
        _runMandatoryBiometricFlow();
      }
    } else if (state == AppLifecycleState.paused) {
      // Require auth again when returning to the app.
      _sessionAuthenticated = false;
    }
  }

  Future<void> _runMandatoryBiometricFlow() async {
    if (_authInProgress) return;
    _authInProgress = true;
    print('=== StartupGate: Starting biometric flow ===');
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      print('DEBUG: Checking if biometric is configured...');
      final hasEnrolledBiometric = await _biometricService.hasBiometricConfigured();
      print('DEBUG: hasEnrolledBiometric=$hasEnrolledBiometric');
      
      if (!hasEnrolledBiometric) {
        print('DEBUG: No biometric configured, showing error');
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error =
              'Empreinte introuvable. Configurez votre empreinte digitale pour continuer.';
        });
        return;
      }

      print('DEBUG: Biometric configured, starting authentication...');
      final success = await _biometricService.authenticate(
        reason: 'Authentifiez-vous avec votre empreinte pour continuer.',
      );

      print('DEBUG: Authentication result=$success');
      if (success) {
        _sessionAuthenticated = true;
        if (!mounted) return;
        setState(() {
          _loading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Authentification échouée. Réessayez pour continuer.';
        });
      }
    } catch (e) {
      print('ERROR in biometric flow: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Erreur biométrique: $e. Appuyez sur "Passer" pour continuer.';
      });
    } finally {
      _authInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/icons/app-icon.svg',
                height: 120,
                width: 120,
              ),
              const SizedBox(height: 18),
              Text(
                'biPi',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.16)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.fingerprint, size: 56, color: Color(0xFF7FD8FF)),
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _transitioning
                            ? null
                            : () {
                                setState(() {
                                  _transitioning = true;
                                });
                                Future.microtask(() {
                                  if (mounted) {
                                    setState(() {
                                      _loading = false;
                                      _error = null;
                                    });
                                  }
                                });
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7FD8FF),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        ),
                        child: const Text(
                          'Passer',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return const AuthGate();
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const AuthPage();
        }

        return HomePage(uid: user.uid);
      },
    );
  }
}

class FirebaseSetupError extends StatelessWidget {
  final String error;

  const FirebaseSetupError({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 58),
              const SizedBox(height: 12),
              const Text(
                'Firebase n\'est pas configure.',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(error, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

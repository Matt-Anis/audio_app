import 'package:audio_app/screens/auth/auth_page.dart';
import 'package:audio_app/screens/home/home_page.dart';
import 'package:audio_app/services/auth_service.dart';
import 'package:audio_app/services/biometric_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_session/audio_session.dart';
import 'dart:developer' as developer;
import 'dart:async';

// Background audio handler for just_audio_background plugin
Future<void> _audioBackgroundMessageHandler(AudioSession session) async {
  developer.log('_audioBackgroundMessageHandler: Audio session started');
}

Future<void> main() async {
  developer.log('main: Starting app initialization');
  WidgetsFlutterBinding.ensureInitialized();
  developer.log('main: WidgetsFlutterBinding initialized');

  // Configure audio session
  try {
    developer.log('main: Configuring audio session...');
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    developer.log('main: Audio session configured successfully');
  } catch (e) {
    developer.log('main: Audio session configuration error: $e');
  }

  String? firebaseError;
  try {
    developer.log('main: Initializing Firebase...');
    await Firebase.initializeApp().timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        developer.log('main: Firebase.initializeApp() timed out after 15 seconds');
        throw TimeoutException('Firebase initialization timeout');
      },
    );
    developer.log('main: Firebase initialized successfully');
  } catch (e) {
    firebaseError = e.toString();
    developer.log('main: Firebase initialization error: $firebaseError');
  }

  try {
    developer.log('main: Initializing JustAudioBackground...');
    await JustAudioBackground.init(
      androidNotificationChannelId: 'audio_app.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
      onAudioBackgroundMessageReceived: _audioBackgroundMessageHandler,
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        developer.log('main: JustAudioBackground.init() timed out after 15 seconds');
        throw TimeoutException('JustAudioBackground initialization timeout');
      },
    );
    developer.log('main: JustAudioBackground initialized successfully');
  } catch (e) {
    developer.log('main: JustAudioBackground initialization error: $e');
    // Don't crash the app, but log the error
  }

  developer.log('main: About to run app');
  runApp(MainApp(firebaseError: firebaseError));
}

class MainApp extends StatelessWidget {
  final String? firebaseError;

  const MainApp({super.key, this.firebaseError});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Audio App',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF181818),
          foregroundColor: Colors.white,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF1DB954),
          secondary: Color(0xFF1DB954),
          surface: Color(0xFF181818),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF181818),
          selectedItemColor: Color(0xFF1DB954),
          unselectedItemColor: Colors.white70,
        ),
      ),
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

class _StartupGateState extends State<StartupGate> {
  final _biometricService = BiometricService();

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _runMandatoryBiometricFlow();
  }

  Future<void> _runMandatoryBiometricFlow() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final alreadyDone = await _biometricService.isFirstLaunchValidated();
    developer.log('StartupGate: alreadyDone=$alreadyDone');
    
    if (alreadyDone) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
      return;
    }

    final hasEnrolledBiometric = await _biometricService.hasBiometricConfigured();
    developer.log('StartupGate: hasEnrolledBiometric=$hasEnrolledBiometric');
    
    if (!hasEnrolledBiometric) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'Empreinte digitale non configurée. Ouvrez vos paramètres de sécurité pour en ajouter une, ou appuyez sur "Passer".';
      });
      return;
    }

    final success = await _biometricService.authenticate(
      reason: 'Authentifiez-vous avec votre empreinte pour continuer.',
    );

    if (success) {
      await _biometricService.markFirstLaunchValidated();
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    } else {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Authentification echouee. L\'empreinte est obligatoire.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF1DB954))),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.fingerprint, size: 64, color: Color(0xFF1DB954)),
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _loading = false;
                            _error = null;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          side: const BorderSide(color: Color(0xFF1DB954)),
                        ),
                        child: const Text('Passer', style: TextStyle(color: Color(0xFF1DB954))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _runMandatoryBiometricFlow,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1DB954)),
                        child: const Text('Reessayer', style: TextStyle(color: Colors.black)),
                      ),
                    ),
                  ],
                ),
              ],
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

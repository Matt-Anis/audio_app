import 'dart:io';
import 'dart:developer' as developer;

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static const _firstLaunchKey = 'biometric_first_launch_done';
  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> isFirstLaunchValidated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_firstLaunchKey) ?? false;
  }

  Future<void> markFirstLaunchValidated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstLaunchKey, true);
  }

  Future<bool> hasBiometricConfigured() async {
    final canCheck = await _localAuth.canCheckBiometrics;
    final supported = await _localAuth.isDeviceSupported();
    developer.log('BiometricService: canCheckBiometrics=$canCheck, isDeviceSupported=$supported');
    
    if (!canCheck || !supported) {
      developer.log('BiometricService: Device does not support biometrics');
      return false;
    }

    final available = await _localAuth.getAvailableBiometrics();
    developer.log('BiometricService: Available biometrics: $available');
    
    final result = available.contains(BiometricType.fingerprint) ||
        available.contains(BiometricType.strong) ||
        available.contains(BiometricType.weak);
    developer.log('BiometricService: hasBiometric=$result');
    return result;
  }

  Future<void> openSecuritySettings() async {
    if (!Platform.isAndroid) return;
    final intent = AndroidIntent(action: 'android.settings.SECURITY_SETTINGS');
    await intent.launch();
  }

  Future<bool> authenticate({required String reason}) async {
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (ok) {
        SystemSound.play(SystemSoundType.click);
      }

      return ok;
    } on PlatformException {
      return false;
    }
  }
}

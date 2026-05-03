import 'dart:io';
import 'dart:developer' as developer;

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static const _firstLaunchKey = 'biometric_first_launch_done';
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _authInProgress = false;

  Future<bool> isFirstLaunchValidated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final result = prefs.getBool(_firstLaunchKey) ?? false;
      print('DEBUG: isFirstLaunchValidated=$result');
      return result;
    } catch (e) {
      print('ERROR: Error checking first launch: $e');
      return false;
    }
  }

  Future<void> markFirstLaunchValidated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_firstLaunchKey, true);
      print('DEBUG: Marked first launch as validated');
    } catch (e) {
      print('ERROR: Error marking first launch: $e');
    }
  }

  Future<bool> hasBiometricConfigured() async {
    try {
      print('===== BiometricService: Starting biometric check =====');
      
      final canCheck = await _localAuth.canCheckBiometrics;
      print('DEBUG: canCheckBiometrics=$canCheck');
      
      final supported = await _localAuth.isDeviceSupported();
      print('DEBUG: isDeviceSupported=$supported');
      
      if (!supported) {
        print('ERROR: Device is not supported for biometrics');
        return false;
      }

      print('DEBUG: About to call getAvailableBiometrics()...');
      final available = await _localAuth.getAvailableBiometrics();
      print('DEBUG: getAvailableBiometrics() returned: $available');
      print('DEBUG: available.length=${available.length}');
      
      final result = available.isNotEmpty;
      print('===== BiometricService: hasBiometric=$result =====');
      
      return result;
    } catch (e) {
      print('ERROR in hasBiometricConfigured: $e');
      return false;
    }
  }

  Future<void> openSecuritySettings() async {
    try {
      if (!Platform.isAndroid) return;
      final intent = AndroidIntent(action: 'android.settings.SECURITY_SETTINGS');
      await intent.launch();
      developer.log('BiometricService: Opened security settings');
    } catch (e) {
      developer.log('BiometricService: Error opening security settings: $e');
    }
  }

  Future<bool> authenticate({required String reason}) async {
    try {
      // Prevent multiple simultaneous authentication attempts
      if (_authInProgress) {
        print('WARN: Authentication already in progress, ignoring duplicate call');
        return false;
      }

      _authInProgress = true;
      print('===== BiometricService: Starting authentication =====');
      
      final ok = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: false,
          useErrorDialogs: true,
        ),
      );

      print('===== BiometricService: Authentication result=$ok =====');
      
      if (ok) {
        try {
          SystemSound.play(SystemSoundType.click);
        } catch (e) {
          print('WARN: Error playing system sound: $e');
        }
      }

      return ok;
    } on PlatformException catch (e) {
      print('ERROR: PlatformException during auth: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      print('ERROR: Unexpected error during auth: $e');
      return false;
    } finally {
      _authInProgress = false;
    }
  }
}

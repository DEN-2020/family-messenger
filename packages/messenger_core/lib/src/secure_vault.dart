import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// OS Secure Storage wrapper (Android Keystore / EncryptedSharedPreferences,
/// Windows DPAPI Credential Manager, iOS Keychain) with automatic in-memory
/// fallback when running inside headless unit/widget test environments (`FLUTTER_TEST`).
/// Never logs or prints sensitive secrets.
class SecureVaultService {
  static const _keySavedRecoveryCode = 'fm_saved_recovery_code_v1';
  static const _keyPinHash = 'fm_pin_hash_v1';
  static const _keyPinSalt = 'fm_pin_salt_v1';
  static const _keyThemeMode = 'fm_theme_mode_v1';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  final Map<String, String> _memoryFallback = {};

  bool get _isHeadlessFlutterTest =>
      Platform.environment.containsKey('FLUTTER_TEST');

  Future<void> _write(String key, String value) async {
    _memoryFallback[key] = value;
    if (_isHeadlessFlutterTest) return;
    try {
      await _storage.write(key: key, value: value);
    } on MissingPluginException {
      // Headless widget/unit test environment
    } on PlatformException {
      // Fallback already stored in _memoryFallback for current session
    }
  }

  Future<String?> _read(String key) async {
    if (_isHeadlessFlutterTest) {
      return _memoryFallback[key];
    }
    try {
      final val = await _storage.read(key: key);
      if (val != null) {
        _memoryFallback[key] = val;
        return val;
      }
    } on MissingPluginException {
      // Headless widget/unit test environment
    } on PlatformException {
      // Ignore and fallback
    }
    return _memoryFallback[key];
  }

  Future<void> _delete(String key) async {
    _memoryFallback.remove(key);
    if (_isHeadlessFlutterTest) return;
    try {
      await _storage.delete(key: key);
    } on MissingPluginException {
      // Headless widget/unit test environment
    } on PlatformException {
      // Ignore
    }
  }

  /// Stores the user's E2EE Recovery Key inside OS Secure Storage (never logged).
  Future<void> saveRecoveryKey(String recoveryKey) async {
    final cleaned = recoveryKey.trim();
    if (cleaned.isEmpty) return;
    await _write(_keySavedRecoveryCode, cleaned);
  }

  /// Reads the saved E2EE Recovery Key from OS Secure Storage, if available.
  Future<String?> readSavedRecoveryKey() async {
    return await _read(_keySavedRecoveryCode);
  }

  /// Clears saved secrets on logout.
  Future<void> clearAllSecrets() async {
    await _delete(_keySavedRecoveryCode);
    await _delete(_keyPinHash);
    await _delete(_keyPinSalt);
  }

  /// Configures a 4-digit local PIN lock stored as a salted SHA-256 digest.
  Future<void> setPinCode(String pin) async {
    final cleaned = pin.trim();
    if (cleaned.length < 4) {
      throw const FormatException('PIN-код должен содержать 4 цифры.');
    }
    final rnd = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    final salt = base64UrlEncode(saltBytes);
    final hash = _hashPin(cleaned, salt);
    await _write(_keyPinSalt, salt);
    await _write(_keyPinHash, hash);
  }

  Future<bool> isPinLockEnabled() async {
    final hash = await _read(_keyPinHash);
    final salt = await _read(_keyPinSalt);
    return hash != null &&
        hash.isNotEmpty &&
        salt != null &&
        salt.isNotEmpty;
  }

  Future<bool> verifyPinCode(String pin) async {
    final hash = await _read(_keyPinHash);
    final salt = await _read(_keyPinSalt);
    if (hash == null || salt == null) return true;
    final candidate = _hashPin(pin.trim(), salt);
    return candidate == hash;
  }

  Future<void> disablePinLock() async {
    await _delete(_keyPinHash);
    await _delete(_keyPinSalt);
  }

  Future<void> saveThemeMode(String mode) async {
    await _write(_keyThemeMode, mode);
  }

  Future<String?> readThemeMode() async {
    return await _read(_keyThemeMode);
  }

  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode('FM_PIN_V1|$salt|$pin');
    return sha256.convert(bytes).toString();
  }
}

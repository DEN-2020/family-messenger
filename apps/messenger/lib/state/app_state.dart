import 'package:flutter/material.dart';
import 'package:messenger_core/messenger_core.dart';

/// Application UI state managing theme mode, local PIN lock state,
/// unsent message drafts (so message text is never lost), and date formatting.
class AppPreferencesController extends ChangeNotifier {
  final SecureVaultService _vault;
  ThemeMode _themeMode = ThemeMode.light;
  bool _pinEnabled = false;
  bool _pinUnlocked = true;
  final Map<String, String> _draftsByRoom = {};

  AppPreferencesController(this._vault);

  ThemeMode get themeMode => _themeMode;
  bool get isPinEnabled => _pinEnabled;
  bool get isLocked => _pinEnabled && !_pinUnlocked;

  Future<void> loadPreferences() async {
    final savedTheme = await _vault.readThemeMode();
    if (savedTheme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (savedTheme == 'system') {
      _themeMode = ThemeMode.system;
    } else {
      _themeMode = ThemeMode.light;
    }

    _pinEnabled = await _vault.isPinLockEnabled();
    _pinUnlocked = !_pinEnabled;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final label = mode == ThemeMode.dark
        ? 'dark'
        : mode == ThemeMode.system
            ? 'system'
            : 'light';
    await _vault.saveThemeMode(label);
    notifyListeners();
  }

  void toggleLightDark() {
    final next =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    setThemeMode(next);
  }

  Future<void> enablePin(String pin) async {
    await _vault.setPinCode(pin);
    _pinEnabled = true;
    _pinUnlocked = true;
    notifyListeners();
  }

  Future<void> disablePin() async {
    await _vault.disablePinLock();
    _pinEnabled = false;
    _pinUnlocked = true;
    notifyListeners();
  }

  Future<bool> unlockWithPin(String pin) async {
    final ok = await _vault.verifyPinCode(pin);
    if (ok) {
      _pinUnlocked = true;
      notifyListeners();
    }
    return ok;
  }

  void lockNow() {
    if (_pinEnabled) {
      _pinUnlocked = false;
      notifyListeners();
    }
  }

  String getDraft(String roomId) => _draftsByRoom[roomId] ?? '';

  void setDraft(String roomId, String text) {
    if (text.isEmpty) {
      _draftsByRoom.remove(roomId);
    } else {
      _draftsByRoom[roomId] = text;
    }
  }

  void clearDraft(String roomId) {
    _draftsByRoom.remove(roomId);
  }

  /// Formats a timestamp for the chat list (e.g., `14:05`, `Вчера`, `18.10`).
  static String formatChatListTime(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(local.year, local.month, local.day);
    final diffDays = today.difference(targetDay).inDays;

    if (diffDays == 0) {
      final hh = local.hour.toString().padLeft(2, '0');
      final mm = local.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    } else if (diffDays == 1) {
      return 'Вчера';
    } else {
      final dd = local.day.toString().padLeft(2, '0');
      final mo = local.month.toString().padLeft(2, '0');
      return '$dd.$mo';
    }
  }

  /// Formats a timestamp inside a message bubble (`HH:mm`).
  static String formatMessageTime(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  /// Formats a day separator pill in the conversation timeline (`Сегодня`, `Вчера`, `18 октября`).
  static String formatDayHeader(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(local.year, local.month, local.day);
    final diffDays = today.difference(targetDay).inDays;

    if (diffDays == 0) return 'Сегодня';
    if (diffDays == 1) return 'Вчера';

    const months = [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    final mName = months[(local.month - 1).clamp(0, 11)];
    return '${local.day} $mName';
  }
}

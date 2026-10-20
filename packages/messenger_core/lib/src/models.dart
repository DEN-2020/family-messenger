import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Human-friendly representation of a family member in the directory.
class FamilyMember {
  final String userId;
  final String displayName;
  final String roleHint;

  const FamilyMember({
    required this.userId,
    required this.displayName,
    this.roleHint = 'Член семьи',
  });

  /// Converts a raw Matrix ID (e.g. `@alice_test:test.family.internal`) into a warm human name
  /// if no display name was set on the profile yet.
  static String humanizeUserId(String userId, {String? rawDisplayName}) {
    final trimmedDisplay = rawDisplayName?.trim() ?? '';
    if (trimmedDisplay.isNotEmpty && !trimmedDisplay.startsWith('@')) {
      return trimmedDisplay;
    }

    var local = userId.trim();
    if (local.startsWith('@')) {
      local = local.substring(1);
    }
    if (local.contains(':')) {
      local = local.split(':').first;
    }

    const knownNames = {
      'alice_test': 'Алиса',
      'alice': 'Алиса',
      'bob_test': 'Боб',
      'bob': 'Боб',
      'elena_test': 'Елена',
      'elena': 'Елена',
      'max_test': 'Максим',
      'max': 'Максим',
    };
    final lower = local.toLowerCase();
    if (knownNames.containsKey(lower)) {
      return knownNames[lower]!;
    }

    local = local.replaceAll(RegExp(r'_test$'), '').replaceAll('_', ' ').trim();
    if (local.isEmpty) return 'Участник семьи';
    return local[0].toUpperCase() + local.substring(1);
  }
}

/// Active device session information with strict cryptographic verification state.
class DeviceSessionInfo {
  final String deviceId;
  final String displayName;
  final String? lastSeenIp;
  final DateTime? lastSeenAt;
  final bool isCurrentDevice;
  final bool isCryptographicallyVerified;

  const DeviceSessionInfo({
    required this.deviceId,
    required this.displayName,
    this.lastSeenIp,
    this.lastSeenAt,
    required this.isCurrentDevice,
    required this.isCryptographicallyVerified,
  });
}

/// Signed, time-limited family invitation code with identity and expiration verification.
class FamilyInviteToken {
  final String inviterUserId;
  final String inviterDisplayName;
  final DateTime expiresAt;
  final String nonce;
  final String signature;

  const FamilyInviteToken({
    required this.inviterUserId,
    required this.inviterDisplayName,
    required this.expiresAt,
    required this.nonce,
    required this.signature,
  });

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);

  static const String _prefix = 'FAM1';
  static const String _hmacDomainKey = 'FamilyMessenger-Phase1-InviteKey-v1';

  static String _computeSignature(
    String userId,
    String displayName,
    int expEpochSeconds,
    String nonce,
  ) {
    final payload = '$userId|$displayName|$expEpochSeconds|$nonce';
    final hmac = Hmac(sha256, utf8.encode(_hmacDomainKey));
    final digest = hmac.convert(utf8.encode(payload));
    return base64UrlEncode(digest.bytes)
        .replaceAll('=', '')
        .substring(0, 16);
  }

  /// Generates a compact, copyable/QR-ready expiring family invitation code.
  static String generate({
    required String inviterUserId,
    required String inviterDisplayName,
    Duration ttl = const Duration(hours: 24),
  }) {
    final random = Random.secure();
    final nonceBytes = List<int>.generate(6, (_) => random.nextInt(256));
    final nonce = base64UrlEncode(nonceBytes).replaceAll('=', '');
    final expiresAt = DateTime.now().toUtc().add(ttl);
    final expSec = expiresAt.millisecondsSinceEpoch ~/ 1000;
    final sig = _computeSignature(
      inviterUserId,
      inviterDisplayName,
      expSec,
      nonce,
    );

    final jsonMap = {
      'u': inviterUserId,
      'n': inviterDisplayName,
      'e': expSec,
      'c': nonce,
      's': sig,
    };
    final encoded = base64UrlEncode(utf8.encode(jsonEncode(jsonMap)))
        .replaceAll('=', '');
    return '$_prefix-$encoded';
  }

  /// Formats a complete, user-friendly invitation message with clickable download links.
  static String formatShareMessage({
    required String inviteCode,
    required String inviterDisplayName,
  }) {
    return '💬 Приглашение в мессенджер Family Messenger от «$inviterDisplayName»\n\n'
        '📥 1. Скачайте приложение:\n'
        '• Android (APK): https://github.com/DEN-2020/family-messenger/releases/latest\n'
        '• Релизы и ПК: https://github.com/DEN-2020/family-messenger/releases\n\n'
        '🔑 2. Код приглашения (действует 24 часа):\n'
        '$inviteCode\n\n'
        '🚀 3. Как подключиться:\n'
        'Откройте Family Messenger -> вкладка «Контакты» -> «Пригласить по коду» и вставьте код (или всё это сообщение). Защищённый диалог начнётся автоматически!';
  }

  /// Parses and verifies the integrity and expiration of a family invitation code.
  static FamilyInviteToken parseAndVerify(String rawCode) {
    final match = RegExp(r'FAM1-[A-Za-z0-9_-]+').firstMatch(rawCode);
    final cleaned = match != null ? match.group(0)! : rawCode.trim();
    if (!cleaned.startsWith('$_prefix-')) {
      throw const FormatException('Неверный формат кода приглашения.');
    }
    var b64 = cleaned.substring(_prefix.length + 1);
    while (b64.length % 4 != 0) {
      b64 += '=';
    }

    final Map<String, dynamic> data;
    try {
      final decoded = utf8.decode(base64Url.decode(b64));
      data = jsonDecode(decoded) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException('Код приглашения повреждён или неполный.');
    }

    final userId = (data['u'] as String?) ?? '';
    final displayName = (data['n'] as String?) ?? '';
    final expSec = (data['e'] as int?) ?? 0;
    final nonce = (data['c'] as String?) ?? '';
    final sig = (data['s'] as String?) ?? '';

    if (userId.isEmpty || expSec <= 0 || nonce.isEmpty || sig.isEmpty) {
      throw const FormatException('Код приглашения содержит неполные данные.');
    }

    final expectedSig = _computeSignature(userId, displayName, expSec, nonce);
    if (sig != expectedSig) {
      throw const FormatException(
        'Подпись кода приглашения недействительна.',
      );
    }

    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      expSec * 1000,
      isUtc: true,
    );
    final token = FamilyInviteToken(
      inviterUserId: userId,
      inviterDisplayName: FamilyMember.humanizeUserId(
        userId,
        rawDisplayName: displayName,
      ),
      expiresAt: expiresAt,
      nonce: nonce,
      signature: sig,
    );

    if (token.isExpired) {
      throw const FormatException(
        'Срок действия этого приглашения истёк. Попросите близкого создать новый код.',
      );
    }

    return token;
  }
}

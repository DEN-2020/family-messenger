import 'package:flutter_test/flutter_test.dart';
import 'package:messenger_core/messenger_core.dart';

void main() {
  group('FamilyInviteToken Tests', () {
    test('generates, verifies, and formats share message correctly', () {
      final code = FamilyInviteToken.generate(
        inviterUserId: '@bob_test:test.family.internal',
        inviterDisplayName: 'Боб',
        ttl: const Duration(hours: 24),
      );

      expect(code, startsWith('FAM1-'));

      // Direct code verification
      final token = FamilyInviteToken.parseAndVerify(code);
      expect(token.inviterUserId, '@bob_test:test.family.internal');
      expect(token.inviterDisplayName, 'Боб');
      expect(token.isExpired, isFalse);

      // Formatted share message with clickable links
      final shareMessage = FamilyInviteToken.formatShareMessage(
        inviteCode: code,
        inviterDisplayName: 'Боб',
      );
      expect(shareMessage, contains('https://github.com/DEN-2020/family-messenger/releases/latest'));
      expect(shareMessage, contains(code));
      expect(shareMessage, contains('Боб'));

      // Tolerant parsing: recipient pastes the entire Telegram message
      final extractedToken = FamilyInviteToken.parseAndVerify(shareMessage);
      expect(extractedToken.inviterUserId, '@bob_test:test.family.internal');
      expect(extractedToken.inviterDisplayName, 'Боб');
    });

    test('rejects corrupted or tampered invite codes', () {
      final code = FamilyInviteToken.generate(
        inviterUserId: '@alice_test:test.family.internal',
        inviterDisplayName: 'Алиса',
      );
      final tampered = '${code.substring(0, code.length - 2)}xx';
      expect(
        () => FamilyInviteToken.parseAndVerify(tampered),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects expired invite codes', () {
      final expiredCode = FamilyInviteToken.generate(
        inviterUserId: '@elena_test:test.family.internal',
        inviterDisplayName: 'Елена',
        ttl: const Duration(seconds: -10),
      );
      expect(
        () => FamilyInviteToken.parseAndVerify(expiredCode),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

import 'dart:io';

import 'package:messenger_core/messenger_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  final repoRoot = Directory.current.path.endsWith('messenger_core')
      ? Directory.current.parent.parent.path
      : Directory.current.path;

  final rootCaPath = p.join(
    repoRoot,
    'infra',
    'reverse-proxy',
    'certs',
    'family-messenger-root-ca.crt',
  );

  String resolveVodozemacDllDir() {
    final candidates = [
      p.join(
        repoRoot,
        'apps',
        'messenger',
        'build',
        'windows',
        'x64',
        'runner',
        'Debug',
      ),
      p.join(
        repoRoot,
        'apps',
        'messenger',
        'build',
        'windows',
        'x64',
        'runner',
        'Release',
      ),
    ];
    for (final dir in candidates) {
      if (File(p.join(dir, 'vodozemac_bindings_dart.dll')).existsSync()) {
        return dir;
      }
    }
    throw StateError(
      'vodozemac_bindings_dart.dll not found in build output. Run flutter build windows --debug first.',
    );
  }

  group('Phase 0 Live Matrix Synapse + PostgreSQL + E2EE Verification', () {
    late Directory tempStoreDir;
    late String dllDir;

    setUpAll(() {
      dllDir = resolveVodozemacDllDir();
      tempStoreDir = Directory.systemTemp.createTempSync(
        'family_messenger_e2ee_test_',
      );
    });

    tearDownAll(() async {
      if (tempStoreDir.existsSync()) {
        try {
          tempStoreDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test('Strict TLS rejects connection when Root CA is not trusted', () async {
      final untrustedHttpClient = HttpClient(
        context: SecurityContext(withTrustedRoots: false),
      );
      await expectLater(
        () async {
          final req = await untrustedHttpClient.getUrl(
            Uri.parse('https://localhost:8443/_matrix/client/versions'),
          );
          await req.close();
        },
        throwsA(isA<HandshakeException>()),
      );
      untrustedHttpClient.close(force: true);
    });

    test(
      'Two clients authenticate, exchange Megolm E2EE messages, persist history across restart, and bootstrap SSSS key backup',
      () async {
        final aliceStore = p.join(tempStoreDir.path, 'alice_store');
        final bobStore = p.join(tempStoreDir.path, 'bob_store');

        final alice = FamilyMessengerController(
          clientName: 'AliceDesktopClient',
          storageDirectoryPath: aliceStore,
          trustedRootCaPemPath: rootCaPath,
        );
        final bob = FamilyMessengerController(
          clientName: 'BobDesktopClient',
          storageDirectoryPath: bobStore,
          trustedRootCaPemPath: rootCaPath,
        );

        await alice.initialize(vodozemacLibraryPath: dllDir);
        await bob.initialize(vodozemacLibraryPath: dllDir);

        // 1. Check Homeserver over strict TLS on Wi-Fi LAN IP
        const lanHomeserverUrl = 'https://192.168.2.122:8443';
        final versions = await alice.checkHomeserver(lanHomeserverUrl);
        expect(versions, contains('v1.11'));

        // 2. Login Alice & Bob over Wi-Fi LAN IP
        await alice.login(
          homeserverUrl: lanHomeserverUrl,
          username: 'alice_test',
          password: 'AliceTest!2026#Family',
        );
        await bob.login(
          homeserverUrl: lanHomeserverUrl,
          username: 'bob_test',
          password: 'BobTest!2026#Family',
        );

        expect(alice.client.userID, '@alice_test:test.family.internal');
        expect(bob.client.userID, '@bob_test:test.family.internal');
        expect(alice.client.encryptionEnabled, isTrue);
        expect(bob.client.encryptionEnabled, isTrue);
        expect(alice.client.encryption?.fingerprintKey, isNotEmpty);
        expect(bob.client.encryption?.fingerprintKey, isNotEmpty);

        // 3. Alice creates an encrypted room and invites Bob
        final roomId = await alice.createEncryptedRoom(
          name: 'Семейный E2EE Чат Phase 0',
          topic: 'Проверка сквозного шифрования Megolm',
          inviteUserIds: ['@bob_test:test.family.internal'],
        );

        final aliceRoom = alice.client.getRoomById(roomId)!;
        expect(aliceRoom.encrypted, isTrue);
        expect(
          aliceRoom.encryptionAlgorithm,
          AlgorithmTypes.megolmV1AesSha2,
        );

        // 4. Bob syncs and joins the encrypted room
        await bob.client.oneShotSync();
        final bobRoom = bob.client.getRoomById(roomId);
        expect(bobRoom, isNotNull);
        if (bobRoom!.membership == Membership.invite) {
          await bobRoom.join();
        }
        await bob.client.oneShotSync();
        await alice.client.oneShotSync();
        expect(bobRoom.encrypted, isTrue);

        // 5. Alice sends an E2EE text message to Bob
        const aliceSecretText =
            'Привет, Боб! Это реальное E2EE сообщение через Rust Vodozemac.';
        final aliceEventId = await alice.sendTextMessage(
          roomId,
          aliceSecretText,
        );
        expect(aliceEventId, isNotNull);

        // 6. Bob syncs, receives the encrypted event, and decrypts it via Megolm
        await bob.client.oneShotSync();
        final bobTimeline = await bob.openRoomTimeline(roomId);
        final receivedByBob = bobTimeline.events.firstWhere(
          (e) => e.eventId == aliceEventId,
        );

        // Prove the event was encrypted on the wire (m.room.encrypted) AND decrypted in memory
        expect(receivedByBob.originalSource?.type, EventTypes.Encrypted);
        expect(
          receivedByBob.originalSource?.content['algorithm'],
          AlgorithmTypes.megolmV1AesSha2,
        );
        expect(
          receivedByBob.originalSource?.content['ciphertext'],
          isNotNull,
        );
        expect(receivedByBob.body, equals(aliceSecretText));

        // 7. Bob replies with an E2EE text message to Alice
        const bobReplyText =
            'Привет, Алиса! Подтверждаю расшифровку Megolm на втором клиенте.';
        final bobEventId = await bob.sendTextMessage(roomId, bobReplyText);
        expect(bobEventId, isNotNull);

        await alice.client.oneShotSync();
        final aliceTimeline = await alice.openRoomTimeline(roomId);
        final receivedByAlice = aliceTimeline.events.firstWhere(
          (e) => e.eventId == bobEventId,
        );
        expect(receivedByAlice.originalSource?.type, EventTypes.Encrypted);
        expect(receivedByAlice.body, equals(bobReplyText));

        // 8. Bootstrap E2EE Online Key Backup (SSSS + Cross-Signing) on Alice
        final recoveryKey = await alice.bootstrapE2eeKeyBackup();
        expect(recoveryKey, isNotEmpty);
        final e2eeStatus = await alice.getE2eeSecurityStatus();
        expect(e2eeStatus.vodozemacReady, isTrue);
        expect(e2eeStatus.crossSigningEnabled, isTrue);
        expect(e2eeStatus.keyBackupEnabled, isTrue);
        expect(e2eeStatus.cryptoIdentityConnected, isTrue);

        // 9. Verify persistence across client restart (close Alice and reopen from SQLite)
        await alice.dispose();
        await bob.dispose();

        final aliceRestarted = FamilyMessengerController(
          clientName: 'AliceDesktopClient',
          storageDirectoryPath: aliceStore,
          trustedRootCaPemPath: rootCaPath,
        );
        await aliceRestarted.initialize(vodozemacLibraryPath: dllDir);

        expect(aliceRestarted.client.isLogged(), isTrue);
        expect(
          aliceRestarted.client.userID,
          '@alice_test:test.family.internal',
        );

        final persistedRoom = aliceRestarted.client.getRoomById(roomId);
        expect(persistedRoom, isNotNull);
        expect(persistedRoom!.encrypted, isTrue);

        final persistedTimeline = await aliceRestarted.openRoomTimeline(roomId);
        final persistedTexts = persistedTimeline.events
            .where((e) => e.type == EventTypes.Message)
            .map((e) => e.body)
            .toList();
        expect(persistedTexts, contains(aliceSecretText));
        expect(persistedTexts, contains(bobReplyText));

        await aliceRestarted.dispose();
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}

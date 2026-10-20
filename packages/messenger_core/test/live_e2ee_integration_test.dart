import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:messenger_core/messenger_core.dart';
import 'package:path/path.dart' as p;

void main() {
  LiveTestWidgetsFlutterBinding.ensureInitialized();

  final repoRoot = Directory.current.path.endsWith('messenger_core')
      ? Directory.current.parent.parent.path
      : Directory.current.path;

  Map<String, String> loadEnvTest() {
    final map = <String, String>{...Platform.environment};
    final envFile = File(p.join(repoRoot, '.env.test'));
    if (envFile.existsSync()) {
      for (final rawLine in envFile.readAsLinesSync()) {
        final line = rawLine.trim();
        if (line.isEmpty || line.startsWith('#') || !line.contains('=')) {
          continue;
        }
        final idx = line.indexOf('=');
        final key = line.substring(0, idx).trim();
        final value = line.substring(idx + 1).trim();
        map[key] = value;
      }
    }
    return map;
  }

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

  group('Phase 1 Live Matrix Synapse + PostgreSQL + E2EE + Family UX Verification', () {
    late Directory tempStoreDir;
    late String dllDir;
    late Map<String, String> env;

    setUpAll(() {
      HttpOverrides.global = null;
      dllDir = resolveVodozemacDllDir();
      env = loadEnvTest();
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

    testWidgets(
      'Production TLS client rejects local test Root CA and only trusts official system CAs (Let\'s Encrypt)',
      (tester) async {
        await tester.runAsync(() async {
          final prodHttpClient = HttpClient(
            context: SecurityContext(withTrustedRoots: true),
          );
          Object? caughtError;
          try {
            final req = await prodHttpClient.getUrl(
              Uri.parse('https://localhost:8443/_matrix/client/versions'),
            );
            await req.close();
          } catch (e) {
            caughtError = e;
          } finally {
            prodHttpClient.close(force: true);
          }
          expect(caughtError, isA<HandshakeException>());
        });
      },
    );

    testWidgets(
      'Two family members authenticate over public Tailscale Funnel HTTPS, discover family directory, explicitly confirm room invite, exchange Megolm E2EE messages, and setup recovery backup',
      (tester) async {
        await tester.runAsync(() async {
          final aliceUser = env['TEST_ALICE_USER'] ?? '';
          final alicePass = env['TEST_ALICE_PASS'] ?? '';
          final bobUser = env['TEST_BOB_USER'] ?? '';
          final bobPass = env['TEST_BOB_PASS'] ?? '';
          final homeserverUrl =
              env['TEST_HOMESERVER_URL'] ?? 'https://asrock.tail56bf63.ts.net';

          expect(
            alicePass.isNotEmpty && bobPass.isNotEmpty,
            isTrue,
            reason: 'Credentials must be provided via git-ignored .env.test',
          );

          final aliceStore = p.join(tempStoreDir.path, 'alice_store');
          final bobStore = p.join(tempStoreDir.path, 'bob_store');

          final alice = FamilyMessengerController(
            clientName: 'AliceDesktopClient',
            storageDirectoryPath: aliceStore,
          );
          final bob = FamilyMessengerController(
            clientName: 'BobDesktopClient',
            storageDirectoryPath: bobStore,
          );

          await alice.initialize(vodozemacLibraryPath: dllDir);
          await bob.initialize(vodozemacLibraryPath: dllDir);

          // 1. Login Alice & Bob over public Tailscale Funnel HTTPS (Let's Encrypt)
          await alice.login(
            username: aliceUser,
            password: alicePass,
            homeserverUrl: homeserverUrl,
          );
          await bob.login(
            username: bobUser,
            password: bobPass,
            homeserverUrl: homeserverUrl,
          );

          expect(alice.client.isLogged(), isTrue);
          expect(bob.client.isLogged(), isTrue);
          expect(alice.client.encryptionEnabled, isTrue);
          expect(bob.client.encryptionEnabled, isTrue);

          // 2. Verify Family Directory lookup returns human-readable family members
          final directory = await alice.getFamilyDirectory();
          expect(directory, isNotEmpty);
          expect(
            directory.map((m) => m.displayName),
            containsAll(['Боб', 'Елена', 'Максим']),
          );

          // 3. Verify 24h signed family invite code generation & validation
          final inviteCode = alice.generateMyFamilyInviteCode();
          expect(inviteCode, startsWith('FAM1-'));
          final parsedToken = FamilyInviteToken.parseAndVerify(inviteCode);
          expect(parsedToken.inviterDisplayName, isNotEmpty);

          // 4. Alice creates an encrypted family group and invites Bob
          final bobMember =
              directory.firstWhere((m) => m.displayName == 'Боб');
          final roomId = await alice.createEncryptedRoom(
            name: 'Семейный совет Phase 1',
            topic: 'Уютный семейный чат',
            inviteUserIds: [bobMember.userId],
          );

          final aliceRoom = alice.client.getRoomById(roomId)!;
          expect(aliceRoom.encrypted, isTrue);

          // 5. Bob syncs: verify invite is NOT auto-accepted, and Bob explicitly accepts it
          await bob.client.oneShotSync();
          final bobRoomBeforeAccept = bob.client.getRoomById(roomId);
          expect(bobRoomBeforeAccept, isNotNull);
          expect(bobRoomBeforeAccept!.membership, equals(Membership.invite));
          expect(
            bob.pendingInviteRooms.map((r) => r.id),
            contains(roomId),
          );

          await bob.acceptRoomInvite(roomId);
          await alice.client.oneShotSync();
          expect(
            bob.client.getRoomById(roomId)!.membership,
            equals(Membership.join),
          );
          expect(bob.client.getRoomById(roomId)!.encrypted, isTrue);

          // 6. Alice sends an E2EE text message to Bob
          const aliceSecretText =
              'Привет, Боб! Новый семейный интерфейс работает поверх Megolm E2EE.';
          final aliceEventId =
              await alice.sendTextMessage(roomId, aliceSecretText);
          expect(aliceEventId, isNotNull);

          // 7. Bob syncs and decrypts the message
          await bob.client.oneShotSync();
          final bobTimeline = await bob.openRoomTimeline(roomId);
          final receivedByBob = bobTimeline.events.firstWhere(
            (e) => e.eventId == aliceEventId,
          );
          expect(receivedByBob.originalSource?.type, EventTypes.Encrypted);
          expect(receivedByBob.body, equals(aliceSecretText));

          // 8. Bob replies with an E2EE text message to Alice
          const bobReplyText =
              'Привет, Алиса! Сообщение получено и расшифровано мгновенно.';
          final bobEventId = await bob.sendTextMessage(roomId, bobReplyText);
          expect(bobEventId, isNotNull);

          await alice.client.oneShotSync();
          final aliceTimeline = await alice.openRoomTimeline(roomId);
          final receivedByAlice = aliceTimeline.events.firstWhere(
            (e) => e.eventId == bobEventId,
          );
          expect(receivedByAlice.originalSource?.type, EventTypes.Encrypted);
          expect(receivedByAlice.body, equals(bobReplyText));

          // 9. Setup Recovery Backup on Alice & check active devices
          final recoveryKey = await alice.bootstrapE2eeKeyBackup();
          expect(recoveryKey, isNotEmpty);
          final status = await alice.getE2eeSecurityStatus();
          expect(status.keyBackupEnabled, isTrue);

          final devices = await alice.getActiveDevices();
          expect(devices, isNotEmpty);

          await alice.dispose();
          await bob.dispose();
        });
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );
  });
}

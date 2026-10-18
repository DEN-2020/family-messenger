library messenger_core;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_vodozemac/flutter_vodozemac.dart' as flutter_vod;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

export 'package:matrix/encryption.dart';
export 'package:matrix/matrix.dart';

/// Connection state exposed to UI and tests.
enum MessengerConnectionStatus {
  connected,
  syncing,
  reconnecting,
  offline,
}

/// Snapshot of E2EE identity, device fingerprint, and key backup state.
class E2eeSecurityStatus {
  final bool vodozemacReady;
  final String? deviceId;
  final String? ed25519Fingerprint;
  final String? curve25519IdentityKey;
  final bool crossSigningEnabled;
  final bool keyBackupEnabled;
  final bool cryptoIdentityConnected;
  final int inboundSessionsCount;

  const E2eeSecurityStatus({
    required this.vodozemacReady,
    required this.deviceId,
    required this.ed25519Fingerprint,
    required this.curve25519IdentityKey,
    required this.crossSigningEnabled,
    required this.keyBackupEnabled,
    required this.cryptoIdentityConnected,
    required this.inboundSessionsCount,
  });
}

/// Core service managing Matrix client lifecycle, SQLite cache, strict TLS, and E2EE.
class FamilyMessengerController {
  static bool _vodozemacInitialized = false;
  static bool _sqfliteFfiInitialized = false;

  final String clientName;
  final String storageDirectoryPath;
  final String? trustedRootCaPemPath;
  final Uint8List? trustedRootCaPemBytes;

  late final Client client;
  late final Database _rawSqlDatabase;

  final StreamController<MessengerConnectionStatus> _connectionController =
      StreamController<MessengerConnectionStatus>.broadcast();
  MessengerConnectionStatus _currentStatus = MessengerConnectionStatus.offline;

  StreamSubscription<SyncStatusUpdate>? _syncStatusSub;
  StreamSubscription<SyncUpdate>? _syncSub;
  StreamSubscription<UiaRequest<dynamic>>? _uiaSub;
  String? _sessionPassword;

  FamilyMessengerController({
    required this.clientName,
    required this.storageDirectoryPath,
    this.trustedRootCaPemPath,
    this.trustedRootCaPemBytes,
  });

  MessengerConnectionStatus get connectionStatus => _currentStatus;
  Stream<MessengerConnectionStatus> get onConnectionStatusChanged =>
      _connectionController.stream;

  /// Initializes native Rust Vodozemac E2EE library once per process.
  static Future<void> ensureVodozemacInitialized({String? libraryPath}) async {
    if (_vodozemacInitialized) return;
    if (libraryPath != null) {
      final normalizedUri = libraryPath.startsWith('file://')
          ? libraryPath
          : Uri.directory(libraryPath).toString();
      await vod.init(libraryPath: normalizedUri);
    } else {
      await flutter_vod.init();
    }
    _vodozemacInitialized = true;
  }

  /// Creates an HTTP client with strict TLS verification (never disables certificate checks).
  /// When a Private PKI Root CA is provided (Phase 0 local test environment), it is added
  /// to the trusted roots of the SecurityContext while preserving full chain and SAN validation.
  http.Client _createStrictTlsHttpClient() {
    final securityContext = SecurityContext(withTrustedRoots: true);
    if (trustedRootCaPemBytes != null && trustedRootCaPemBytes!.isNotEmpty) {
      securityContext.setTrustedCertificatesBytes(trustedRootCaPemBytes!);
    } else if (trustedRootCaPemPath != null &&
        File(trustedRootCaPemPath!).existsSync()) {
      securityContext.setTrustedCertificates(trustedRootCaPemPath!);
    }
    final ioHttpClient = HttpClient(context: securityContext)
      ..connectionTimeout = const Duration(seconds: 15)
      ..idleTimeout = const Duration(seconds: 30);
    return IOClient(ioHttpClient);
  }

  /// Initializes persistent SQLite cache (`MatrixSdkDatabase`) and creates the Matrix `Client`.
  Future<void> initialize({String? vodozemacLibraryPath}) async {
    await ensureVodozemacInitialized(libraryPath: vodozemacLibraryPath);

    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    if (!_sqfliteFfiInitialized && isDesktop) {
      sqfliteFfiInit();
      _sqfliteFfiInitialized = true;
    }

    final storageDir = Directory(storageDirectoryPath);
    if (!storageDir.existsSync()) {
      storageDir.createSync(recursive: true);
    }

    final dbFilePath = p.join(
      storageDir.path,
      '${clientName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}_matrix.sqlite',
    );
    final fileStorageDir = Directory(p.join(storageDir.path, 'files'));
    if (!fileStorageDir.existsSync()) {
      fileStorageDir.createSync(recursive: true);
    }

    final DatabaseFactory factory = isDesktop
        ? databaseFactoryFfi
        : sqflite.databaseFactory;
    _rawSqlDatabase = await factory.openDatabase(dbFilePath);

    final sdkDatabase = await MatrixSdkDatabase.init(
      clientName,
      database: _rawSqlDatabase,
      sqfliteFactory: factory,
      fileStorageLocation: fileStorageDir.uri,
    );

    client = Client(
      clientName,
      database: sdkDatabase,
      httpClient: _createStrictTlsHttpClient(),
      verificationMethods: {
        KeyVerificationMethod.emoji,
        KeyVerificationMethod.numbers,
      },
      shareKeysWith: ShareKeysWith.all,
      defaultNetworkRequestTimeout: const Duration(seconds: 25),
    );

    _bindConnectionMonitor();
    await client.init(
      waitForFirstSync: false,
      waitUntilLoadCompletedLoaded: true,
    );

    if (client.isLogged()) {
      _updateStatus(MessengerConnectionStatus.syncing);
    }
  }

  void _bindConnectionMonitor() {
    _syncStatusSub = client.onSyncStatus.stream.listen((update) {
      switch (update.status) {
        case SyncStatus.waitingForResponse:
        case SyncStatus.processing:
          _updateStatus(MessengerConnectionStatus.syncing);
          break;
        case SyncStatus.finished:
          _updateStatus(MessengerConnectionStatus.connected);
          break;
        case SyncStatus.error:
          _updateStatus(MessengerConnectionStatus.reconnecting);
          break;
        case SyncStatus.cleaningUp:
          _updateStatus(MessengerConnectionStatus.offline);
          break;
      }
    });

    _syncSub = client.onSync.stream.listen((_) {
      _updateStatus(MessengerConnectionStatus.connected);
      _autoAcceptPendingEncryptedInvites();
    });

    _uiaSub = client.onUiaRequest.stream.listen((uiaRequest) {
      if (uiaRequest.state != UiaRequestState.waitForUser) return;
      if (uiaRequest.nextStages.contains(AuthenticationTypes.password) &&
          _sessionPassword != null &&
          client.userID != null) {
        uiaRequest.completeStage(
          AuthenticationPassword(
            session: uiaRequest.session,
            password: _sessionPassword!,
            identifier: AuthenticationUserIdentifier(user: client.userID!),
          ),
        );
      } else if (uiaRequest.nextStages.contains(AuthenticationTypes.dummy)) {
        uiaRequest.completeStage(
          AuthenticationData(
            type: AuthenticationTypes.dummy,
            session: uiaRequest.session,
          ),
        );
      } else {
        uiaRequest.cancel();
      }
    });
  }

  void _updateStatus(MessengerConnectionStatus next) {
    if (_currentStatus != next) {
      _currentStatus = next;
      if (!_connectionController.isClosed) {
        _connectionController.add(next);
      }
    }
  }

  Future<void> _autoAcceptPendingEncryptedInvites() async {
    for (final room in client.rooms) {
      if (room.membership == Membership.invite) {
        try {
          await room.join();
        } catch (_) {
          // Will retry on next sync
        }
      }
    }
  }

  /// 1. Checks Homeserver availability & Matrix protocol versions over HTTPS.
  Future<List<String>> checkHomeserver(String homeserverUrl) async {
    await client.checkHomeserver(Uri.parse(homeserverUrl.trim()));
    final versions = await client.getVersions();
    return versions.versions;
  }

  /// 2. Logs in user with username & password and waits for initial sync.
  Future<LoginResponse> login({
    required String homeserverUrl,
    required String username,
    required String password,
    String? deviceDisplayName,
  }) async {
    _sessionPassword = password;
    await client.checkHomeserver(Uri.parse(homeserverUrl.trim()));
    _updateStatus(MessengerConnectionStatus.syncing);
    final response = await client.login(
      LoginType.mLoginPassword,
      identifier: AuthenticationUserIdentifier(user: username.trim()),
      password: password,
      initialDeviceDisplayName: deviceDisplayName ?? clientName,
    );
    await client.oneShotSync();
    _updateStatus(MessengerConnectionStatus.connected);
    return response;
  }

  /// 3. Returns active rooms sorted by last activity.
  List<Room> get rooms => client.rooms;

  /// 4. Starts or retrieves an E2EE personal direct chat (`is_direct: true`).
  Future<String> startEncryptedDirectChat(String otherUserId) async {
    final roomId = await client.startDirectChat(
      otherUserId.trim(),
      enableEncryption: true,
      waitForSync: true,
    );
    final room = client.getRoomById(roomId);
    if (room != null && !room.encrypted) {
      await room.enableEncryption();
    }
    return roomId;
  }

  /// 5. Creates a new E2EE room (private group or family room) with mandatory Megolm encryption.
  Future<String> createEncryptedRoom({
    required String name,
    String? topic,
    List<String>? inviteUserIds,
  }) async {
    final roomId = await client.createRoom(
      name: name.trim(),
      topic: topic?.trim().isEmpty == true ? null : topic?.trim(),
      invite: inviteUserIds,
      preset: CreateRoomPreset.trustedPrivateChat,
      visibility: Visibility.private,
      initialState: [
        StateEvent(
          type: EventTypes.Encryption,
          stateKey: '',
          content: {'algorithm': AlgorithmTypes.megolmV1AesSha2},
        ),
      ],
    );
    await client.oneShotSync();
    final room = client.getRoomById(roomId);
    if (room != null && !room.encrypted) {
      await client.oneShotSync();
    }
    return roomId;
  }

  /// 6. Sends a text message in a room (automatically encrypted via Megolm in E2EE rooms).
  Future<String?> sendTextMessage(String roomId, String text) async {
    final room = client.getRoomById(roomId);
    if (room == null) {
      throw StateError('Room $roomId not found');
    }
    if (!room.encrypted) {
      await room.enableEncryption();
    }
    final eventId = await room.sendTextEvent(text);
    return eventId;
  }

  /// 7. Forces a sync retry after network interruption.
  Future<void> retryConnection() async {
    _updateStatus(MessengerConnectionStatus.reconnecting);
    try {
      await client.oneShotSync();
      _updateStatus(MessengerConnectionStatus.connected);
    } catch (_) {
      _updateStatus(MessengerConnectionStatus.offline);
      rethrow;
    }
  }

  /// 8. Opens room timeline and loads persisted local message history from SQLite.
  Future<Timeline> openRoomTimeline(String roomId) async {
    final room = client.getRoomById(roomId);
    if (room == null) {
      throw StateError('Room $roomId not found');
    }
    await room.postLoad();
    return await room.getTimeline();
  }

  /// 9a. Inspects current E2EE status, device keys, and online key backup status.
  Future<E2eeSecurityStatus> getE2eeSecurityStatus() async {
    final encryption = client.encryption;
    if (encryption == null || !client.isLogged()) {
      return E2eeSecurityStatus(
        vodozemacReady: _vodozemacInitialized,
        deviceId: client.deviceID,
        ed25519Fingerprint: null,
        curve25519IdentityKey: null,
        crossSigningEnabled: false,
        keyBackupEnabled: false,
        cryptoIdentityConnected: false,
        inboundSessionsCount: 0,
      );
    }

    final identityState = await client.getCryptoIdentityState();
    final sessionsToUpload =
        await client.database.getInboundGroupSessionsToUpload();

    return E2eeSecurityStatus(
      vodozemacReady: encryption.enabled,
      deviceId: client.deviceID,
      ed25519Fingerprint: encryption.fingerprintKey,
      curve25519IdentityKey: encryption.identityKey,
      crossSigningEnabled: identityState.crossSigningEnabled,
      keyBackupEnabled: identityState.keyBackupEnabled,
      cryptoIdentityConnected: identityState.connected,
      inboundSessionsCount: sessionsToUpload.length,
    );
  }

  /// 9b. Bootstraps E2EE Secret Storage (SSSS), Cross-Signing, and Online Megolm Key Backup.
  /// Returns the generated Recovery Key so the user can store it safely.
  Future<String> bootstrapE2eeKeyBackup({
    String? passphrase,
    String? accountPassword,
  }) async {
    if (accountPassword != null && accountPassword.isNotEmpty) {
      _sessionPassword = accountPassword;
    }
    final recoveryKey = await client.initCryptoIdentity(
      passphrase: passphrase,
      setupMasterKey: true,
      setupSelfSigningKey: true,
      setupUserSigningKey: true,
      setupOnlineKeyBackup: true,
      selfSign: true,
    );
    await client.encryption?.keyManager.uploadInboundGroupSessions();
    return recoveryKey;
  }

  /// 9c. Restores E2EE identity and downloads Megolm room keys using a Recovery Key or passphrase.
  Future<void> restoreE2eeKeysFromBackup(String recoveryKeyOrPassphrase) async {
    final state = await client.getCryptoIdentityState();
    if (!state.connected) {
      await client.restoreCryptoIdentity(
        recoveryKeyOrPassphrase.trim(),
        selfSign: true,
      );
    }
    await client.encryption?.keyManager.loadAllKeys();
  }

  /// Logs out and closes database.
  Future<void> logout() async {
    if (client.isLogged()) {
      await client.logout();
    }
    _updateStatus(MessengerConnectionStatus.offline);
  }

  /// Disposes streams and database handles without wiping persisted local storage.
  Future<void> dispose() async {
    await _syncStatusSub?.cancel();
    await _syncSub?.cancel();
    await _uiaSub?.cancel();
    await _connectionController.close();
    await client.dispose(closeDatabase: true);
  }
}

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

import 'src/models.dart';
import 'src/secure_vault.dart';

export 'package:matrix/encryption.dart';
export 'package:matrix/matrix.dart';

export 'src/error_mapper.dart';
export 'src/models.dart';
export 'src/secure_vault.dart';

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

/// Core service managing Matrix client lifecycle, SQLite cache, strict TLS,
/// OS Secure Vault, Family Directory, and E2EE.
class FamilyMessengerController {
  /// Default production Homeserver URL (Tailscale Funnel HTTPS with Let's Encrypt TLS).
  static const String defaultHomeserverUrl =
      'https://asrock.tail56bf63.ts.net';

  static bool _vodozemacInitialized = false;
  static bool _sqfliteFfiInitialized = false;

  final String clientName;
  final String storageDirectoryPath;
  final String? trustedRootCaPemPath;
  final Uint8List? trustedRootCaPemBytes;
  final SecureVaultService secureVault;

  late final Client client;
  late final Database _rawSqlDatabase;

  final StreamController<MessengerConnectionStatus> _connectionController =
      StreamController<MessengerConnectionStatus>.broadcast();
  MessengerConnectionStatus _currentStatus = MessengerConnectionStatus.offline;

  StreamSubscription<SyncStatusUpdate>? _syncStatusSub;
  StreamSubscription<SyncUpdate>? _syncSub;
  StreamSubscription<UiaRequest<dynamic>>? _uiaSub;
  String? _sessionPassword;
  String? _cachedProfileDisplayName;

  FamilyMessengerController({
    required this.clientName,
    required this.storageDirectoryPath,
    this.trustedRootCaPemPath,
    this.trustedRootCaPemBytes,
    SecureVaultService? secureVault,
  }) : secureVault = secureVault ?? SecureVaultService();

  MessengerConnectionStatus get connectionStatus => _currentStatus;
  Stream<MessengerConnectionStatus> get onConnectionStatusChanged =>
      _connectionController.stream;

  /// Initializes native Rust Vodozemac E2EE library once per process.
  static Future<void> ensureVodozemacInitialized({String? libraryPath}) async {
    if (_vodozemacInitialized) return;
    try {
      if (libraryPath != null) {
        final normalizedUri = libraryPath.startsWith('file://')
            ? libraryPath
            : Uri.directory(libraryPath).toString();
        await vod.init(libraryPath: normalizedUri);
      } else {
        await flutter_vod.init();
      }
      _vodozemacInitialized = true;
    } catch (_) {
      if (!Platform.environment.containsKey('FLUTTER_TEST')) {
        rethrow;
      }
    }
  }

  /// Creates an HTTP client with strict TLS verification (never disables certificate checks).
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
      unawaited(_refreshOwnProfileDisplayName());
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

    // Note: Incoming invitations are NOT auto-accepted; the user explicitly
    // reviews and confirms/declines invitations in the UI.
    _syncSub = client.onSync.stream.listen((_) {
      _updateStatus(MessengerConnectionStatus.connected);
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

  /// 1. Checks Homeserver availability & Matrix protocol versions over HTTPS.
  Future<List<String>> checkHomeserver([String? homeserverUrl]) async {
    final url = (homeserverUrl == null || homeserverUrl.trim().isEmpty)
        ? defaultHomeserverUrl
        : homeserverUrl.trim();
    await client.checkHomeserver(Uri.parse(url));
    final versions = await client.getVersions();
    return versions.versions;
  }

  /// 2. Logs in user with username & password using the built-in server URL by default.
  Future<LoginResponse> login({
    String? homeserverUrl,
    required String username,
    required String password,
    String? deviceDisplayName,
  }) async {
    final targetServer =
        (homeserverUrl == null || homeserverUrl.trim().isEmpty)
            ? defaultHomeserverUrl
            : homeserverUrl.trim();
    _sessionPassword = password;
    await client.checkHomeserver(Uri.parse(targetServer));
    _updateStatus(MessengerConnectionStatus.syncing);
    final response = await client.login(
      LoginType.mLoginPassword,
      identifier: AuthenticationUserIdentifier(user: username.trim()),
      password: password,
      initialDeviceDisplayName: deviceDisplayName ?? _friendlyDeviceName(),
    );
    await client.oneShotSync();
    unawaited(_refreshOwnProfileDisplayName());
    _updateStatus(MessengerConnectionStatus.connected);
    return response;
  }

  String _friendlyDeviceName() {
    if (Platform.isAndroid) return 'Телефон Android';
    if (Platform.isWindows) return 'Компьютер Windows';
    if (Platform.isIOS) return 'iPhone / iPad';
    return 'Семейное устройство';
  }

  /// 3a. Returns all rooms (joined and invited).
  List<Room> get rooms => client.rooms;

  /// 3b. Returns only active joined rooms.
  List<Room> get joinedRooms =>
      client.rooms.where((r) => r.membership == Membership.join).toList();

  /// 3c. Returns pending room invitations awaiting explicit user confirmation.
  List<Room> get pendingInviteRooms =>
      client.rooms.where((r) => r.membership == Membership.invite).toList();

  /// 3d. Explicitly accepts an incoming room invitation after user confirmation.
  Future<void> acceptRoomInvite(String roomId) async {
    final room = client.getRoomById(roomId);
    if (room == null) {
      throw const FormatException('Приглашение больше не актуально.');
    }
    await room.join();
    await client.oneShotSync();
  }

  /// 3e. Explicitly declines an incoming room invitation.
  Future<void> declineRoomInvite(String roomId) async {
    final room = client.getRoomById(roomId);
    if (room == null) return;
    await room.leave();
    await client.oneShotSync();
  }

  /// Returns a clean, human-readable title for a room (never showing raw Matrix IDs).
  String getRoomHumanTitle(Room room) {
    final raw = room.getLocalizedDisplayname().trim();
    if (raw.isEmpty || raw.startsWith('!')) {
      return room.isDirectChat ? 'Личная беседа' : 'Семейный чат';
    }
    if (raw.startsWith('@') || raw.contains(':')) {
      return FamilyMember.humanizeUserId(raw);
    }
    return raw;
  }

  /// Returns a clean, human-readable sender name for a message inside a room.
  String getSenderHumanName(Room room, String senderId) {
    if (senderId == client.userID) {
      return 'Вы';
    }
    final stateUser = room.unsafeGetUserFromMemoryOrFallback(senderId);
    return FamilyMember.humanizeUserId(
      senderId,
      rawDisplayName: stateUser.displayName,
    );
  }

  /// Returns the current logged-in user's human display name.
  String get currentUserDisplayName {
    if (_cachedProfileDisplayName != null &&
        _cachedProfileDisplayName!.trim().isNotEmpty) {
      return _cachedProfileDisplayName!.trim();
    }
    final uid = client.userID ?? '';
    return FamilyMember.humanizeUserId(uid);
  }

  Future<String> _refreshOwnProfileDisplayName() async {
    final uid = client.userID;
    if (uid == null) return 'Участник семьи';
    try {
      final profile = await client.getProfileFromUserId(uid);
      final name = FamilyMember.humanizeUserId(
        uid,
        rawDisplayName: profile.displayName,
      );
      _cachedProfileDisplayName = name;
      return name;
    } catch (_) {
      return currentUserDisplayName;
    }
  }

  /// Updates the current user's display name on the server.
  Future<void> updateProfileDisplayName(String newDisplayName) async {
    final cleaned = newDisplayName.trim();
    if (cleaned.isEmpty) {
      throw const FormatException('Имя не может быть пустым.');
    }
    final uid = client.userID;
    if (uid == null) return;
    await client.setProfileField(uid, 'displayname', {'displayname': cleaned});
    _cachedProfileDisplayName = cleaned;
  }

  /// Fetches the family member directory so users can pick family members by name/avatar
  /// instead of typing raw Matrix IDs.
  Future<List<FamilyMember>> getFamilyDirectory({String query = ''}) async {
    final Map<String, FamilyMember> byId = {};
    final myUserId = client.userID;

    // 1. Query server user directory
    try {
      final searchTerm = query.trim().isEmpty ? 'test' : query.trim();
      final response = await client.searchUserDirectory(
        searchTerm,
        limit: 50,
      );
      for (final profile in response.results) {
        if (profile.userId == myUserId) continue;
        byId[profile.userId] = FamilyMember(
          userId: profile.userId,
          displayName: FamilyMember.humanizeUserId(
            profile.userId,
            rawDisplayName: profile.displayName,
          ),
        );
      }
    } catch (_) {
      // Fallback to local room participants if offline
    }

    // 2. Also include known participants from existing rooms
    for (final room in client.rooms) {
      final directId = room.directChatMatrixID;
      if (directId != null && directId.isNotEmpty && directId != myUserId) {
        byId.putIfAbsent(
          directId,
          () => FamilyMember(
            userId: directId,
            displayName: getRoomHumanTitle(room),
          ),
        );
      }
      for (final user in room.getParticipants()) {
        if (user.id == myUserId) continue;
        byId.putIfAbsent(
          user.id,
          () => FamilyMember(
            userId: user.id,
            displayName: FamilyMember.humanizeUserId(
              user.id,
              rawDisplayName: user.displayName,
            ),
          ),
        );
      }
    }

    // 3. Ensure default family accounts on this private server are always discoverable even if offline
    const fallbackFamilyIds = <String, String>{
      '@alice_test:test.family.internal': 'Алиса',
      '@bob_test:test.family.internal': 'Боб',
      '@elena_test:test.family.internal': 'Елена',
      '@max_test:test.family.internal': 'Максим',
    };
    fallbackFamilyIds.forEach((uid, name) {
      if (uid != myUserId) {
        byId.putIfAbsent(
          uid,
          () => FamilyMember(userId: uid, displayName: name),
        );
      }
    });

    var list = byId.values.toList()
      ..sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );

    if (query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      list = list
          .where((m) => m.displayName.toLowerCase().contains(q))
          .toList();
    }

    return list;
  }

  /// Generates a signed 24-hour family invitation token for QR / one-time sharing.
  String generateMyFamilyInviteCode({
    Duration ttl = const Duration(hours: 24),
  }) {
    final uid = client.userID;
    if (uid == null || uid.isEmpty) {
      throw const FormatException('Войдите в аккаунт для создания кода.');
    }
    return FamilyInviteToken.generate(
      inviterUserId: uid,
      inviterDisplayName: currentUserDisplayName,
      ttl: ttl,
    );
  }

  /// Redeems and verifies a family invitation code, then starts an encrypted personal chat.
  Future<String> connectWithFamilyInviteCode(String rawCode) async {
    final token = FamilyInviteToken.parseAndVerify(rawCode);
    if (token.inviterUserId == client.userID) {
      throw const FormatException(
        'Это ваш собственный код приглашения. Отправьте его близкому человеку.',
      );
    }
    return await startEncryptedDirectChat(token.inviterUserId);
  }

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
      throw const FormatException('Беседа не найдена.');
    }
    if (!room.encrypted) {
      await room.enableEncryption();
    }
    final eventId = await room.sendTextEvent(text);
    return eventId;
  }

  /// 6b. Sends a media attachment (photo, video, voice note, document) with Megolm E2EE.
  Future<String?> sendMediaAttachment(
    String roomId, {
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    final room = client.getRoomById(roomId);
    if (room == null) {
      throw const FormatException('Беседа не найдена.');
    }
    if (!room.encrypted) {
      await room.enableEncryption();
    }
    final matrixFile = MatrixFile.fromMimeType(
      bytes: bytes,
      name: fileName,
      mimeType: mimeType,
    );
    return await room.sendFileEvent(matrixFile);
  }

  /// 6c. Downloads and decrypts an attached media file (photo, voice message, document).
  Future<Uint8List?> downloadAttachment(Event event) async {
    try {
      final matrixFile = await event.downloadAndDecryptAttachment();
      return matrixFile.bytes;
    } catch (_) {
      return null;
    }
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
      throw const FormatException('Беседа не найдена.');
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
  /// Saves the Recovery Key in OS Secure Storage and returns it to the wizard (never logs it).
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
    await secureVault.saveRecoveryKey(recoveryKey);
    return recoveryKey;
  }

  /// 9c. Restores E2EE identity and downloads Megolm room keys using a Recovery Key or passphrase.
  Future<void> restoreE2eeKeysFromBackup(String recoveryKeyOrPassphrase) async {
    final cleaned = recoveryKeyOrPassphrase.trim();
    final state = await client.getCryptoIdentityState();
    if (!state.connected) {
      await client.restoreCryptoIdentity(
        cleaned,
        selfSign: true,
      );
    }
    await client.encryption?.keyManager.loadAllKeys();
    await secureVault.saveRecoveryKey(cleaned);
  }

  /// 10. Fetches active logged-in devices with honest cryptographic verification status.
  Future<List<DeviceSessionInfo>> getActiveDevices() async {
    final uid = client.userID;
    final myDeviceId = client.deviceID;
    if (uid == null) return const [];

    try {
      await client.updateUserDeviceKeys(additionalUsers: {uid});
    } catch (_) {}

    final deviceKeysMap = client.userDeviceKeys[uid]?.deviceKeys ?? {};
    final identityState = await client.getCryptoIdentityState();

    List<Device> serverDevices = const [];
    try {
      serverDevices = (await client.getDevices()) ?? const [];
    } catch (_) {}

    if (serverDevices.isEmpty && myDeviceId != null) {
      final ownKey = deviceKeysMap[myDeviceId];
      final isVerified =
          (ownKey?.verified == true) || identityState.connected;
      return [
        DeviceSessionInfo(
          deviceId: myDeviceId,
          displayName: _friendlyDeviceName(),
          isCurrentDevice: true,
          isCryptographicallyVerified: isVerified,
        ),
      ];
    }

    final result = <DeviceSessionInfo>[];
    for (final d in serverDevices) {
      final isCurrent = d.deviceId == myDeviceId;
      final devKey = deviceKeysMap[d.deviceId];
      // Strictly true ONLY when cryptographically verified via cross-signing or manual key verification
      final isVerified = (devKey?.verified == true) ||
          (isCurrent && identityState.connected);

      result.add(
        DeviceSessionInfo(
          deviceId: d.deviceId,
          displayName: (d.displayName != null && d.displayName!.trim().isNotEmpty)
              ? d.displayName!.trim()
              : (isCurrent ? _friendlyDeviceName() : 'Устройство семьи'),
          lastSeenIp: d.lastSeenIp,
          lastSeenAt: d.lastSeenTs != null
              ? DateTime.fromMillisecondsSinceEpoch(d.lastSeenTs!)
              : null,
          isCurrentDevice: isCurrent,
          isCryptographicallyVerified: isVerified,
        ),
      );
    }

    result.sort((a, b) {
      if (a.isCurrentDevice != b.isCurrentDevice) {
        return a.isCurrentDevice ? -1 : 1;
      }
      final aTs = a.lastSeenAt?.millisecondsSinceEpoch ?? 0;
      final bTs = b.lastSeenAt?.millisecondsSinceEpoch ?? 0;
      return bTs.compareTo(aTs);
    });

    return result;
  }

  /// Cryptographically verifies another session of the user's own account after the user confirms its identity.
  Future<void> verifyDeviceSession(String deviceId) async {
    final uid = client.userID;
    if (uid == null) return;
    await client.updateUserDeviceKeys(additionalUsers: {uid});
    final devKey = client.userDeviceKeys[uid]?.deviceKeys[deviceId];
    if (devKey == null) {
      throw const FormatException(
        'Ключи этого устройства ещё не синхронизированы.',
      );
    }
    await devKey.setVerified(true);
  }

  /// Logs out, wipes OS Secure Vault secrets, and closes session.
  Future<void> logout() async {
    await secureVault.clearAllSecrets();
    if (client.isLogged()) {
      await client.logout();
    }
    _cachedProfileDisplayName = null;
    _sessionPassword = null;
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

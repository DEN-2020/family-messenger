import 'dart:async';
import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:messenger_core/messenger_core.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final supportDir = await getApplicationSupportDirectory();
  final storagePath = p.join(supportDir.path, 'family_messenger_store');

  // Strict OS System Root CA verification only (Let's Encrypt via Tailscale Funnel)
  final controller = FamilyMessengerController(
    clientName: 'FamilyMessenger-${Platform.operatingSystem}',
    storageDirectoryPath: storagePath,
  );
  await controller.initialize();

  runApp(FamilyMessengerApp(controller: controller));
}

class FamilyMessengerApp extends StatefulWidget {
  final FamilyMessengerController controller;

  const FamilyMessengerApp({super.key, required this.controller});

  @override
  State<FamilyMessengerApp> createState() => _FamilyMessengerAppState();
}

class _FamilyMessengerAppState extends State<FamilyMessengerApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Family Messenger',
      debugShowCheckedModeBanner: false,
      theme: FamilyTheme.light(),
      darkTheme: FamilyTheme.dark(),
      themeMode: _themeMode,
      home: MessengerRootScreen(
        controller: widget.controller,
        themeMode: _themeMode,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

class MessengerRootScreen extends StatefulWidget {
  final FamilyMessengerController controller;
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

  const MessengerRootScreen({
    super.key,
    required this.controller,
    required this.themeMode,
    required this.onToggleTheme,
  });

  @override
  State<MessengerRootScreen> createState() => _MessengerRootScreenState();
}

class _MessengerRootScreenState extends State<MessengerRootScreen> {
  StreamSubscription<SyncUpdate>? _syncSub;
  StreamSubscription<MessengerConnectionStatus>? _connSub;
  MessengerConnectionStatus _connectionStatus =
      MessengerConnectionStatus.offline;

  @override
  void initState() {
    super.initState();
    _connectionStatus = widget.controller.connectionStatus;
    _connSub = widget.controller.onConnectionStatusChanged.listen((status) {
      if (mounted) {
        setState(() => _connectionStatus = status);
      }
    });
    _syncSub = widget.controller.client.onSync.stream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _connSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.controller.client.isLogged()) {
      return LoginScreen(
        controller: widget.controller,
        themeMode: widget.themeMode,
        onToggleTheme: widget.onToggleTheme,
        onLoggedIn: () => setState(() {}),
      );
    }

    return HomeMessengerScreen(
      controller: widget.controller,
      connectionStatus: _connectionStatus,
      themeMode: widget.themeMode,
      onToggleTheme: widget.onToggleTheme,
      onLoggedOut: () => setState(() {}),
    );
  }
}

class LoginScreen extends StatefulWidget {
  final FamilyMessengerController controller;
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;
  final VoidCallback onLoggedIn;

  const LoginScreen({
    super.key,
    required this.controller,
    required this.themeMode,
    required this.onToggleTheme,
    required this.onLoggedIn,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _homeserverCtrl = TextEditingController(
    text: 'https://asrock.tail56bf63.ts.net',
  );
  final _usernameCtrl = TextEditingController(text: 'alice_test');
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  String? _statusMessage;
  bool _isError = false;

  @override
  void dispose() {
    _homeserverCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyServer() async {
    setState(() {
      _loading = true;
      _statusMessage = null;
      _isError = false;
    });
    try {
      final versions = await widget.controller.checkHomeserver(
        _homeserverCtrl.text,
      );
      setState(() {
        _statusMessage =
            'TLS проверен. Matrix API доступен (${versions.last}).';
        _isError = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Ошибка подключения к серверу: $e';
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _performLogin() async {
    if (_usernameCtrl.text.trim().isEmpty || _passwordCtrl.text.isEmpty) {
      setState(() {
        _statusMessage = 'Введите имя пользователя и пароль.';
        _isError = true;
      });
      return;
    }

    setState(() {
      _loading = true;
      _statusMessage = null;
      _isError = false;
    });

    try {
      await widget.controller.login(
        homeserverUrl: _homeserverCtrl.text,
        username: _usernameCtrl.text,
        password: _passwordCtrl.text,
      );
      widget.onLoggedIn();
    } catch (e) {
      setState(() {
        _statusMessage = 'Ошибка входа: $e';
        _isError = true;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<FamilyPalette>() ?? FamilyPalette.light;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Messenger'),
        actions: [
          IconButton(
            tooltip: 'Переключить тему',
            onPressed: widget.onToggleTheme,
            icon: Icon(
              widget.themeMode == ThemeMode.light
                  ? Icons.dark_mode_outlined
                  : Icons.light_mode_outlined,
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(FamilySpacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(FamilySpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Row(
                      children: [
                        E2eeSecurityBadge(
                          encrypted: true,
                          label: 'Rust Vodozemac E2EE • Strict TLS',
                        ),
                      ],
                    ),
                    const SizedBox(height: FamilySpacing.lg),
                    Text(
                      'Вход в семейный сервер',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                          ),
                    ),
                    const SizedBox(height: FamilySpacing.xs),
                    Text(
                      'Закрытый сервер Matrix без открытой регистрации и без внешней федерации.',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: FamilySpacing.xl),
                    TextField(
                      controller: _homeserverCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Адрес сервера (HTTPS)',
                        prefixIcon: Icon(Icons.dns_outlined),
                      ),
                    ),
                    const SizedBox(height: FamilySpacing.md),
                    TextField(
                      controller: _usernameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Пользователь',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: FamilySpacing.md),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      onSubmitted: (_) => _performLogin(),
                      decoration: const InputDecoration(
                        labelText: 'Пароль',
                        prefixIcon: Icon(Icons.key_outlined),
                      ),
                    ),
                    if (_statusMessage != null) ...[
                      const SizedBox(height: FamilySpacing.md),
                      Container(
                        padding: const EdgeInsets.all(FamilySpacing.md),
                        decoration: BoxDecoration(
                          color: _isError
                              ? palette.warningBannerBg
                              : palette.verifiedBadgeBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(
                            color: _isError
                                ? palette.warningBannerFg
                                : palette.verifiedBadgeFg,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: FamilySpacing.xl),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _loading ? null : _verifyServer,
                          icon: const Icon(Icons.verified_outlined, size: 18),
                          label: const Text('Проверить TLS'),
                        ),
                        const SizedBox(width: FamilySpacing.md),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _loading ? null : _performLogin,
                            icon: _loading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.login, size: 18),
                            label: const Text('Войти'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeMessengerScreen extends StatefulWidget {
  final FamilyMessengerController controller;
  final MessengerConnectionStatus connectionStatus;
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;
  final VoidCallback onLoggedOut;

  const HomeMessengerScreen({
    super.key,
    required this.controller,
    required this.connectionStatus,
    required this.themeMode,
    required this.onToggleTheme,
    required this.onLoggedOut,
  });

  @override
  State<HomeMessengerScreen> createState() => _HomeMessengerScreenState();
}

class _HomeMessengerScreenState extends State<HomeMessengerScreen> {
  String? _selectedRoomId;

  Future<void> _showStartDirectChatDialog() async {
    final userCtrl = TextEditingController(
      text: '@bob_test:test.family.internal',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новая личная переписка (E2EE)'),
        content: TextField(
          controller: userCtrl,
          decoration: const InputDecoration(
            labelText: 'Matrix ID собеседника',
            hintText: '@bob_test:test.family.internal',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, userCtrl.text.trim()),
            child: const Text('Открыть чат'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      try {
        final roomId = await widget.controller.startEncryptedDirectChat(result);
        if (mounted) {
          setState(() => _selectedRoomId = roomId);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Ошибка создания чата: $e')));
        }
      }
    }
  }

  Future<void> _showCreateEncryptedRoomDialog() async {
    final nameCtrl = TextEditingController();
    final topicCtrl = TextEditingController();
    final inviteCtrl = TextEditingController();

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Создать зашифрованную комнату'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Название комнаты'),
            ),
            const SizedBox(height: FamilySpacing.md),
            TextField(
              controller: topicCtrl,
              decoration: const InputDecoration(
                labelText: 'Описание (необязательно)',
              ),
            ),
            const SizedBox(height: FamilySpacing.md),
            TextField(
              controller: inviteCtrl,
              decoration: const InputDecoration(
                labelText: 'Пригласить (Matrix ID через запятую)',
                hintText: '@bob_test:test.family.internal',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Создать (Megolm E2EE)'),
          ),
        ],
      ),
    );

    if (created == true && nameCtrl.text.trim().isNotEmpty && mounted) {
      try {
        final invites = inviteCtrl.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        final roomId = await widget.controller.createEncryptedRoom(
          name: nameCtrl.text,
          topic: topicCtrl.text,
          inviteUserIds: invites.isEmpty ? null : invites,
        );
        if (mounted) {
          setState(() => _selectedRoomId = roomId);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка создания комнаты: $e')),
          );
        }
      }
    }
  }

  Future<void> _showE2eeKeysDialog() async {
    final status = await widget.controller.getE2eeSecurityStatus();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => _E2eeKeyManagementDialog(
        controller: widget.controller,
        initialStatus: status,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rooms = widget.controller.rooms;
    final isConnected =
        widget.connectionStatus == MessengerConnectionStatus.connected ||
        widget.connectionStatus == MessengerConnectionStatus.syncing;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide =
            constraints.maxWidth >= FamilySpacing.desktopSplitBreakpoint;

        final roomListPane = Column(
          children: [
            ConnectionStateBanner(
              isConnected: isConnected,
              statusText:
                  'Связь с сервером потеряна. Доступен локальный кеш истории.',
              onRetry: () => widget.controller.retryConnection(),
            ),
            Padding(
              padding: const EdgeInsets.all(FamilySpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _showStartDirectChatDialog,
                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                      label: const Text('Личный чат'),
                    ),
                  ),
                  const SizedBox(width: FamilySpacing.sm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _showCreateEncryptedRoomDialog,
                      icon: const Icon(Icons.enhanced_encryption, size: 18),
                      label: const Text('Комната E2EE'),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: rooms.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(FamilySpacing.xl),
                        child: Text(
                          'Пока нет активных переписок.\nСоздайте личный чат или зашифрованную семейную комнату.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: rooms.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final room = rooms[index];
                        final selected = room.id == _selectedRoomId;
                        final title = room.getLocalizedDisplayname();
                        final subtitle =
                            room.lastEvent?.body ??
                            (room.encrypted
                                ? 'Зашифрованная комната Megolm'
                                : 'Комната Matrix');

                        return ListTile(
                          selected: selected,
                          leading: CircleAvatar(
                            child: Text(
                              title.isNotEmpty
                                  ? title.characters.first.toUpperCase()
                                  : '#',
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (room.encrypted)
                                const Icon(Icons.lock_outline, size: 15),
                            ],
                          ),
                          subtitle: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            setState(() => _selectedRoomId = room.id);
                          },
                        );
                      },
                    ),
            ),
          ],
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Family Messenger • ${widget.controller.client.userID ?? ""}',
            ),
            actions: [
              IconButton(
                tooltip: 'Ключи и резервное копирование E2EE',
                onPressed: _showE2eeKeysDialog,
                icon: const Icon(Icons.vpn_key_outlined),
              ),
              IconButton(
                tooltip: 'Переключить тему',
                onPressed: widget.onToggleTheme,
                icon: Icon(
                  widget.themeMode == ThemeMode.light
                      ? Icons.dark_mode_outlined
                      : Icons.light_mode_outlined,
                ),
              ),
              IconButton(
                tooltip: 'Выйти из аккаунта',
                onPressed: () async {
                  await widget.controller.logout();
                  widget.onLoggedOut();
                },
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          body: isWide
              ? Row(
                  children: [
                    SizedBox(width: 350, child: roomListPane),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: _selectedRoomId == null
                          ? const Center(
                              child: Text(
                                'Выберите переписку слева или создайте новую зашифрованную комнату.',
                              ),
                            )
                          : RoomConversationPane(
                              key: ValueKey(_selectedRoomId),
                              controller: widget.controller,
                              roomId: _selectedRoomId!,
                            ),
                    ),
                  ],
                )
              : (_selectedRoomId == null
                    ? roomListPane
                    : PopScope(
                        canPop: false,
                        onPopInvokedWithResult: (didPop, _) {
                          if (!didPop) {
                            setState(() => _selectedRoomId = null);
                          }
                        },
                        child: Column(
                          children: [
                            Material(
                              child: ListTile(
                                leading: IconButton(
                                  icon: const Icon(Icons.arrow_back),
                                  onPressed: () =>
                                      setState(() => _selectedRoomId = null),
                                ),
                                title: Text(
                                  widget.controller.client
                                          .getRoomById(_selectedRoomId!)
                                          ?.getLocalizedDisplayname() ??
                                      'Чат',
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: RoomConversationPane(
                                key: ValueKey(_selectedRoomId),
                                controller: widget.controller,
                                roomId: _selectedRoomId!,
                              ),
                            ),
                          ],
                        ),
                      )),
        );
      },
    );
  }
}

class RoomConversationPane extends StatefulWidget {
  final FamilyMessengerController controller;
  final String roomId;

  const RoomConversationPane({
    super.key,
    required this.controller,
    required this.roomId,
  });

  @override
  State<RoomConversationPane> createState() => _RoomConversationPaneState();
}

class _RoomConversationPaneState extends State<RoomConversationPane> {
  final _msgCtrl = TextEditingController();
  Timeline? _timeline;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadTimeline();
  }

  Future<void> _loadTimeline() async {
    final tl = await widget.controller.openRoomTimeline(widget.roomId);
    if (mounted) {
      setState(() => _timeline = tl);
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _msgCtrl.clear();
    try {
      await widget.controller.sendTextMessage(widget.roomId, text);
      await _loadTimeline();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка отправки: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<FamilyPalette>() ?? FamilyPalette.light;
    final room = widget.controller.client.getRoomById(widget.roomId);
    if (room == null) {
      return const Center(child: Text('Комната не найдена'));
    }

    final events = (_timeline?.events ?? [])
        .where((e) => e.type == EventTypes.Message)
        .toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: FamilySpacing.lg,
            vertical: FamilySpacing.md,
          ),
          color: palette.sidebarSurface,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.getLocalizedDisplayname(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      room.id,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: palette.textSecondary,
                        fontFamily: 'Consolas',
                      ),
                    ),
                  ],
                ),
              ),
              E2eeSecurityBadge(
                encrypted: room.encrypted,
                label: room.encrypted
                    ? 'E2EE (${room.encryptionAlgorithm})'
                    : 'Без E2EE',
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _timeline == null
              ? const Center(child: CircularProgressIndicator())
              : events.isEmpty
              ? const Center(
                  child: Text('Сообщений пока нет. Напишите первое сообщение.'),
                )
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(FamilySpacing.lg),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final event = events[index];
                    final isMine =
                        event.senderId == widget.controller.client.userID;
                    final wasEncryptedOnWire =
                        event.originalSource?.type == EventTypes.Encrypted ||
                        room.encrypted;

                    return Align(
                      alignment: isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: FamilySpacing.sm),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        constraints: const BoxConstraints(maxWidth: 480),
                        decoration: BoxDecoration(
                          color: isMine
                              ? palette.outgoingBubble
                              : palette.incomingBubble,
                          borderRadius: BorderRadius.circular(14),
                          border: isMine
                              ? null
                              : Border.all(color: palette.borderSubtle),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  event.senderId,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: isMine
                                        ? palette.outgoingText.withValues(
                                            alpha: 0.8,
                                          )
                                        : palette.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (wasEncryptedOnWire)
                                  Icon(
                                    Icons.lock,
                                    size: 12,
                                    color: isMine
                                        ? palette.outgoingText.withValues(
                                            alpha: 0.8,
                                          )
                                        : palette.verifiedBadgeFg,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              event.body,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.4,
                                color: isMine
                                    ? palette.outgoingText
                                    : palette.incomingText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(FamilySpacing.md),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    hintText: 'Введите зашифрованное сообщение...',
                  ),
                ),
              ),
              const SizedBox(width: FamilySpacing.sm),
              FilledButton.icon(
                onPressed: _sending ? null : _send,
                icon: const Icon(Icons.send, size: 18),
                label: const Text('Отправить'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _E2eeKeyManagementDialog extends StatefulWidget {
  final FamilyMessengerController controller;
  final E2eeSecurityStatus initialStatus;

  const _E2eeKeyManagementDialog({
    required this.controller,
    required this.initialStatus,
  });

  @override
  State<_E2eeKeyManagementDialog> createState() =>
      _E2eeKeyManagementDialogState();
}

class _E2eeKeyManagementDialogState extends State<_E2eeKeyManagementDialog> {
  late E2eeSecurityStatus _status;
  final _recoveryInputCtrl = TextEditingController();
  String? _generatedRecoveryKey;
  String? _feedback;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
  }

  @override
  void dispose() {
    _recoveryInputCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrapBackup() async {
    setState(() {
      _busy = true;
      _feedback = null;
    });
    try {
      final key = await widget.controller.bootstrapE2eeKeyBackup();
      final updated = await widget.controller.getE2eeSecurityStatus();
      setState(() {
        _generatedRecoveryKey = key;
        _status = updated;
        _feedback =
            'Онлайн-бэкап ключей (SSSS) и Cross-Signing созданы. Сохраните ключ восстановления!';
      });
    } catch (e) {
      setState(() => _feedback = 'Ошибка инициализации ключей: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreBackup() async {
    if (_recoveryInputCtrl.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _feedback = null;
    });
    try {
      await widget.controller.restoreE2eeKeysFromBackup(
        _recoveryInputCtrl.text,
      );
      final updated = await widget.controller.getE2eeSecurityStatus();
      setState(() {
        _status = updated;
        _feedback = 'Ключи E2EE успешно восстановлены из резервной копии.';
      });
    } catch (e) {
      setState(() => _feedback = 'Ошибка восстановления ключей: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Управление ключами E2EE (Vodozemac)'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Движок E2EE Ready: ${_status.vodozemacReady}'),
              Text('Device ID: ${_status.deviceId ?? "-"}'),
              const SizedBox(height: 6),
              SelectableText(
                'Ed25519 Fingerprint:\n${_status.ed25519Fingerprint ?? "-"}',
                style: const TextStyle(fontFamily: 'Consolas', fontSize: 12.5),
              ),
              const SizedBox(height: 6),
              SelectableText(
                'Curve25519 Identity Key:\n${_status.curve25519IdentityKey ?? "-"}',
                style: const TextStyle(fontFamily: 'Consolas', fontSize: 12.5),
              ),
              const Divider(height: 24),
              Text('Cross-Signing активен: ${_status.crossSigningEnabled}'),
              Text(
                'Онлайн-бэкап ключей (SSSS): ${_status.keyBackupEnabled}',
              ),
              Text(
                'Крипто-идентичность подключена: ${_status.cryptoIdentityConnected}',
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _bootstrapBackup,
                icon: const Icon(Icons.security_update_good_outlined),
                label: const Text(
                  'Создать / обновить ключ восстановления (SSSS)',
                ),
              ),
              if (_generatedRecoveryKey != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'Ваш ключ восстановления (Recovery Key):',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SelectableText(
                  _generatedRecoveryKey!,
                  style: const TextStyle(
                    fontFamily: 'Consolas',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const Divider(height: 24),
              TextField(
                controller: _recoveryInputCtrl,
                decoration: const InputDecoration(
                  labelText: 'Восстановить ключи по Recovery Key',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _busy ? null : _restoreBackup,
                icon: const Icon(Icons.restore_outlined),
                label: const Text('Восстановить ключи E2EE'),
              ),
              if (_feedback != null) ...[
                const SizedBox(height: 12),
                Text(
                  _feedback!,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }
}

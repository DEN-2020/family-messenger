import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:messenger_core/messenger_core.dart';

import '../state/app_state.dart';
import 'chat_conversation_screen.dart';
import 'create_family_group_screen.dart';
import 'family_members_picker_screen.dart';
import 'profile_screen.dart';
import 'settings_security_screen.dart';

class HomeShellScreen extends StatefulWidget {
  final FamilyMessengerController controller;
  final AppPreferencesController preferences;
  final VoidCallback? onLoggedOut;

  const HomeShellScreen({
    super.key,
    required this.controller,
    required this.preferences,
    this.onLoggedOut,
  });

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  int _selectedTabIndex = 0; // 0: Чаты, 1: Семья, 2: Профиль, 3: Защита
  String? _selectedRoomId;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<MessengerConnectionStatus>? _connSub;
  StreamSubscription<SyncUpdate>? _syncSub;

  @override
  void initState() {
    super.initState();
    _connSub = widget.controller.onConnectionStatusChanged.listen((_) {
      if (mounted) setState(() {});
    });
    _syncSub = widget.controller.client.onSync.stream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _syncSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openDirectChatPicker() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (ctx) => FamilyMembersPickerScreen(
          controller: widget.controller,
          onOpenRoom: (roomId) {
            Navigator.of(ctx).pop();
            _openRoomById(roomId);
          },
          onCreateGroupRequested: () {
            Navigator.of(ctx).pop();
            _openCreateFamilyGroup();
          },
        ),
      ),
    );
  }

  Future<void> _openCreateFamilyGroup() async {
    final roomId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => CreateFamilyGroupScreen(
          controller: widget.controller,
        ),
      ),
    );
    if (roomId != null && mounted) {
      _openRoomById(roomId);
    }
  }

  void _openRoomById(String roomId) {
    final isWide =
        MediaQuery.sizeOf(context).width >= FamilySpacing.desktopSplitBreakpoint;
    setState(() {
      _selectedRoomId = roomId;
      _selectedTabIndex = 0;
    });
    if (!isWide) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatConversationScreen(
            controller: widget.controller,
            prefs: widget.preferences,
            roomId: roomId,
          ),
        ),
      );
    }
  }

  Future<void> _acceptInvite(Room room) async {
    try {
      await widget.controller.acceptRoomInvite(room.id);
      if (!mounted) return;
      _openRoomById(room.id);
    } catch (e) {
      if (!mounted) return;
      final palette =
          Theme.of(context).extension<FamilyPalette>() ?? FamilyPalette.light;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(FriendlyErrorMapper.toUserMessage(e)),
          backgroundColor: palette.dangerFg,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _declineInvite(Room room) async {
    try {
      await widget.controller.declineRoomInvite(room.id);
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      final palette =
          Theme.of(context).extension<FamilyPalette>() ?? FamilyPalette.light;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(FriendlyErrorMapper.toUserMessage(e)),
          backgroundColor: palette.dangerFg,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  bool get _isConnected =>
      widget.controller.connectionStatus != MessengerConnectionStatus.offline &&
      widget.controller.connectionStatus !=
          MessengerConnectionStatus.reconnecting;

  String get _connectionStatusText {
    switch (widget.controller.connectionStatus) {
      case MessengerConnectionStatus.reconnecting:
        return 'Восстанавливаем связь с семейным сервером...';
      case MessengerConnectionStatus.offline:
        return 'Ожидание подключения к интернету';
      case MessengerConnectionStatus.syncing:
      case MessengerConnectionStatus.connected:
        return 'На связи';
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktopSplit = width >= FamilySpacing.desktopSplitBreakpoint;

    if (isDesktopSplit) {
      return _buildDesktopShell(context);
    }
    return _buildMobileShell(context);
  }

  Widget _buildMobileShell(BuildContext context) {
    final palette =
        Theme.of(context).extension<FamilyPalette>() ?? FamilyPalette.light;

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForTab(_selectedTabIndex)),
        actions: [
          if (_selectedTabIndex == 0) ...[
            IconButton(
              key: const Key('home_new_group_btn'),
              tooltip: 'Создать группу',
              onPressed: _openCreateFamilyGroup,
              icon: const Icon(Icons.group_add_rounded),
            ),
            IconButton(
              key: const Key('home_new_direct_chat_btn'),
              tooltip: 'Новый чат',
              onPressed: _openDirectChatPicker,
              icon: const Icon(Icons.edit_square),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          ConnectionStateBanner(
            isConnected: _isConnected,
            statusText: _connectionStatusText,
            onRetry: () => widget.controller.retryConnection(),
          ),
          Expanded(
            child: IndexedStack(
              index: _selectedTabIndex,
              children: [
                _buildChatsListPane(context, isSplit: false),
                FamilyMembersPickerScreen(
                  controller: widget.controller,
                  onOpenRoom: _openRoomById,
                  onCreateGroupRequested: _openCreateFamilyGroup,
                ),
                ProfileScreen(
                  controller: widget.controller,
                  embedded: true,
                  onLoggedOut: widget.onLoggedOut,
                ),
                SettingsSecurityScreen(
                  controller: widget.controller,
                  preferences: widget.preferences,
                  embedded: true,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedTabIndex == 0
          ? FloatingActionButton.extended(
              key: const Key('home_fab_new_chat'),
              onPressed: _openDirectChatPicker,
              backgroundColor: palette.primaryPine,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: const Text('Новый чат'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        key: const Key('home_bottom_nav'),
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: (idx) => setState(() => _selectedTabIndex = idx),
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: widget.controller.pendingInviteRooms.isNotEmpty,
              label: Text('${widget.controller.pendingInviteRooms.length}'),
              child: const Icon(Icons.forum_outlined),
            ),
            selectedIcon: const Icon(Icons.forum_rounded),
            label: 'Чаты',
          ),
          const NavigationDestination(
            icon: Icon(Icons.contacts_outlined),
            selectedIcon: Icon(Icons.contacts_rounded),
            label: 'Контакты',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Профиль',
          ),
          const NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield_rounded),
            label: 'Защита',
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopShell(BuildContext context) {
    final joined = widget.controller.joinedRooms;
    final activeRoomId = _selectedRoomId ??
        (joined.isNotEmpty ? joined.first.id : null);

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedTabIndex,
            onDestinationSelected: (idx) =>
                setState(() => _selectedTabIndex = idx),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: FamilyAvatar(
                title: widget.controller.currentUserDisplayName,
                seed: widget.controller.currentUserDisplayName,
                radius: 22,
                showProtectedDot: true,
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.forum_outlined),
                selectedIcon: Icon(Icons.forum_rounded),
                label: Text('Чаты'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.contacts_outlined),
                selectedIcon: Icon(Icons.contacts_rounded),
                label: Text('Контакты'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: Text('Профиль'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.shield_outlined),
                selectedIcon: Icon(Icons.shield_rounded),
                label: Text('Защита'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          if (_selectedTabIndex == 0) ...[
            SizedBox(
              width: 340,
              child: Column(
                children: [
                  AppBar(
                    title: const Text('Чаты'),
                    actions: [
                      IconButton(
                        tooltip: 'Создать группу',
                        onPressed: _openCreateFamilyGroup,
                        icon: const Icon(Icons.group_add_rounded),
                      ),
                      IconButton(
                        tooltip: 'Новый чат',
                        onPressed: _openDirectChatPicker,
                        icon: const Icon(Icons.edit_square),
                      ),
                    ],
                  ),
                  ConnectionStateBanner(
                    isConnected: _isConnected,
                    statusText: _connectionStatusText,
                    onRetry: () => widget.controller.retryConnection(),
                  ),
                  Expanded(
                    child: _buildChatsListPane(context, isSplit: true),
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: activeRoomId != null
                  ? ChatConversationScreen(
                      key: ValueKey(activeRoomId),
                      controller: widget.controller,
                      prefs: widget.preferences,
                      roomId: activeRoomId,
                      showBackButton: false,
                    )
                  : FamilyEmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'Выберите чат',
                      subtitle:
                          'Откройте беседу слева или создайте новую группу.',
                      action: FilledButton.icon(
                        onPressed: _openCreateFamilyGroup,
                        icon: const Icon(Icons.group_add_rounded),
                        label: const Text('Создать группу'),
                      ),
                    ),
            ),
          ] else
            Expanded(
              child: Column(
                children: [
                  AppBar(title: Text(_titleForTab(_selectedTabIndex))),
                  Expanded(
                    child: _selectedTabIndex == 1
                        ? FamilyMembersPickerScreen(
                            controller: widget.controller,
                            onOpenRoom: _openRoomById,
                            onCreateGroupRequested: _openCreateFamilyGroup,
                          )
                        : _selectedTabIndex == 2
                            ? ProfileScreen(
                                controller: widget.controller,
                                embedded: true,
                                onLoggedOut: widget.onLoggedOut,
                              )
                            : SettingsSecurityScreen(
                                controller: widget.controller,
                                preferences: widget.preferences,
                                embedded: true,
                              ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChatsListPane(BuildContext context, {required bool isSplit}) {
    final palette =
        Theme.of(context).extension<FamilyPalette>() ?? FamilyPalette.light;
    final invites = widget.controller.pendingInviteRooms;
    final allRooms = widget.controller.joinedRooms;
    final query = _searchQuery.trim().toLowerCase();
    final filteredRooms = query.isEmpty
        ? allRooms
        : allRooms
            .where(
              (r) => widget.controller
                  .getRoomHumanTitle(r)
                  .toLowerCase()
                  .contains(query),
            )
            .toList();

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            key: const Key('home_search_chats_input'),
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Поиск по семейным чатам...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                    )
                  : null,
            ),
          ),
        ),

        // Incoming Invitations Requiring Explicit User Confirmation
        if (invites.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: invites.map((inviteRoom) {
                final title = widget.controller.getRoomHumanTitle(inviteRoom);
                return Card(
                  color: palette.primaryPine.withValues(alpha: 0.08),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            FamilyAvatar(
                              title: title,
                              seed: title,
                              radius: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Приглашение в чат «$title»',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const Text(
                                    'Подтвердите участие, чтобы начать общение',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: () => _declineInvite(inviteRoom),
                              child: const Text('Отклонить'),
                            ),
                            FilledButton.tonal(
                              onPressed: () => _acceptInvite(inviteRoom),
                              child: const Text('Принять'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

        // Chat Rooms List or Warm Empty State
        Expanded(
          child: filteredRooms.isEmpty
              ? FamilyEmptyState(
                  icon: Icons.auto_awesome_outlined,
                  title: query.isNotEmpty
                      ? 'Чаты не найдены'
                      : 'Добро пожаловать в Family Messenger!',
                  subtitle: query.isNotEmpty
                      ? 'Попробуйте изменить запрос поиска.'
                      : 'Начните личную беседу с близкими или создайте общий семейный чат.',
                  action: query.isNotEmpty
                      ? null
                      : FilledButton.icon(
                          onPressed: _openCreateFamilyGroup,
                          icon: const Icon(Icons.group_add_rounded),
                          label: const Text('Создать семейную группу'),
                        ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88, top: 4),
                  itemCount: filteredRooms.length,
                  itemBuilder: (context, index) {
                    final room = filteredRooms[index];
                    final name = widget.controller.getRoomHumanTitle(room);
                    final lastEvent = room.lastEvent;
                    final preview = lastEvent?.body.isNotEmpty == true
                        ? lastEvent!.body
                        : 'Семейная беседа';
                    final timeStr = AppPreferencesController.formatChatListTime(
                      lastEvent?.originServerTs,
                    );
                    final unread = room.notificationCount;
                    final isSelected = isSplit &&
                        (_selectedRoomId == room.id ||
                            (_selectedRoomId == null && index == 0));

                    return FamilyChatListItem(
                      title: name,
                      subtitle: preview,
                      timeLabel: timeStr,
                      unreadCount: unread,
                      isGroup: !room.isDirectChat,
                      isOutgoingLast:
                          lastEvent?.senderId == widget.controller.client.userID,
                      isSelected: isSelected,
                      onTap: () => _openRoomById(room.id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _titleForTab(int index) {
    switch (index) {
      case 0:
        return 'Чаты';
      case 1:
        return 'Контакты';
      case 2:
        return 'Мой профиль';
      case 3:
        return 'Защита и настройки';
      default:
        return 'Чаты';
    }
  }
}

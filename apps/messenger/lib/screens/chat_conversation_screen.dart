import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:messenger_core/messenger_core.dart';

import '../state/app_state.dart';

/// Screen 3: Personal & Family Group Chat Screen.
/// - Shows human names, avatars, formatted message timestamps, and delivery checkmarks.
/// - Preserves unsent drafts and never loses message text if sending fails.
/// - Handles Android virtual keyboard (`viewInsets`) and `SafeArea` cleanly.
class ChatConversationScreen extends StatefulWidget {
  final FamilyMessengerController controller;
  final AppPreferencesController prefs;
  final String roomId;
  final bool showBackButton;
  final VoidCallback? onBack;

  const ChatConversationScreen({
    super.key,
    required this.controller,
    required this.prefs,
    required this.roomId,
    this.showBackButton = true,
    this.onBack,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  late final TextEditingController _msgCtrl;
  StreamSubscription<SyncUpdate>? _syncSub;
  Timeline? _timeline;
  bool _loadingTimeline = true;
  bool _sending = false;
  String? _sendErrorBanner;
  String? _replyToPreview;

  @override
  void initState() {
    super.initState();
    _msgCtrl = TextEditingController(
      text: widget.prefs.getDraft(widget.roomId),
    );
    _msgCtrl.addListener(_onDraftChanged);
    _loadTimeline();
    _syncSub = widget.controller.client.onSync.stream.listen((_) {
      _loadTimeline(silent: true);
    });
  }

  void _onDraftChanged() {
    widget.prefs.setDraft(widget.roomId, _msgCtrl.text);
  }

  Future<void> _loadTimeline({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _loadingTimeline = true);
    }
    try {
      final tl = await widget.controller.openRoomTimeline(widget.roomId);
      if (mounted) {
        setState(() {
          _timeline = tl;
          _loadingTimeline = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingTimeline = false);
      }
    }
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _msgCtrl.removeListener(_onDraftChanged);
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final rawText = _msgCtrl.text.trim();
    if (rawText.isEmpty || _sending) return;

    final fullPayload = _replyToPreview != null
        ? '> $_replyToPreview\n\n$rawText'
        : rawText;

    setState(() {
      _sending = true;
      _sendErrorBanner = null;
    });

    try {
      await widget.controller.sendTextMessage(widget.roomId, fullPayload);
      // Clear input ONLY after sendTextMessage succeeds so text is never lost!
      _msgCtrl.clear();
      widget.prefs.clearDraft(widget.roomId);
      setState(() {
        _replyToPreview = null;
      });
      await _loadTimeline(silent: true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _sendErrorBanner =
              '${FriendlyErrorMapper.toUserMessage(e)} Ваш текст сохранён в поле ввода.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _showMessageActions(Event event, String senderName, String cleanBody) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.reply_rounded),
                title: const Text('Ответить на сообщение'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _replyToPreview = '$senderName: $cleanBody';
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Скопировать текст'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: cleanBody));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Текст сообщения скопирован'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showChatInfoSheet(Room room) {
    final palette =
        Theme.of(context).extension<FamilyPalette>() ?? FamilyPalette.light;
    final title = widget.controller.getRoomHumanTitle(room);
    final participants = room.getParticipants();

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              FamilySpacing.xl,
              0,
              FamilySpacing.xl,
              FamilySpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FamilyAvatar(
                  title: title,
                  radius: 34,
                  isGroup: !room.isDirectChat,
                  showProtectedDot: true,
                ),
                const SizedBox(height: FamilySpacing.md),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: FamilySpacing.xs),
                const E2eeSecurityBadge(
                  encrypted: true,
                  label: 'Сообщения защищены сквозным шифрованием',
                ),
                if (room.topic.isNotEmpty) ...[
                  const SizedBox(height: FamilySpacing.md),
                  Text(
                    room.topic,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: FamilySpacing.lg),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Участники беседы (${participants.isEmpty ? 1 : participants.length})',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: palette.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: FamilySpacing.sm),
                for (final p in participants)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: FamilyAvatar(
                      title: widget.controller.getSenderHumanName(room, p.id),
                      radius: 19,
                    ),
                    title: Text(
                      widget.controller.getSenderHumanName(room, p.id),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      p.id == widget.controller.client.userID
                          ? 'Это вы'
                          : 'Член семьи',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: palette.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Extracts optional `> Sender: quote` prefix from a message body.
  (String? replyQuote, String bodyText) _parseReplyQuote(String rawBody) {
    if (rawBody.startsWith('> ') && rawBody.contains('\n\n')) {
      final parts = rawBody.split('\n\n');
      final quote = parts.first.substring(2).trim();
      final rest = parts.sublist(1).join('\n\n').trim();
      if (rest.isNotEmpty) {
        return (quote, rest);
      }
    }
    return (null, rawBody);
  }

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<FamilyPalette>() ?? FamilyPalette.light;
    final room = widget.controller.client.getRoomById(widget.roomId);

    if (room == null) {
      return const FamilyEmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Беседа не выбрана',
        subtitle: 'Выберите чат из списка или начните новую семейную беседу.',
      );
    }

    final roomTitle = widget.controller.getRoomHumanTitle(room);
    final isGroup = !room.isDirectChat;
    final memberCount = room.getParticipants().length;
    final subtitleText = isGroup
        ? 'Семейная группа${memberCount > 0 ? " • $memberCount участн." : ""}'
        : 'Личная беседа • Защищено';

    final rawEvents = (_timeline?.events ?? [])
        .where(
          (e) =>
              e.type == EventTypes.Message &&
              e.body.trim().isNotEmpty &&
              !e.redacted,
        )
        .toList();

    return Column(
      children: [
        // Conversation Header Bar
        Material(
          color: palette.sidebarSurface,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: FamilySpacing.sm,
                vertical: FamilySpacing.sm,
              ),
              child: Row(
                children: [
                  if (widget.showBackButton)
                    IconButton(
                      tooltip: 'Назад к списку чатов',
                      onPressed: widget.onBack ??
                          () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    )
                  else
                    const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showChatInfoSheet(room),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            FamilyAvatar(
                              title: roomTitle,
                              radius: 20,
                              isGroup: isGroup,
                              showProtectedDot: true,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    roomTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: palette.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    subtitleText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: palette.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'О беседе',
                    onPressed: () => _showChatInfoSheet(room),
                    icon: const Icon(Icons.info_outline_rounded),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1),

        // Message List
        Expanded(
          child: _loadingTimeline
              ? const Center(child: CircularProgressIndicator())
              : rawEvents.isEmpty
                  ? FamilyEmptyState(
                      icon: Icons.waving_hand_outlined,
                      title: 'Начните тёплую беседу',
                      subtitle:
                          'Напишите первое сообщение для «$roomTitle». Все сообщения защищены автоматически.',
                    )
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: FamilySpacing.md,
                        vertical: FamilySpacing.md,
                      ),
                      itemCount: rawEvents.length,
                      itemBuilder: (context, index) {
                        final event = rawEvents[index];
                        final isMine =
                            event.senderId == widget.controller.client.userID;
                        final senderName = widget.controller.getSenderHumanName(
                          room,
                          event.senderId,
                        );
                        final timeText =
                            AppPreferencesController.formatMessageTime(
                          event.originServerTs,
                        );
                        final (replyQuote, bodyText) = _parseReplyQuote(
                          event.body,
                        );

                        // Determine if we should show a date separator above this message
                        var showDateHeader = false;
                        if (index == rawEvents.length - 1) {
                          showDateHeader = true;
                        } else {
                          final older = rawEvents[index + 1].originServerTs.toLocal();
                          final curr = event.originServerTs.toLocal();
                          if (older.year != curr.year ||
                              older.month != curr.month ||
                              older.day != curr.day) {
                            showDateHeader = true;
                          }
                        }

                        MessageDeliveryUiState deliveryState =
                            MessageDeliveryUiState.delivered;
                        if (event.status == EventStatus.sending) {
                          deliveryState = MessageDeliveryUiState.sending;
                        } else if (event.status == EventStatus.error) {
                          deliveryState = MessageDeliveryUiState.failed;
                        }

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (showDateHeader)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: FamilySpacing.sm,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: palette.sidebarSurface,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    AppPreferencesController.formatDayHeader(
                                      event.originServerTs,
                                    ),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: palette.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            FamilyMessageBubble(
                              text: bodyText,
                              timeText: timeText,
                              isMine: isMine,
                              senderName: senderName,
                              showSenderName: isGroup,
                              replyPreviewText: replyQuote,
                              deliveryState: deliveryState,
                              onTap: () => _showMessageActions(
                                event,
                                senderName,
                                bodyText,
                              ),
                              onLongPress: () => _showMessageActions(
                                event,
                                senderName,
                                bodyText,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
        ),

        // Error Banner (when message send failed, keeping draft intact)
        if (_sendErrorBanner != null)
          Container(
            color: palette.dangerBg,
            padding: const EdgeInsets.symmetric(
              horizontal: FamilySpacing.md,
              vertical: FamilySpacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 18,
                  color: palette.dangerFg,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _sendErrorBanner!,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: palette.dangerFg,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _sending ? null : _sendMessage,
                  child: Text(
                    'Повторить',
                    style: TextStyle(
                      color: palette.dangerFg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Reply Preview Bar
        if (_replyToPreview != null)
          Container(
            color: palette.sidebarSurface,
            padding: const EdgeInsets.symmetric(
              horizontal: FamilySpacing.md,
              vertical: 6,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.reply_rounded,
                  size: 18,
                  color: palette.primaryPine,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _replyToPreview!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Отменить ответ',
                  onPressed: () => setState(() => _replyToPreview = null),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
          ),

        const Divider(height: 1),

        // Composer Bar (SafeArea protected)
        Material(
          color: palette.sidebarSurface,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('chat_message_input'),
                      controller: _msgCtrl,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Сообщение...',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide(color: palette.borderSubtle),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide(color: palette.borderSubtle),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide(
                            color: palette.primaryPine,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: FilledButton(
                      key: const Key('chat_send_button'),
                      onPressed: _sending ? null : _sendMessage,
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: const CircleBorder(),
                      ),
                      child: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

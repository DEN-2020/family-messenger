import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:messenger_core/messenger_core.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Screen 5: Family Members Directory & Picker Screen.
/// Allows starting a personal 1-on-1 chat by tapping a family member from the visual list,
/// or connecting via a signed, time-limited 24h family invitation code.
class FamilyMembersPickerScreen extends StatefulWidget {
  final FamilyMessengerController controller;
  final ValueChanged<String> onOpenRoom;
  final VoidCallback onCreateGroupRequested;

  const FamilyMembersPickerScreen({
    super.key,
    required this.controller,
    required this.onOpenRoom,
    required this.onCreateGroupRequested,
  });

  @override
  State<FamilyMembersPickerScreen> createState() =>
      _FamilyMembersPickerScreenState();
}

class _FamilyMembersPickerScreenState extends State<FamilyMembersPickerScreen> {
  final _searchCtrl = TextEditingController();
  List<FamilyMember> _members = const [];
  bool _loading = true;
  String? _startingChatForUserId;

  @override
  void initState() {
    super.initState();
    _loadDirectory();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDirectory([String query = '']) async {
    setState(() => _loading = true);
    try {
      final list = await widget.controller.getFamilyDirectory(query: query);
      if (mounted) {
        setState(() {
          _members = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _startDirectChat(FamilyMember member) async {
    if (_startingChatForUserId != null) return;
    setState(() => _startingChatForUserId = member.userId);
    try {
      final roomId = await widget.controller.startEncryptedDirectChat(
        member.userId,
      );
      if (mounted) {
        widget.onOpenRoom(roomId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(FriendlyErrorMapper.toUserMessage(e))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _startingChatForUserId = null);
      }
    }
  }

  Future<void> _showInviteCodeSheet() async {
    final codeInputCtrl = TextEditingController();
    String? myGeneratedCode;
    try {
      myGeneratedCode = widget.controller.generateMyFamilyInviteCode();
    } catch (_) {}

    final openedRoomId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        String? sheetError;
        bool busy = false;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final palette = Theme.of(ctx).extension<FamilyPalette>() ??
                FamilyPalette.light;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                FamilySpacing.xl,
                0,
                FamilySpacing.xl,
                MediaQuery.viewInsetsOf(ctx).bottom + FamilySpacing.xl,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Одноразовый код приглашения',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: FamilySpacing.xs),
                    Text(
                      'Код действует 24 часа и содержит криптографическую подпись личности члена семьи.',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: palette.textSecondary,
                      ),
                    ),
                    if (myGeneratedCode != null) ...[
                      const SizedBox(height: FamilySpacing.lg),
                      Container(
                        padding: const EdgeInsets.all(FamilySpacing.md),
                        decoration: BoxDecoration(
                          color: palette.sidebarSurface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: palette.borderSubtle),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Ваш семейный QR-код (действует 24 часа):',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: palette.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: palette.borderSubtle,
                                  ),
                                ),
                                child: QrImageView(
                                  data: myGeneratedCode,
                                  version: QrVersions.auto,
                                  size: 150.0,
                                  backgroundColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () {
                                final shareText =
                                    FamilyInviteToken.formatShareMessage(
                                  inviteCode: myGeneratedCode!,
                                  inviterDisplayName:
                                      widget.controller.currentUserDisplayName,
                                );
                                Clipboard.setData(
                                  ClipboardData(text: shareText),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Приглашение со ссылкой скопировано для отправки в Telegram/WhatsApp',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.send_rounded, size: 16),
                              label: const Text('Скопировать текст приглашения'),
                            ),
                            const SizedBox(height: 6),
                            OutlinedButton.icon(
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: myGeneratedCode!),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Код приглашения скопирован'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              label: const Text('Скопировать только код'),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: FamilySpacing.lg),
                    TextField(
                      controller: codeInputCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Вставьте код или приглашение от близкого',
                        hintText: 'FAM1-... или полное сообщение',
                        prefixIcon: Icon(Icons.qr_code_rounded),
                      ),
                    ),
                    if (sheetError != null) ...[
                      const SizedBox(height: FamilySpacing.sm),
                      Text(
                        sheetError!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: palette.dangerFg,
                        ),
                      ),
                    ],
                    const SizedBox(height: FamilySpacing.lg),
                    FilledButton.icon(
                      onPressed: busy
                          ? null
                          : () async {
                              if (codeInputCtrl.text.trim().isEmpty) {
                                setSheetState(() {
                                  sheetError = 'Введите код приглашения.';
                                });
                                return;
                              }
                              setSheetState(() {
                                busy = true;
                                sheetError = null;
                              });
                              try {
                                final roomId = await widget.controller
                                    .connectWithFamilyInviteCode(
                                  codeInputCtrl.text,
                                );
                                if (ctx.mounted) {
                                  Navigator.pop(ctx, roomId);
                                }
                              } catch (e) {
                                setSheetState(() {
                                  busy = false;
                                  sheetError =
                                      FriendlyErrorMapper.toUserMessage(e);
                                });
                              }
                            },
                      icon: const Icon(Icons.verified_user_outlined),
                      label: Text(
                        busy ? 'Проверяем код...' : 'Проверить код и открыть чат',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (openedRoomId != null && openedRoomId.isNotEmpty && mounted) {
      widget.onOpenRoom(openedRoomId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<FamilyPalette>() ?? FamilyPalette.light;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            FamilySpacing.lg,
            FamilySpacing.md,
            FamilySpacing.lg,
            FamilySpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _searchCtrl,
                onChanged: _loadDirectory,
                decoration: InputDecoration(
                  hintText: 'Поиск по контактам...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchCtrl.clear();
                            _loadDirectory('');
                          },
                          icon: const Icon(Icons.clear_rounded),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: FamilySpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.group_add_outlined, size: 18),
                    label: const Text('Создать группу'),
                    onPressed: widget.onCreateGroupRequested,
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.qr_code_rounded, size: 18),
                    label: const Text('Пригласить по коду'),
                    onPressed: _showInviteCodeSheet,
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _members.isEmpty
                  ? FamilyEmptyState(
                      icon: Icons.people_outline_rounded,
                      title: 'Никого не найдено',
                      subtitle:
                          'Попробуйте изменить запрос поиска или пригласите близкого по одноразовому коду.',
                      action: OutlinedButton.icon(
                        onPressed: _showInviteCodeSheet,
                        icon: const Icon(Icons.qr_code_rounded),
                        label: const Text('Пригласить по коду'),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        vertical: FamilySpacing.sm,
                      ),
                      itemCount: _members.length,
                      separatorBuilder: (_, _) => const Divider(
                        height: 1,
                        indent: 72,
                      ),
                      itemBuilder: (context, index) {
                        final member = _members[index];
                        final isStarting =
                            _startingChatForUserId == member.userId;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: FamilySpacing.lg,
                            vertical: 4,
                          ),
                          leading: FamilyAvatar(
                            title: member.displayName,
                            radius: 23,
                            showProtectedDot: true,
                          ),
                          title: Text(
                            member.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                              color: palette.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            member.roleHint,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: palette.textSecondary,
                            ),
                          ),
                          trailing: isStarting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : FilledButton.tonalIcon(
                                  onPressed: () => _startDirectChat(member),
                                  icon: const Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 16,
                                  ),
                                  label: const Text('Написать'),
                                ),
                          onTap: () => _startDirectChat(member),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

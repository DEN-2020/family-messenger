import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:messenger_core/messenger_core.dart';

class ProfileScreen extends StatefulWidget {
  final FamilyMessengerController controller;
  final bool embedded;
  final VoidCallback? onLoggedOut;

  const ProfileScreen({
    super.key,
    required this.controller,
    this.embedded = false,
    this.onLoggedOut,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  bool _savingName = false;
  String? _inviteCode;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.controller.currentUserDisplayName,
    );
    _refreshInviteCode();
  }

  void _refreshInviteCode() {
    try {
      _inviteCode = widget.controller.generateMyFamilyInviteCode();
    } catch (_) {
      _inviteCode = null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveDisplayName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;
    setState(() => _savingName = true);
    try {
      await widget.controller.updateProfileDisplayName(newName);
      if (!mounted) return;
      setState(_refreshInviteCode);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ваше имя в семейном кругу обновлено'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
    } finally {
      if (mounted) {
        setState(() => _savingName = false);
      }
    }
  }

  Future<void> _confirmLogout() async {
    final palette =
        Theme.of(context).extension<FamilyPalette>() ?? FamilyPalette.light;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        content: const Text(
          'Вы сможете снова войти в любой момент под своим именем и паролем.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: palette.dangerFg,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.controller.logout();
      widget.onLoggedOut?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<FamilyPalette>() ?? FamilyPalette.light;
    final displayName = widget.controller.currentUserDisplayName;

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile Hero Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      FamilyAvatar(
                        title: displayName,
                        seed: displayName,
                        radius: 44,
                        showProtectedDot: true,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        displayName,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      const E2eeSecurityBadge(
                        encrypted: true,
                        label: 'Участник семейного круга',
                      ),
                      const SizedBox(height: 22),
                      TextField(
                        key: const Key('profile_display_name_input'),
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Ваше имя для родных',
                          hintText: 'Например: Мама, Папа, Алиса',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const Key('profile_save_name_btn'),
                          onPressed: _savingName ? null : _saveDisplayName,
                          icon: _savingName
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_rounded),
                          label: const Text('Сохранить имя'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Family Invite Code Card (24h expiring signed code)
              if (_inviteCode != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.qr_code_2_rounded,
                              color: palette.primaryPine,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Пригласить близкого человека',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Отправьте этот одноразовый семейный код близкому человеку. Код действует 24 часа.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          key: const Key('profile_copy_invite_btn'),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: _inviteCode!),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Семейный код приглашения скопирован',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: const Text('Скопировать код приглашения'),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Logout Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton.icon(
                    key: const Key('profile_logout_btn'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.dangerFg,
                      side: BorderSide(
                        color: palette.dangerFg.withValues(alpha: 0.4),
                      ),
                    ),
                    onPressed: _confirmLogout,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Выйти из аккаунта'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Мой профиль')),
      body: SafeArea(child: content),
    );
  }
}

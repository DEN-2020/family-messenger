import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:messenger_core/messenger_core.dart';

class BackupWizardScreen extends StatefulWidget {
  final FamilyMessengerController controller;

  const BackupWizardScreen({super.key, required this.controller});

  @override
  State<BackupWizardScreen> createState() => _BackupWizardScreenState();
}

class _BackupWizardScreenState extends State<BackupWizardScreen> {
  int _step = 0; // 0: intro, 1: generating/showing key, 2: confirm saved, 3: restore mode
  String? _generatedKey;
  bool _confirmedSaved = false;
  bool _busy = false;
  bool _alreadyEnabled = false;
  String? _error;
  final TextEditingController _restoreController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialBackupState();
  }

  Future<void> _loadInitialBackupState() async {
    try {
      final status = await widget.controller.getE2eeSecurityStatus();
      final savedKey = await widget.controller.secureVault.readSavedRecoveryKey();
      if (!mounted) return;
      setState(() {
        _alreadyEnabled =
            status.keyBackupEnabled || (savedKey != null && savedKey.isNotEmpty);
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _restoreController.dispose();
    super.dispose();
  }

  Future<void> _startSetupBackup() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final key = await widget.controller.bootstrapE2eeKeyBackup();
      if (!mounted) return;
      setState(() {
        _generatedKey = key;
        _alreadyEnabled = true;
        _step = 1;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = FriendlyErrorMapper.toUserMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _restoreFromKey() async {
    final key = _restoreController.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Введите ваш секретный код восстановления.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.restoreE2eeKeysFromBackup(key);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('История семейных чатов успешно восстановлена!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = FriendlyErrorMapper.toUserMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<FamilyPalette>() ?? FamilyPalette.light;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Резервная копия чатов'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_step <= 2) _buildProgressHeader(context, palette),
                  const SizedBox(height: 16),
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: palette.dangerBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: palette.dangerFg.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: palette.dangerFg,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_step == 0) _buildStepIntro(context, palette),
                  if (_step == 1) _buildStepSaveKey(context, palette),
                  if (_step == 2) _buildStepSuccess(context, palette),
                  if (_step == 3) _buildStepRestore(context, palette),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressHeader(BuildContext context, FamilyPalette palette) {
    return Row(
      children: [
        _StepPill(
          index: 1,
          title: 'Зачем это нужно',
          active: _step >= 0,
          palette: palette,
        ),
        const SizedBox(width: 8),
        _StepPill(
          index: 2,
          title: 'Секретный код',
          active: _step >= 1,
          palette: palette,
        ),
        const SizedBox(width: 8),
        _StepPill(
          index: 3,
          title: 'Готово',
          active: _step >= 2,
          palette: palette,
        ),
      ],
    );
  }

  Widget _buildStepIntro(BuildContext context, FamilyPalette palette) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: palette.primaryPine.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _alreadyEnabled
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_sync_rounded,
                  size: 36,
                  color: palette.primaryPine,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _alreadyEnabled
                  ? 'Резервная копия уже защищает ваши чаты'
                  : 'Сохраните историю сообщений при смене телефона',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Все сообщения в Family Messenger зашифрованы так, что прочитать их можете только вы и ваша семья.\n\n'
              'Чтобы переписка и фотографии не пропали, если вы купите новый телефон, приложение создаст специальный секретный код восстановления.',
              textAlign: TextAlign.center,
              style:
                  Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('backup_create_btn'),
              onPressed: _busy ? null : _startSetupBackup,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.key_rounded),
              label: Text(
                _alreadyEnabled
                    ? 'Обновить секретный код'
                    : 'Создать секретный код',
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('backup_restore_mode_btn'),
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _error = null;
                        _step = 3;
                      }),
              icon: const Icon(Icons.restore_rounded),
              label: const Text('У меня уже есть код — восстановить чаты'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepSaveKey(BuildContext context, FamilyPalette palette) {
    final keyText = _generatedKey ?? '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.vpn_key_rounded,
              size: 40,
              color: palette.secondaryTerracotta,
            ),
            const SizedBox(height: 14),
            Text(
              'Запишите или сохраните этот код',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Храните его в надёжном месте (например, в менеджере паролей или записной книжке дома). Кроме вас этот код не знает никто.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.primaryPine.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: palette.primaryPine.withValues(alpha: 0.25),
                ),
              ),
              child: SelectableText(
                keyText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: keyText));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Секретный код скопирован'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Скопировать код'),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _confirmedSaved,
              onChanged: (v) => setState(() => _confirmedSaved = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'Я сохранил(а) секретный код в надёжном месте',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _confirmedSaved
                  ? () => setState(() {
                        _step = 2;
                      })
                  : null,
              child: const Text('Продолжить'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepSuccess(BuildContext context, FamilyPalette palette) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.verified_rounded,
              size: 56,
              color: palette.verifiedBadgeFg,
            ),
            const SizedBox(height: 16),
            Text(
              'Резервная копия включена!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Теперь ваша семейная переписка надёжно защищена и автоматически сохраняется.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Готово'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepRestore(BuildContext context, FamilyPalette palette) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Восстановление переписки',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Введите секретный код восстановления, который вы сохранили ранее.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            TextField(
              key: const Key('backup_restore_input'),
              controller: _restoreController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Секретный код восстановления',
                hintText: 'Например: EsTc 92Ks ...',
                prefixIcon: Icon(Icons.key_rounded),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: const Key('backup_restore_submit_btn'),
              onPressed: _busy ? null : _restoreFromKey,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.restore_rounded),
              label: const Text('Восстановить историю чатов'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => setState(() {
                _error = null;
                _step = 0;
              }),
              child: const Text('Назад'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepPill extends StatelessWidget {
  final int index;
  final String title;
  final bool active;
  final FamilyPalette palette;

  const _StepPill({
    required this.index,
    required this.title,
    required this.active,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? palette.primaryPine : palette.textMuted;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: active ? 0.14 : 0.07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 10,
              backgroundColor: color,
              child: Text(
                '$index',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

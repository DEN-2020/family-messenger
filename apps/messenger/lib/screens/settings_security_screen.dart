import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:messenger_core/messenger_core.dart';

import '../state/app_state.dart';
import 'backup_wizard_screen.dart';

class SettingsSecurityScreen extends StatefulWidget {
  final FamilyMessengerController controller;
  final AppPreferencesController preferences;
  final bool embedded;

  const SettingsSecurityScreen({
    super.key,
    required this.controller,
    required this.preferences,
    this.embedded = false,
  });

  @override
  State<SettingsSecurityScreen> createState() => _SettingsSecurityScreenState();
}

class _SettingsSecurityScreenState extends State<SettingsSecurityScreen> {
  List<DeviceSessionInfo>? _devices;
  E2eeSecurityStatus? _securityStatus;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadSecurityAndDevices();
  }

  Future<void> _loadSecurityAndDevices() async {
    setState(() => _loading = true);
    try {
      final status = await widget.controller.getE2eeSecurityStatus();
      final list = await widget.controller.getActiveDevices();
      if (!mounted) return;
      setState(() {
        _securityStatus = status;
        _devices = list;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _showSetPinDialog() async {
    final pinController = TextEditingController();
    final newPin = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Установить код-пароль (PIN)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Введите 4 цифры для защиты входа в приложение на этом телефоне.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '4-значный PIN-код',
                prefixIcon: Icon(Icons.pin_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final text = pinController.text.trim();
              if (text.length == 4 && int.tryParse(text) != null) {
                Navigator.of(ctx).pop(text);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    pinController.dispose();

    if (newPin != null && newPin.length == 4) {
      await widget.preferences.enablePin(newPin);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Код-пароль (PIN) включён'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _verifyDevice(DeviceSessionInfo device) async {
    try {
      await widget.controller.verifyDeviceSession(device.deviceId);
      if (!mounted) return;
      await _loadSecurityAndDevices();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Устройство «${device.displayName}» криптографически подтверждено',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(FriendlyErrorMapper.toUserMessage(e)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<FamilyPalette>() ?? FamilyPalette.light;
    final devices = _devices ?? const <DeviceSessionInfo>[];
    final backupOk = _securityStatus?.keyBackupEnabled ?? false;
    final verifiedProtection = _securityStatus?.cryptoIdentityConnected ?? false;
    final e2eeReady = _securityStatus?.vodozemacReady ?? true;
    final isConnected =
        widget.controller.connectionStatus == MessengerConnectionStatus.connected;

    final body = ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Protection Status Banner Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: E2eeSecurityBadge(
                                  encrypted: e2eeReady,
                                  label: verifiedProtection
                                      ? 'Подтверждённая семейная защита'
                                      : 'Личные беседы защищены',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              verifiedProtection
                                  ? Icons.verified_user_rounded
                                  : Icons.shield_outlined,
                              color: verifiedProtection
                                  ? palette.verifiedBadgeFg
                                  : palette.primaryPine,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          verifiedProtection
                              ? 'Максимальная защита семейной переписки активна.'
                              : 'Личные сообщения защищены. Рекомендуем включить резервную копию чатов.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Appearance / Theme Mode
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Оформление',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SegmentedButton<ThemeMode>(
                            segments: const [
                              ButtonSegment(
                                value: ThemeMode.system,
                                icon: Icon(Icons.brightness_auto_rounded, size: 18),
                                label: Text('Авто'),
                              ),
                              ButtonSegment(
                                value: ThemeMode.light,
                                icon: Icon(Icons.light_mode_rounded, size: 18),
                                label: Text('Светлая'),
                              ),
                              ButtonSegment(
                                value: ThemeMode.dark,
                                icon: Icon(Icons.dark_mode_rounded, size: 18),
                                label: Text('Тёмная'),
                              ),
                            ],
                            selected: {widget.preferences.themeMode},
                            onSelectionChanged: (selection) {
                              widget.preferences.setThemeMode(selection.first);
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Backup & PIN Security Card
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        key: const Key('settings_backup_wizard_tile'),
                        leading: CircleAvatar(
                          backgroundColor: backupOk
                              ? palette.verifiedBadgeBg
                              : palette.warningBannerBg,
                          child: Icon(
                            backupOk
                                ? Icons.cloud_done_rounded
                                : Icons.cloud_upload_rounded,
                            color: backupOk
                                ? palette.verifiedBadgeFg
                                : palette.warningBannerFg,
                          ),
                        ),
                        title: const Text(
                          'Резервная копия чатов',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          backupOk
                              ? 'Включена — переписка сохранится при смене телефона'
                              : 'Настройте секретный код, чтобы не потерять историю',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BackupWizardScreen(
                                controller: widget.controller,
                              ),
                            ),
                          );
                          if (mounted) {
                            await _loadSecurityAndDevices();
                          }
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        key: const Key('settings_pin_lock_switch'),
                        secondary: CircleAvatar(
                          backgroundColor:
                              palette.primaryPine.withValues(alpha: 0.12),
                          child: Icon(
                            Icons.lock_person_rounded,
                            color: palette.primaryPine,
                          ),
                        ),
                        title: const Text(
                          'Код-пароль при входе (PIN)',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          widget.preferences.isPinEnabled
                              ? 'Включён — запрашивать 4 цифры при открытии'
                              : 'Дополнительная защита на этом устройстве',
                        ),
                        value: widget.preferences.isPinEnabled,
                        onChanged: (enabled) async {
                          if (enabled) {
                            await _showSetPinDialog();
                          } else {
                            await widget.preferences.disablePin();
                            if (mounted) setState(() {});
                          }
                        },
                      ),
                      if (widget.preferences.isPinEnabled)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => widget.preferences.lockNow(),
                              icon:
                                  const Icon(Icons.lock_outline_rounded, size: 18),
                              label: const Text('Заблокировать экран сейчас'),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Active Devices Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Ваши устройства',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Обновить список устройств',
                              onPressed:
                                  _loading ? null : _loadSecurityAndDevices,
                              icon: const Icon(Icons.refresh_rounded, size: 20),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Список телефонов и компьютеров, на которых выполнен вход в ваш аккаунт.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        if (_loading)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (devices.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('Активное устройство: этот телефон'),
                          )
                        else
                          ...devices.map(
                            (d) => _buildDeviceTile(context, d, palette),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 5. Collapsed "Для специалистов" section (hidden by default)
                Card(
                  child: ExpansionTile(
                    key: const Key('settings_specialist_expansion'),
                    leading: Icon(
                      Icons.build_circle_outlined,
                      color: palette.textMuted,
                    ),
                    title: const Text(
                      'Для специалистов',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Техническая информация для обслуживания',
                      style: TextStyle(fontSize: 12),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    children: [
                      _SpecialistRow(
                        label: 'Статус канала связи',
                        value: isConnected
                            ? 'Защищённое соединение активно'
                            : 'Синхронизация',
                      ),
                      _SpecialistRow(
                        label: 'Криптографический модуль',
                        value: e2eeReady ? 'Активен' : 'Ожидание',
                      ),
                      _SpecialistRow(
                        label: 'Резервное хранилище ключей',
                        value: backupOk ? 'Настроено' : 'Отключено',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки и защита')),
      body: SafeArea(child: body),
    );
  }

  Widget _buildDeviceTile(
    BuildContext context,
    DeviceSessionInfo device,
    FamilyPalette palette,
  ) {
    final verified = device.isCryptographicallyVerified;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.borderSubtle),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: verified
                ? palette.verifiedBadgeBg
                : palette.primaryPine.withValues(alpha: 0.12),
            child: Icon(
              device.isCurrentDevice
                  ? Icons.smartphone_rounded
                  : Icons.devices_other_rounded,
              color: verified ? palette.verifiedBadgeFg : palette.primaryPine,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.isCurrentDevice
                      ? '${device.displayName} (это устройство)'
                      : device.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  verified
                      ? 'Подтверждено криптографически'
                      : 'Стандартный вход • ожидает подтверждения',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        verified ? palette.verifiedBadgeFg : palette.textMuted,
                    fontWeight: verified ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (!verified)
            TextButton(
              onPressed: () => _verifyDevice(device),
              child: const Text('Подтвердить'),
            ),
        ],
      ),
    );
  }
}

class _SpecialistRow extends StatelessWidget {
  final String label;
  final String value;

  const _SpecialistRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

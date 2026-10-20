import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:messenger_core/messenger_core.dart';

/// Screen 1: Warm consumer-grade Welcome & Simple Login Screen.
/// - No pre-filled username (`alice_test` removed).
/// - Server URL is pre-configured internally (`FamilyMessengerController.defaultHomeserverUrl`)
///   and not shown on the main login form.
/// - Responsive and scrollable across 320px–1280px in portrait and landscape.
class WelcomeLoginScreen extends StatefulWidget {
  final FamilyMessengerController controller;
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;
  final VoidCallback onLoggedIn;

  const WelcomeLoginScreen({
    super.key,
    required this.controller,
    required this.themeMode,
    required this.onToggleTheme,
    required this.onLoggedIn,
  });

  @override
  State<WelcomeLoginScreen> createState() => _WelcomeLoginScreenState();
}

class _WelcomeLoginScreenState extends State<WelcomeLoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  String? _errorMessage;
  String? _customServerOverride;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _performLogin() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Пожалуйста, введите ваше имя пользователя и пароль.';
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await widget.controller.login(
        homeserverUrl: _customServerOverride,
        username: username,
        password: password,
      );
      if (mounted) {
        widget.onLoggedIn();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = FriendlyErrorMapper.toUserMessage(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _showAdvancedServerSheet() async {
    final serverCtrl = TextEditingController(
      text: _customServerOverride ??
          FamilyMessengerController.defaultHomeserverUrl,
    );
    final saved = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
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
                const Text(
                  'Настройка подключения',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: FamilySpacing.xs),
                const Text(
                  'Адрес семейного сервера настроен автоматически. Изменяйте его только при переезде на новый адрес.',
                  style: TextStyle(fontSize: 13.5),
                ),
                const SizedBox(height: FamilySpacing.lg),
                TextField(
                  controller: serverCtrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Адрес семейного сервера',
                    prefixIcon: Icon(Icons.cloud_outlined),
                  ),
                ),
                const SizedBox(height: FamilySpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(
                          ctx,
                          FamilyMessengerController.defaultHomeserverUrl,
                        ),
                        child: const Text('По умолчанию'),
                      ),
                    ),
                    const SizedBox(width: FamilySpacing.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: () =>
                            Navigator.pop(ctx, serverCtrl.text.trim()),
                        child: const Text('Сохранить'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (saved != null && saved.isNotEmpty && mounted) {
      setState(() {
        _customServerOverride =
            saved == FamilyMessengerController.defaultHomeserverUrl
                ? null
                : saved;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<FamilyPalette>() ?? FamilyPalette.light;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Family Messenger'),
        actions: [
          IconButton(
            tooltip: 'Переключить тему оформления',
            onPressed: widget.onToggleTheme,
            icon: Icon(
              widget.themeMode == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Параметры подключения',
            onPressed: _showAdvancedServerSheet,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: FamilySpacing.lg,
              vertical: FamilySpacing.md,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Warm Brand Header
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            palette.primaryPine,
                            palette.secondaryTerracotta,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: palette.primaryPine.withValues(alpha: 0.24),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ),
                  const SizedBox(height: FamilySpacing.lg),
                  Text(
                    'Тёплое общение с близкими',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: FamilySpacing.xs),
                  Text(
                    'Закрытый семейный мессенджер. Ваши сообщения и фотографии доступны только членам семьи.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: FamilySpacing.lg),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      E2eeSecurityBadge(
                        encrypted: true,
                        label: 'Личное пространство семьи',
                      ),
                      E2eeSecurityBadge(
                        encrypted: true,
                        label: 'Работает в любой стране',
                      ),
                    ],
                  ),
                  const SizedBox(height: FamilySpacing.xl),

                  // Login Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(FamilySpacing.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Вход в аккаунт',
                            style: TextStyle(
                              fontSize: 17.5,
                              fontWeight: FontWeight.w700,
                              color: palette.textPrimary,
                            ),
                          ),
                          const SizedBox(height: FamilySpacing.md),
                          TextField(
                            key: const Key('login_username_field'),
                            controller: _usernameCtrl,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            decoration: const InputDecoration(
                              labelText: 'Имя пользователя',
                              hintText: 'Например: anna',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                          ),
                          const SizedBox(height: FamilySpacing.md),
                          TextField(
                            key: const Key('login_password_field'),
                            controller: _passwordCtrl,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _performLogin(),
                            decoration: InputDecoration(
                              labelText: 'Пароль',
                              hintText: 'Введите ваш пароль',
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Показать пароль'
                                    : 'Скрыть пароль',
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: FamilySpacing.md),
                            Container(
                              padding: const EdgeInsets.all(FamilySpacing.md),
                              decoration: BoxDecoration(
                                color: palette.dangerBg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.error_outline_rounded,
                                    size: 18,
                                    color: palette.dangerFg,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        color: palette.dangerFg,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: FamilySpacing.xl),
                          FilledButton.icon(
                            key: const Key('login_submit_button'),
                            onPressed: _loading ? null : _performLogin,
                            icon: _loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.arrow_forward_rounded),
                            label: Text(
                              _loading ? 'Входим...' : 'Войти в мессенджер',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: FamilySpacing.md),
                  Text(
                    'Новые аккаунты создаются главой семьи по приглашению.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: palette.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

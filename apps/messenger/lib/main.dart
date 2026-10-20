import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:messenger_core/messenger_core.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'screens/home_shell_screen.dart';
import 'screens/pin_lock_screen.dart';
import 'screens/welcome_login_screen.dart';
import 'state/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FamilyMessengerBootstrap());
}

class FamilyMessengerBootstrap extends StatefulWidget {
  const FamilyMessengerBootstrap({super.key});

  @override
  State<FamilyMessengerBootstrap> createState() =>
      _FamilyMessengerBootstrapState();
}

class _FamilyMessengerBootstrapState extends State<FamilyMessengerBootstrap> {
  FamilyMessengerController? _controller;
  AppPreferencesController? _preferences;
  bool _initializing = true;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _startBootstrap();
  }

  Future<void> _startBootstrap() async {
    try {
      final docsDir = await getApplicationSupportDirectory();
      final storagePath = p.join(docsDir.path, 'family_messenger_store');

      String? vodozemacLibDir;
      if (Platform.isWindows) {
        final exeDir = File(Platform.resolvedExecutable).parent.path;
        if (File(p.join(exeDir, 'vodozemac_bindings_dart.dll')).existsSync()) {
          vodozemacLibDir = exeDir;
        }
      }

      final controller = FamilyMessengerController(
        clientName: 'FamilyMessenger',
        storageDirectoryPath: storagePath,
      );
      await controller.initialize(vodozemacLibraryPath: vodozemacLibDir);

      final preferences = AppPreferencesController(controller.secureVault);
      await preferences.loadPreferences();

      if (mounted) {
        setState(() {
          _controller = controller;
          _preferences = preferences;
          _initializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _initError = e.toString();
          _initializing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return MaterialApp(
        title: 'Family Messenger',
        debugShowCheckedModeBanner: false,
        theme: FamilyTheme.light(),
        darkTheme: FamilyTheme.dark(),
        home: const Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FamilyAvatar(
                  title: 'Семья',
                  radius: 36,
                  isGroup: true,
                ),
                SizedBox(height: 18),
                Text(
                  'Family Messenger',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 14),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_initError != null || _controller == null || _preferences == null) {
      return MaterialApp(
        title: 'Family Messenger',
        debugShowCheckedModeBanner: false,
        theme: FamilyTheme.light(),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Не удалось запустить Family Messenger',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _initError ?? 'Неизвестная ошибка',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _initializing = true;
                        _initError = null;
                      });
                      _startBootstrap();
                    },
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ListenableBuilder(
      listenable: _preferences!,
      builder: (context, _) {
        return MaterialApp(
          title: 'Family Messenger',
          debugShowCheckedModeBanner: false,
          theme: FamilyTheme.light(),
          darkTheme: FamilyTheme.dark(),
          themeMode: _preferences!.themeMode,
          home: _buildRootScreen(),
        );
      },
    );
  }

  Widget _buildRootScreen() {
    final prefs = _preferences!;
    final controller = _controller!;

    if (prefs.isLocked) {
      return PinLockScreen(
        prefs: prefs,
        userDisplayName: controller.currentUserDisplayName,
      );
    }
    if (controller.client.isLogged()) {
      return HomeShellScreen(
        controller: controller,
        preferences: prefs,
        onLoggedOut: () => setState(() {}),
      );
    }
    return WelcomeLoginScreen(
      controller: controller,
      themeMode: prefs.themeMode,
      onToggleTheme: prefs.toggleLightDark,
      onLoggedIn: () => setState(() {}),
    );
  }
}

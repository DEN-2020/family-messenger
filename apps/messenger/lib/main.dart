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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

  runApp(
    FamilyMessengerApp(
      controller: controller,
      preferences: preferences,
    ),
  );
}

class FamilyMessengerApp extends StatefulWidget {
  final FamilyMessengerController controller;
  final AppPreferencesController preferences;

  const FamilyMessengerApp({
    super.key,
    required this.controller,
    required this.preferences,
  });

  @override
  State<FamilyMessengerApp> createState() => _FamilyMessengerAppState();
}

class _FamilyMessengerAppState extends State<FamilyMessengerApp> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.preferences,
      builder: (context, _) {
        return MaterialApp(
          title: 'Family Messenger',
          debugShowCheckedModeBanner: false,
          theme: FamilyTheme.light(),
          darkTheme: FamilyTheme.dark(),
          themeMode: widget.preferences.themeMode,
          home: _buildRootScreen(),
        );
      },
    );
  }

  Widget _buildRootScreen() {
    if (widget.preferences.isLocked) {
      return PinLockScreen(
        prefs: widget.preferences,
        userDisplayName: widget.controller.currentUserDisplayName,
      );
    }
    if (widget.controller.client.isLogged()) {
      return HomeShellScreen(
        controller: widget.controller,
        preferences: widget.preferences,
        onLoggedOut: () => setState(() {}),
      );
    }
    return WelcomeLoginScreen(
      controller: widget.controller,
      themeMode: widget.preferences.themeMode,
      onToggleTheme: widget.preferences.toggleLightDark,
      onLoggedIn: () => setState(() {}),
    );
  }
}

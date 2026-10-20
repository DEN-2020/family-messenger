import 'dart:io';
import 'dart:ui' as ui;

import 'package:design_system/design_system.dart';
import 'package:family_messenger/screens/backup_wizard_screen.dart';
import 'package:family_messenger/screens/create_family_group_screen.dart';
import 'package:family_messenger/screens/family_members_picker_screen.dart';
import 'package:family_messenger/screens/home_shell_screen.dart';
import 'package:family_messenger/screens/pin_lock_screen.dart';
import 'package:family_messenger/screens/profile_screen.dart';
import 'package:family_messenger/screens/settings_security_screen.dart';
import 'package:family_messenger/screens/welcome_login_screen.dart';
import 'package:family_messenger/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:messenger_core/messenger_core.dart';
import 'package:path/path.dart' as p;

Future<void> _loadWindowsSystemFontIfPresent() async {
  final regular = File(r'C:\Windows\Fonts\segoeui.ttf');
  final bold = File(r'C:\Windows\Fonts\segoeuib.ttf');
  if (!regular.existsSync()) return;

  final regularBytes = regular.readAsBytesSync();
  final boldBytes = bold.existsSync() ? bold.readAsBytesSync() : regularBytes;

  for (final family in ['Roboto', 'Segoe UI', '.SF Pro Text', '.SF UI Text']) {
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.view(regularBytes.buffer)))
      ..addFont(Future.value(ByteData.view(boldBytes.buffer)));
    await loader.load();
  }
}

void _assertZeroTechnicalJargonVisible(WidgetTester tester) {
  const forbiddenTerms = [
    'm.megolm.v1.aes-sha2',
    'Ed25519',
    'Curve25519',
    'SSSS',
    '@alice_test:',
    '@bob_test:',
    '!room',
    'asrock.tail56bf63.ts.net',
  ];
  for (final term in forbiddenTerms) {
    expect(
      find.textContaining(term),
      findsNothing,
      reason: 'Technical term "$term" must never be visible on user screens',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late FamilyMessengerController offlineController;
  late AppPreferencesController prefs;

  setUpAll(() async {
    await _loadWindowsSystemFontIfPresent();
    tempDir = Directory.systemTemp.createTempSync('fm_widget_test_');
    String? dllDir;
    final repoRoot = Directory.current.path.endsWith('messenger')
        ? Directory.current.parent.parent.path
        : Directory.current.path;
    final debugDll = p.join(
      repoRoot,
      'apps',
      'messenger',
      'build',
      'windows',
      'x64',
      'runner',
      'Debug',
    );
    if (File(p.join(debugDll, 'vodozemac_bindings_dart.dll')).existsSync()) {
      dllDir = debugDll;
    }

    offlineController = FamilyMessengerController(
      clientName: 'WidgetTestClient',
      storageDirectoryPath: p.join(tempDir.path, 'offline_store'),
    );
    await offlineController.initialize(vodozemacLibraryPath: dllDir);
    prefs = AppPreferencesController(offlineController.secureVault);
    await prefs.loadPreferences();
  });

  tearDownAll(() async {
    await offlineController.dispose();
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  testWidgets(
    'Design System components render cleanly in Light & Dark themes and contain zero technical jargon',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: FamilyTheme.light(),
          darkTheme: FamilyTheme.dark(),
          home: Scaffold(
            body: ListView(
              children: [
                const E2eeSecurityBadge(
                  encrypted: true,
                  label: 'Личная семейная беседа защищена',
                ),
                const ConnectionStateBanner(
                  isConnected: false,
                  statusText: 'Ожидание подключения к интернету',
                ),
                FamilyChatListItem(
                  title: 'Алиса',
                  subtitle: 'Привет! Как дела дома?',
                  timeLabel: '10:30',
                  unreadCount: 2,
                  isGroup: false,
                  onTap: () {},
                ),
                const FamilyMessageBubble(
                  text: 'Мама, мы скоро будем дома!',
                  timeText: '10:31',
                  isMine: true,
                  replyPreviewText: 'Во сколько вы приедете?',
                  deliveryState: MessageDeliveryUiState.delivered,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Личная семейная беседа защищена'), findsOneWidget);
      expect(find.text('Ожидание подключения к интернету'), findsOneWidget);
      expect(find.text('Алиса'), findsOneWidget);
      expect(find.text('Мама, мы скоро будем дома!'), findsOneWidget);
      _assertZeroTechnicalJargonVisible(tester);
    },
  );

  testWidgets(
    'Responsive layout verification across 320, 360, 390, 412, 600, 768, and 1280 widths (Portrait, Landscape, Light, Dark, Keyboard Open)',
    (WidgetTester tester) async {
      const widths = <double>[320, 360, 390, 412, 600, 768, 1280];
      const heights = <double>[640, 844];

      for (final width in widths) {
        for (final height in heights) {
          for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
            tester.view.physicalSize = Size(width, height);
            tester.view.devicePixelRatio = 1.0;

            // 1. Welcome Login Screen (also tested with simulated open keyboard)
            tester.view.viewInsets = const FakeViewPadding(bottom: 260);
            await tester.pumpWidget(
              MaterialApp(
                theme: FamilyTheme.light(),
                darkTheme: FamilyTheme.dark(),
                themeMode: themeMode,
                home: WelcomeLoginScreen(
                  controller: offlineController,
                  themeMode: themeMode,
                  onToggleTheme: () {},
                  onLoggedIn: () {},
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            _assertZeroTechnicalJargonVisible(tester);
            tester.view.viewInsets = FakeViewPadding.zero;

            // 2. Home Shell Screen (Chat List, Family Tab, Profile Tab, Security Tab)
            await tester.pumpWidget(
              MaterialApp(
                theme: FamilyTheme.light(),
                darkTheme: FamilyTheme.dark(),
                themeMode: themeMode,
                home: HomeShellScreen(
                  controller: offlineController,
                  preferences: prefs,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            _assertZeroTechnicalJargonVisible(tester);

            // 3. Create Family Group Screen
            await tester.pumpWidget(
              MaterialApp(
                theme: FamilyTheme.light(),
                darkTheme: FamilyTheme.dark(),
                themeMode: themeMode,
                home: CreateFamilyGroupScreen(
                  controller: offlineController,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            _assertZeroTechnicalJargonVisible(tester);

            // 4. Family Members Picker Screen
            await tester.pumpWidget(
              MaterialApp(
                theme: FamilyTheme.light(),
                darkTheme: FamilyTheme.dark(),
                themeMode: themeMode,
                home: Scaffold(
                  body: FamilyMembersPickerScreen(
                    controller: offlineController,
                    onOpenRoom: (_) {},
                    onCreateGroupRequested: () {},
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            _assertZeroTechnicalJargonVisible(tester);

            // 5. Profile Screen
            await tester.pumpWidget(
              MaterialApp(
                theme: FamilyTheme.light(),
                darkTheme: FamilyTheme.dark(),
                themeMode: themeMode,
                home: ProfileScreen(
                  controller: offlineController,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            _assertZeroTechnicalJargonVisible(tester);

            // 6. Settings & Security Screen
            await tester.pumpWidget(
              MaterialApp(
                theme: FamilyTheme.light(),
                darkTheme: FamilyTheme.dark(),
                themeMode: themeMode,
                home: SettingsSecurityScreen(
                  controller: offlineController,
                  preferences: prefs,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            _assertZeroTechnicalJargonVisible(tester);

            // 7. Backup Wizard Screen
            await tester.pumpWidget(
              MaterialApp(
                theme: FamilyTheme.light(),
                darkTheme: FamilyTheme.dark(),
                themeMode: themeMode,
                home: BackupWizardScreen(
                  controller: offlineController,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            _assertZeroTechnicalJargonVisible(tester);

            // 8. PIN Lock Screen
            await tester.pumpWidget(
              MaterialApp(
                theme: FamilyTheme.light(),
                darkTheme: FamilyTheme.dark(),
                themeMode: themeMode,
                home: PinLockScreen(
                  prefs: prefs,
                  userDisplayName: 'Алиса',
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            _assertZeroTechnicalJargonVisible(tester);
          }
        }
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    },
  );
}

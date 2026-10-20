import 'dart:io';
import 'dart:ui' as ui;

import 'package:design_system/design_system.dart';
import 'package:family_messenger/screens/backup_wizard_screen.dart';
import 'package:family_messenger/screens/create_family_group_screen.dart';
import 'package:family_messenger/screens/family_members_picker_screen.dart';
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

const String _artifactDir =
    r'C:\Users\Admin\.gemini\antigravity\brain\a4de780a-ab69-45b5-9add-a63c8edc6e4f';

Future<void> _loadSystemFonts() async {
  final regular = File(r'C:\Windows\Fonts\segoeui.ttf');
  final bold = File(r'C:\Windows\Fonts\segoeuib.ttf');
  final semibold = File(r'C:\Windows\Fonts\seguisb.ttf');
  if (!regular.existsSync()) return;

  final regularBytes = regular.readAsBytesSync();
  final boldBytes = bold.existsSync() ? bold.readAsBytesSync() : regularBytes;
  final semiBytes =
      semibold.existsSync() ? semibold.readAsBytesSync() : boldBytes;

  for (final family in [
    'Roboto',
    'Segoe UI',
    '.SF Pro Text',
    '.SF UI Text',
    'sans-serif',
  ]) {
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.view(regularBytes.buffer)))
      ..addFont(Future.value(ByteData.view(semiBytes.buffer)))
      ..addFont(Future.value(ByteData.view(boldBytes.buffer)));
    await loader.load();
  }

  // Also load MaterialIcons from Flutter SDK cache so all icons render crisply
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? r'C:\src\flutter';
  final materialIconsFile = File(
    p.join(
      flutterRoot,
      'bin',
      'cache',
      'artifacts',
      'material_fonts',
      'MaterialIcons-Regular.otf',
    ),
  );
  if (materialIconsFile.existsSync()) {
    final iconBytes = materialIconsFile.readAsBytesSync();
    final iconLoader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.view(iconBytes.buffer)));
    await iconLoader.load();
  }
}

Future<void> _captureScreen(
  WidgetTester tester, {
  required Size size,
  required ThemeMode themeMode,
  required Widget child,
  required String filename,
}) async {
  final boundaryKey = GlobalKey();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;

  await tester.pumpWidget(
    RepaintBoundary(
      key: boundaryKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: FamilyTheme.light(),
        darkTheme: FamilyTheme.dark(),
        themeMode: themeMode,
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();

  final boundary = boundaryKey.currentContext!.findRenderObject()
      as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData != null) {
      final outFile = File(p.join(_artifactDir, filename));
      outFile.parent.createSync(recursive: true);
      outFile.writeAsBytesSync(byteData.buffer.asUint8List());
    }
  });
}

/// Showcase widget for Screen 2 (Chat List with avatars, human names, timestamps, unread counters, and explicit invite confirmation).
class _ShowcaseChatListScreen extends StatelessWidget {
  const _ShowcaseChatListScreen();

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<FamilyPalette>() ?? FamilyPalette.light;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Семейные чаты'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.group_add_rounded),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.edit_square),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Поиск по семейным чатам...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          // Explicit Room Invite Confirmation Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Card(
              color: palette.primaryPine.withValues(alpha: 0.08),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        FamilyAvatar(
                          title: 'Выходные на даче',
                          radius: 18,
                          isGroup: true,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Приглашение в чат «Выходные на даче»',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'Елена приглашает вас присоединиться',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {},
                          child: const Text('Отклонить'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          onPressed: () {},
                          child: const Text('Принять'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                FamilyChatListItem(
                  title: 'Наша семья',
                  subtitle: 'Елена: Ужин будет готов к 19:00, ждём всех!',
                  timeLabel: '18:42',
                  unreadCount: 3,
                  isGroup: true,
                  onTap: () {},
                ),
                FamilyChatListItem(
                  title: 'Боб',
                  subtitle: 'Купил продукты и свежий хлеб по дороге домой',
                  timeLabel: '18:15',
                  unreadCount: 1,
                  isGroup: false,
                  onTap: () {},
                ),
                FamilyChatListItem(
                  title: 'Елена',
                  subtitle: 'Спасибо за фотографии с прогулки!',
                  timeLabel: '16:05',
                  unreadCount: 0,
                  isOutgoingLast: true,
                  isGroup: false,
                  onTap: () {},
                ),
                FamilyChatListItem(
                  title: 'Максим',
                  subtitle: 'Уроки сделал, иду на тренировку',
                  timeLabel: 'Вчера',
                  unreadCount: 0,
                  isGroup: false,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: palette.primaryPine,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.chat_bubble_outline_rounded),
        label: const Text('Новый чат'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(
            icon: Badge(label: Text('1'), child: Icon(Icons.forum_outlined)),
            selectedIcon: Badge(
              label: Text('1'),
              child: Icon(Icons.forum_rounded),
            ),
            label: 'Чаты',
          ),
          NavigationDestination(
            icon: Icon(Icons.diversity_3_outlined),
            selectedIcon: Icon(Icons.diversity_3_rounded),
            label: 'Семья',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Профиль',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield_rounded),
            label: 'Защита',
          ),
        ],
      ),
    );
  }
}

/// Showcase widget for Screen 3 (Personal Chat with message bubbles, reply quote, delivery checkmarks, and composer).
class _ShowcasePersonalChatScreen extends StatelessWidget {
  final bool showBackButton;
  const _ShowcasePersonalChatScreen({this.showBackButton = true});

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<FamilyPalette>() ?? FamilyPalette.light;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: showBackButton,
        leading: showBackButton ? const BackButton() : null,
        titleSpacing: showBackButton ? 0 : 16,
        title: const Row(
          children: [
            FamilyAvatar(
              title: 'Боб',
              radius: 19,
              showProtectedDot: true,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Боб',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Личная защищённая беседа',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: palette.sidebarSurface,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Сегодня',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const FamilyMessageBubble(
                  text: 'Привет! Во сколько вы сегодня возвращаетесь домой?',
                  timeText: '18:10',
                  isMine: false,
                  senderName: 'Боб',
                ),
                const FamilyMessageBubble(
                  text: 'Привет! Мы заехали в пекарню, будем через 20 минут.',
                  timeText: '18:12',
                  isMine: true,
                  deliveryState: MessageDeliveryUiState.delivered,
                ),
                const FamilyMessageBubble(
                  text: 'Купил продукты и свежий хлеб по дороге домой',
                  timeText: '18:15',
                  isMine: false,
                  senderName: 'Боб',
                  replyPreviewText:
                      'Привет! Мы заехали в пекарню, будем через 20 минут.',
                ),
                const FamilyMessageBubble(
                  text: 'Отлично, спасибо! Елена уже ставит чайник.',
                  timeText: '18:16',
                  isMine: true,
                  deliveryState: MessageDeliveryUiState.delivered,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(
              color: palette.sidebarSurface,
              border: Border(top: BorderSide(color: palette.borderSubtle)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Напишите сообщение...',
                      fillColor: palette.cardSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 22,
                  backgroundColor: palette.primaryPine,
                  child: const Icon(Icons.send_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Showcase widget for Desktop Split-View (1280x800 Dark Theme).
class _ShowcaseDesktopSplitScreen extends StatelessWidget {
  const _ShowcaseDesktopSplitScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: 0,
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: FamilyAvatar(
                title: 'Алиса',
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
                icon: Icon(Icons.diversity_3_outlined),
                selectedIcon: Icon(Icons.diversity_3_rounded),
                label: Text('Семья'),
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
          SizedBox(
            width: 350,
            child: Column(
              children: [
                AppBar(
                  title: const Text('Семейные чаты'),
                  actions: [
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.group_add_rounded),
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.edit_square),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 8, 14, 8),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Поиск по семейным чатам...',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      FamilyChatListItem(
                        title: 'Боб',
                        subtitle: 'Отлично, спасибо! Елена уже ставит чайник.',
                        timeLabel: '18:16',
                        unreadCount: 0,
                        isSelected: true,
                        isOutgoingLast: true,
                        onTap: () {},
                      ),
                      FamilyChatListItem(
                        title: 'Наша семья',
                        subtitle: 'Елена: Ужин будет готов к 19:00, ждём всех!',
                        timeLabel: '18:42',
                        unreadCount: 3,
                        isGroup: true,
                        onTap: () {},
                      ),
                      FamilyChatListItem(
                        title: 'Елена',
                        subtitle: 'Спасибо за фотографии с прогулки!',
                        timeLabel: '16:05',
                        unreadCount: 0,
                        isOutgoingLast: true,
                        onTap: () {},
                      ),
                      FamilyChatListItem(
                        title: 'Максим',
                        subtitle: 'Уроки сделал, иду на тренировку',
                        timeLabel: 'Вчера',
                        unreadCount: 0,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          const Expanded(
            child: _ShowcasePersonalChatScreen(showBackButton: false),
          ),
        ],
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late FamilyMessengerController controller;
  late AppPreferencesController prefs;

  setUpAll(() async {
    await _loadSystemFonts();
    tempDir = Directory.systemTemp.createTempSync('fm_screenshots_');
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

    controller = FamilyMessengerController(
      clientName: 'ScreenshotClient',
      storageDirectoryPath: p.join(tempDir.path, 'store'),
    );
    await controller.initialize(vodozemacLibraryPath: dllDir);
    prefs = AppPreferencesController(controller.secureVault);
    await prefs.loadPreferences();
  });

  tearDownAll(() async {
    await controller.dispose();
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  testWidgets('Generate high-resolution Phase 1 UI screenshots', (tester) async {
    if (!Directory(_artifactDir).existsSync()) {
      return;
    }

    const mobileSize = Size(390, 844);
    const desktopSize = Size(1280, 800);

    // 1. Welcome & Simple Login (Light)
    await _captureScreen(
      tester,
      size: mobileSize,
      themeMode: ThemeMode.light,
      filename: 'phase1_01_welcome_login_light.png',
      child: WelcomeLoginScreen(
        controller: controller,
        themeMode: ThemeMode.light,
        onToggleTheme: () {},
        onLoggedIn: () {},
      ),
    );

    // 2. Welcome & Simple Login (Dark)
    await _captureScreen(
      tester,
      size: mobileSize,
      themeMode: ThemeMode.dark,
      filename: 'phase1_02_welcome_login_dark.png',
      child: WelcomeLoginScreen(
        controller: controller,
        themeMode: ThemeMode.dark,
        onToggleTheme: () {},
        onLoggedIn: () {},
      ),
    );

    // 3. Chat List with Avatars, Names, Timestamps, Unread Badges & Invite Confirmation
    await _captureScreen(
      tester,
      size: mobileSize,
      themeMode: ThemeMode.light,
      filename: 'phase1_03_chat_list_mobile.png',
      child: const _ShowcaseChatListScreen(),
    );

    // 4. Personal Chat with Bubbles, Reply Quote, Delivery Checkmarks & Composer
    await _captureScreen(
      tester,
      size: mobileSize,
      themeMode: ThemeMode.light,
      filename: 'phase1_04_personal_chat_mobile.png',
      child: const _ShowcasePersonalChatScreen(),
    );

    // 5. Create Family Group Screen
    await _captureScreen(
      tester,
      size: mobileSize,
      themeMode: ThemeMode.light,
      filename: 'phase1_05_family_group_creation.png',
      child: CreateFamilyGroupScreen(controller: controller),
    );

    // 6. Pick Family Members Screen
    await _captureScreen(
      tester,
      size: mobileSize,
      themeMode: ThemeMode.light,
      filename: 'phase1_06_family_members_picker.png',
      child: Scaffold(
        appBar: AppBar(title: const Text('Семья')),
        body: FamilyMembersPickerScreen(
          controller: controller,
          onOpenRoom: (_) {},
          onCreateGroupRequested: () {},
        ),
      ),
    );

    // 7. User Profile Screen
    await _captureScreen(
      tester,
      size: mobileSize,
      themeMode: ThemeMode.light,
      filename: 'phase1_07_user_profile.png',
      child: ProfileScreen(controller: controller),
    );

    // 8. Settings, Security & Device Management Screen
    await _captureScreen(
      tester,
      size: mobileSize,
      themeMode: ThemeMode.light,
      filename: 'phase1_08_settings_security_devices.png',
      child: SettingsSecurityScreen(
        controller: controller,
        preferences: prefs,
      ),
    );

    // 9. Backup Wizard Screen + PIN Lock Screen
    await _captureScreen(
      tester,
      size: mobileSize,
      themeMode: ThemeMode.light,
      filename: 'phase1_09_backup_wizard.png',
      child: BackupWizardScreen(controller: controller),
    );

    await _captureScreen(
      tester,
      size: mobileSize,
      themeMode: ThemeMode.light,
      filename: 'phase1_11_pin_lock_screen.png',
      child: PinLockScreen(
        prefs: prefs,
        userDisplayName: 'Алиса',
      ),
    );

    // 10. Windows Desktop Split-View (Dark Theme, 1280x800)
    await _captureScreen(
      tester,
      size: desktopSize,
      themeMode: ThemeMode.dark,
      filename: 'phase1_10_desktop_split_view_dark.png',
      child: const _ShowcaseDesktopSplitScreen(),
    );

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

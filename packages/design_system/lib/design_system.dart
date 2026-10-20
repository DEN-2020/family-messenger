library design_system;

import 'package:flutter/material.dart';

/// Color tokens for the "Hearth & Nordic Linen" v2 consumer design system.
@immutable
class FamilyPalette extends ThemeExtension<FamilyPalette> {
  final Color canvas;
  final Color sidebarSurface;
  final Color cardSurface;
  final Color elevatedSurface;
  final Color borderSubtle;
  final Color primaryPine;
  final Color secondaryTerracotta;
  final Color outgoingBubble;
  final Color outgoingText;
  final Color incomingBubble;
  final Color incomingText;
  final Color verifiedBadgeBg;
  final Color verifiedBadgeFg;
  final Color warningBannerBg;
  final Color warningBannerFg;
  final Color dangerBg;
  final Color dangerFg;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  const FamilyPalette({
    required this.canvas,
    required this.sidebarSurface,
    required this.cardSurface,
    required this.elevatedSurface,
    required this.borderSubtle,
    required this.primaryPine,
    required this.secondaryTerracotta,
    required this.outgoingBubble,
    required this.outgoingText,
    required this.incomingBubble,
    required this.incomingText,
    required this.verifiedBadgeBg,
    required this.verifiedBadgeFg,
    required this.warningBannerBg,
    required this.warningBannerFg,
    required this.dangerBg,
    required this.dangerFg,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
  });

  static const light = FamilyPalette(
    canvas: Color(0xFFF6F3EC),
    sidebarSurface: Color(0xFFEEEAE0),
    cardSurface: Color(0xFFFFFFFF),
    elevatedSurface: Color(0xFFFDFBF7),
    borderSubtle: Color(0xFFE3DDD1),
    primaryPine: Color(0xFF235745),
    secondaryTerracotta: Color(0xFFC26A41),
    outgoingBubble: Color(0xFF235745),
    outgoingText: Color(0xFFFBF9F5),
    incomingBubble: Color(0xFFFFFFFF),
    incomingText: Color(0xFF1A211E),
    verifiedBadgeBg: Color(0xFFDDF0E6),
    verifiedBadgeFg: Color(0xFF1B573F),
    warningBannerBg: Color(0xFFFCEBDF),
    warningBannerFg: Color(0xFF8B3E19),
    dangerBg: Color(0xFFFCE6E6),
    dangerFg: Color(0xFF9E2A2B),
    textPrimary: Color(0xFF1A211E),
    textSecondary: Color(0xFF535E59),
    textMuted: Color(0xFF7B8681),
  );

  static const dark = FamilyPalette(
    canvas: Color(0xFF0F1412),
    sidebarSurface: Color(0xFF161D1A),
    cardSurface: Color(0xFF1B2420),
    elevatedSurface: Color(0xFF222D28),
    borderSubtle: Color(0xFF2B3832),
    primaryPine: Color(0xFF5EC29E),
    secondaryTerracotta: Color(0xFFE38F66),
    outgoingBubble: Color(0xFF214A3B),
    outgoingText: Color(0xFFEDF6F2),
    incomingBubble: Color(0xFF1B2420),
    incomingText: Color(0xFFE7EFEA),
    verifiedBadgeBg: Color(0xFF18362B),
    verifiedBadgeFg: Color(0xFF82D6B6),
    warningBannerBg: Color(0xFF392318),
    warningBannerFg: Color(0xFFF5B493),
    dangerBg: Color(0xFF3B1D1E),
    dangerFg: Color(0xFFF49798),
    textPrimary: Color(0xFFE7EFEA),
    textSecondary: Color(0xFF9BA8A2),
    textMuted: Color(0xFF6F7D77),
  );

  /// Warm, harmonious avatar background colors derived deterministically from a seed string.
  static const List<List<Color>> avatarGradients = [
    [Color(0xFF2B6CB0), Color(0xFF2C5282)],
    [Color(0xFF2F855A), Color(0xFF276749)],
    [Color(0xFFC05621), Color(0xFF9C4221)],
    [Color(0xFF6B46C1), Color(0xFF553C9A)],
    [Color(0xFFB83280), Color(0xFF97266D)],
    [Color(0xFF2C7A7B), Color(0xFF285E61)],
    [Color(0xFFB7791F), Color(0xFF975A16)],
    [Color(0xFF319795), Color(0xFF234E52)],
  ];

  static List<Color> gradientForSeed(String seed) {
    var hash = 0;
    for (var i = 0; i < seed.length; i++) {
      hash = 0x1fffffff & (hash + seed.codeUnitAt(i));
      hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
      hash ^= (hash >> 6);
    }
    final index = hash.abs() % avatarGradients.length;
    return avatarGradients[index];
  }

  @override
  FamilyPalette copyWith({
    Color? canvas,
    Color? sidebarSurface,
    Color? cardSurface,
    Color? elevatedSurface,
    Color? borderSubtle,
    Color? primaryPine,
    Color? secondaryTerracotta,
    Color? outgoingBubble,
    Color? outgoingText,
    Color? incomingBubble,
    Color? incomingText,
    Color? verifiedBadgeBg,
    Color? verifiedBadgeFg,
    Color? warningBannerBg,
    Color? warningBannerFg,
    Color? dangerBg,
    Color? dangerFg,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
  }) {
    return FamilyPalette(
      canvas: canvas ?? this.canvas,
      sidebarSurface: sidebarSurface ?? this.sidebarSurface,
      cardSurface: cardSurface ?? this.cardSurface,
      elevatedSurface: elevatedSurface ?? this.elevatedSurface,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      primaryPine: primaryPine ?? this.primaryPine,
      secondaryTerracotta: secondaryTerracotta ?? this.secondaryTerracotta,
      outgoingBubble: outgoingBubble ?? this.outgoingBubble,
      outgoingText: outgoingText ?? this.outgoingText,
      incomingBubble: incomingBubble ?? this.incomingBubble,
      incomingText: incomingText ?? this.incomingText,
      verifiedBadgeBg: verifiedBadgeBg ?? this.verifiedBadgeBg,
      verifiedBadgeFg: verifiedBadgeFg ?? this.verifiedBadgeFg,
      warningBannerBg: warningBannerBg ?? this.warningBannerBg,
      warningBannerFg: warningBannerFg ?? this.warningBannerFg,
      dangerBg: dangerBg ?? this.dangerBg,
      dangerFg: dangerFg ?? this.dangerFg,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
    );
  }

  @override
  FamilyPalette lerp(ThemeExtension<FamilyPalette>? other, double t) {
    if (other is! FamilyPalette) return this;
    return FamilyPalette(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      sidebarSurface: Color.lerp(sidebarSurface, other.sidebarSurface, t)!,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      primaryPine: Color.lerp(primaryPine, other.primaryPine, t)!,
      secondaryTerracotta:
          Color.lerp(secondaryTerracotta, other.secondaryTerracotta, t)!,
      outgoingBubble: Color.lerp(outgoingBubble, other.outgoingBubble, t)!,
      outgoingText: Color.lerp(outgoingText, other.outgoingText, t)!,
      incomingBubble: Color.lerp(incomingBubble, other.incomingBubble, t)!,
      incomingText: Color.lerp(incomingText, other.incomingText, t)!,
      verifiedBadgeBg: Color.lerp(verifiedBadgeBg, other.verifiedBadgeBg, t)!,
      verifiedBadgeFg: Color.lerp(verifiedBadgeFg, other.verifiedBadgeFg, t)!,
      warningBannerBg: Color.lerp(warningBannerBg, other.warningBannerBg, t)!,
      warningBannerFg: Color.lerp(warningBannerFg, other.warningBannerFg, t)!,
      dangerBg: Color.lerp(dangerBg, other.dangerBg, t)!,
      dangerFg: Color.lerp(dangerFg, other.dangerFg, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
    );
  }
}

/// Spacing scale tokens (4px base grid).
class FamilySpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double desktopSplitBreakpoint = 720;
}

/// Theme builder for Family Messenger (Light & Dark).
class FamilyTheme {
  static ThemeData light() => _build(Brightness.light, FamilyPalette.light);
  static ThemeData dark() => _build(Brightness.dark, FamilyPalette.dark);

  static ThemeData _build(Brightness brightness, FamilyPalette palette) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: palette.primaryPine,
      brightness: brightness,
      primary: palette.primaryPine,
      secondary: palette.secondaryTerracotta,
      surface: palette.canvas,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.canvas,
      extensions: [palette],
      dividerColor: palette.borderSubtle,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.sidebarSurface,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: palette.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.cardSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.borderSubtle),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.sidebarSurface,
        indicatorColor: palette.primaryPine.withValues(alpha: 0.16),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? palette.primaryPine : palette.textSecondary,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.cardSurface,
        hintStyle: TextStyle(color: palette.textMuted, fontSize: 14.5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.primaryPine, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide(color: palette.borderSubtle),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Warm gradient avatar displaying 1–2 initials or a group icon.
class FamilyAvatar extends StatelessWidget {
  final String title;
  final String? seed;
  final double radius;
  final bool isGroup;
  final bool showProtectedDot;

  const FamilyAvatar({
    super.key,
    required this.title,
    this.seed,
    this.radius = 22,
    this.isGroup = false,
    this.showProtectedDot = false,
  });

  String _extractInitials(String raw) {
    final cleaned = raw.trim();
    if (cleaned.isEmpty) return '?';
    final words = cleaned
        .split(RegExp(r'[\s_.-]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.length >= 2) {
      final first = words[0].characters.first.toUpperCase();
      final second = words[1].characters.first.toUpperCase();
      return '$first$second';
    }
    return cleaned.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<FamilyPalette>() ?? FamilyPalette.light;
    final colors = FamilyPalette.gradientForSeed(seed ?? title);
    final initials = _extractInitials(title);

    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.last.withValues(alpha: 0.22),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: isGroup && initials == '?'
                ? Icon(
                    Icons.groups_rounded,
                    color: Colors.white,
                    size: radius * 0.95,
                  )
                : Text(
                    initials,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: radius * 0.72,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
          ),
          if (showProtectedDot)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: radius * 0.58,
                height: radius * 0.58,
                decoration: BoxDecoration(
                  color: palette.verifiedBadgeBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.cardSurface, width: 1.5),
                ),
                child: Icon(
                  Icons.shield_rounded,
                  size: radius * 0.34,
                  color: palette.verifiedBadgeFg,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pill badge displaying protection or status in plain human language.
class E2eeSecurityBadge extends StatelessWidget {
  final bool encrypted;
  final String label;

  const E2eeSecurityBadge({
    super.key,
    required this.encrypted,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<FamilyPalette>() ?? FamilyPalette.light;
    final bg = encrypted ? palette.verifiedBadgeBg : palette.warningBannerBg;
    final fg = encrypted ? palette.verifiedBadgeFg : palette.warningBannerFg;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            encrypted ? Icons.shield_outlined : Icons.info_outline,
            size: 14,
            color: fg,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Live connection banner that appears when offline or reconnecting.
class ConnectionStateBanner extends StatelessWidget {
  final bool isConnected;
  final String statusText;
  final VoidCallback? onRetry;

  const ConnectionStateBanner({
    super.key,
    required this.isConnected,
    required this.statusText,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isConnected) return const SizedBox.shrink();
    final palette =
        Theme.of(context).extension<FamilyPalette>() ?? FamilyPalette.light;

    return Material(
      color: palette.warningBannerBg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 18,
              color: palette.warningBannerFg,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                statusText,
                style: TextStyle(
                  color: palette.warningBannerFg,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  'Обновить',
                  style: TextStyle(
                    color: palette.warningBannerFg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Friendly empty state widget for chat lists, search, and conversations.
class FamilyEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const FamilyEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<FamilyPalette>() ?? FamilyPalette.light;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(FamilySpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: palette.primaryPine.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: palette.primaryPine),
              ),
              const SizedBox(height: FamilySpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17.5,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: FamilySpacing.sm),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: palette.textSecondary,
                ),
              ),
              if (action != null) ...[
                const SizedBox(height: FamilySpacing.xl),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Consumer-grade chat list row with avatar, human name, time, unread counter, and delivery indicator.
class FamilyChatListItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final String timeLabel;
  final int unreadCount;
  final bool isGroup;
  final bool isSelected;
  final bool isOutgoingLast;
  final VoidCallback onTap;

  const FamilyChatListItem({
    super.key,
    required this.title,
    required this.subtitle,
    required this.timeLabel,
    this.unreadCount = 0,
    this.isGroup = false,
    this.isSelected = false,
    this.isOutgoingLast = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<FamilyPalette>() ?? FamilyPalette.light;

    return Material(
      color: isSelected
          ? palette.primaryPine.withValues(alpha: 0.11)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              FamilyAvatar(
                title: title,
                radius: 24,
                isGroup: isGroup,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (isGroup) ...[
                          Icon(
                            Icons.people_alt_outlined,
                            size: 15,
                            color: palette.textSecondary,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: unreadCount > 0
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: palette.textPrimary,
                            ),
                          ),
                        ),
                        if (timeLabel.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            timeLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: unreadCount > 0
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: unreadCount > 0
                                  ? palette.primaryPine
                                  : palette.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (isOutgoingLast) ...[
                          Icon(
                            Icons.done_all_rounded,
                            size: 15,
                            color: palette.primaryPine,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: unreadCount > 0
                                  ? palette.textPrimary
                                  : palette.textSecondary,
                              fontWeight: unreadCount > 0
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            constraints: const BoxConstraints(minWidth: 22),
                            decoration: BoxDecoration(
                              color: palette.primaryPine,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Message delivery state for chat bubbles.
enum MessageDeliveryUiState {
  sending,
  sent,
  delivered,
  failed,
}

/// Consumer-grade message bubble with human sender name, timestamp, and delivery indicator.
class FamilyMessageBubble extends StatelessWidget {
  final String text;
  final String timeText;
  final bool isMine;
  final String? senderName;
  final bool showSenderName;
  final String? replyPreviewText;
  final MessageDeliveryUiState deliveryState;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? mediaWidget;

  const FamilyMessageBubble({
    super.key,
    required this.text,
    required this.timeText,
    required this.isMine,
    this.senderName,
    this.showSenderName = false,
    this.replyPreviewText,
    this.deliveryState = MessageDeliveryUiState.delivered,
    this.onTap,
    this.onLongPress,
    this.mediaWidget,
  });

  @override
  Widget build(BuildContext context) {
    final palette =
        Theme.of(context).extension<FamilyPalette>() ?? FamilyPalette.light;
    final bg = isMine ? palette.outgoingBubble : palette.incomingBubble;
    final fg = isMine ? palette.outgoingText : palette.incomingText;
    final metaColor = isMine
        ? palette.outgoingText.withValues(alpha: 0.76)
        : palette.textMuted;

    IconData statusIcon;
    switch (deliveryState) {
      case MessageDeliveryUiState.sending:
        statusIcon = Icons.schedule_rounded;
        break;
      case MessageDeliveryUiState.sent:
        statusIcon = Icons.check_rounded;
        break;
      case MessageDeliveryUiState.delivered:
        statusIcon = Icons.done_all_rounded;
        break;
      case MessageDeliveryUiState.failed:
        statusIcon = Icons.error_outline_rounded;
        break;
    }

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.fromLTRB(14, 9, 12, 8),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78 > 460
                ? 460
                : MediaQuery.sizeOf(context).width * 0.78,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMine ? 18 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 18),
            ),
            border: isMine ? null : Border.all(color: palette.borderSubtle),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showSenderName &&
                  !isMine &&
                  senderName != null &&
                  senderName!.isNotEmpty) ...[
                Text(
                  senderName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: FamilyPalette.gradientForSeed(senderName!).first,
                  ),
                ),
                const SizedBox(height: 3),
              ],
              if (replyPreviewText != null && replyPreviewText!.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isMine
                        ? Colors.white.withValues(alpha: 0.14)
                        : palette.sidebarSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(
                        color: isMine ? Colors.white : palette.primaryPine,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Text(
                    replyPreviewText!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: fg.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
              if (mediaWidget != null) ...[
                mediaWidget!,
                if (text.isNotEmpty) const SizedBox(height: 6),
              ],
              if (text.isNotEmpty)
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.38,
                    color: fg,
                  ),
                ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    timeText,
                    style: TextStyle(
                      fontSize: 11,
                      color: metaColor,
                    ),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 4),
                    Icon(
                      statusIcon,
                      size: 14,
                      color: deliveryState == MessageDeliveryUiState.failed
                          ? palette.dangerFg
                          : metaColor,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modern voice message bubble with Play/Pause button, animated waveform bars, and duration.
class FamilyVoiceBubble extends StatelessWidget {
  final bool isPlaying;
  final String durationText;
  final double progress; // 0.0 to 1.0
  final bool isMine;
  final VoidCallback onPlayPause;

  const FamilyVoiceBubble({
    super.key,
    required this.isPlaying,
    required this.durationText,
    this.progress = 0.0,
    required this.isMine,
    required this.onPlayPause,
  });

  @override
  Widget build(BuildContext context) {
    final waveColor =
        isMine ? Colors.white.withValues(alpha: 0.45) : Colors.black26;
    final activeWave = isMine ? Colors.white : const Color(0xFF235745);

    // 16 decorative waveform bar heights
    const bars = [8, 14, 22, 12, 18, 26, 16, 20, 24, 14, 22, 10, 18, 20, 14, 10];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: isMine
                  ? Colors.white.withValues(alpha: 0.22)
                  : const Color(0xFF235745),
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
              minimumSize: const Size(36, 36),
            ),
            icon: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 22,
            ),
            onPressed: onPlayPause,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (var i = 0; i < bars.length; i++)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      width: 3,
                      height: bars[i].toDouble(),
                      decoration: BoxDecoration(
                        color: (i / bars.length) <= progress
                            ? activeWave
                            : waveColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                durationText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isMine
                      ? Colors.white.withValues(alpha: 0.85)
                      : Colors.black54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Modern file / document attachment card with icon, title, and size.
class FamilyFileAttachmentBubble extends StatelessWidget {
  final String fileName;
  final String sizeLabel;
  final bool isMine;
  final IconData icon;
  final VoidCallback? onTap;

  const FamilyFileAttachmentBubble({
    super.key,
    required this.fileName,
    required this.sizeLabel,
    required this.isMine,
    this.icon = Icons.insert_drive_file_rounded,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isMine
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.black.withValues(alpha: 0.05);
    final fg = isMine ? Colors.white : Colors.black87;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isMine
                    ? Colors.white.withValues(alpha: 0.22)
                    : const Color(0xFF235745),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sizeLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: isMine ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

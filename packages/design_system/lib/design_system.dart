library design_system;

import 'package:flutter/material.dart';

/// Color tokens for the "Hearth & Nordic Linen" design language.
@immutable
class FamilyPalette extends ThemeExtension<FamilyPalette> {
  final Color canvas;
  final Color sidebarSurface;
  final Color cardSurface;
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
  final Color textPrimary;
  final Color textSecondary;

  const FamilyPalette({
    required this.canvas,
    required this.sidebarSurface,
    required this.cardSurface,
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
    required this.textPrimary,
    required this.textSecondary,
  });

  static const light = FamilyPalette(
    canvas: Color(0xFFF7F4EF),
    sidebarSurface: Color(0xFFEFECE6),
    cardSurface: Color(0xFFFFFFFF),
    borderSubtle: Color(0xFFE2DDD5),
    primaryPine: Color(0xFF2A5C4A),
    secondaryTerracotta: Color(0xFFB86B43),
    outgoingBubble: Color(0xFF2A5C4A),
    outgoingText: Color(0xFFF9F7F3),
    incomingBubble: Color(0xFFFFFFFF),
    incomingText: Color(0xFF1C201E),
    verifiedBadgeBg: Color(0xFFDFF0E8),
    verifiedBadgeFg: Color(0xFF1E5C42),
    warningBannerBg: Color(0xFFFBE9DF),
    warningBannerFg: Color(0xFF8C3F1B),
    textPrimary: Color(0xFF1C201E),
    textSecondary: Color(0xFF5C6460),
  );

  static const dark = FamilyPalette(
    canvas: Color(0xFF121615),
    sidebarSurface: Color(0xFF181E1C),
    cardSurface: Color(0xFF1D2421),
    borderSubtle: Color(0xFF2B3531),
    primaryPine: Color(0xFF63B999),
    secondaryTerracotta: Color(0xFFE09167),
    outgoingBubble: Color(0xFF21483A),
    outgoingText: Color(0xFFECF4F0),
    incomingBubble: Color(0xFF1D2421),
    incomingText: Color(0xFFE6ECE9),
    verifiedBadgeBg: Color(0xFF19382D),
    verifiedBadgeFg: Color(0xFF85D6B7),
    warningBannerBg: Color(0xFF3A2419),
    warningBannerFg: Color(0xFFF3B391),
    textPrimary: Color(0xFFE6ECE9),
    textSecondary: Color(0xFF9AA6A0),
  );

  @override
  FamilyPalette copyWith({
    Color? canvas,
    Color? sidebarSurface,
    Color? cardSurface,
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
    Color? textPrimary,
    Color? textSecondary,
  }) {
    return FamilyPalette(
      canvas: canvas ?? this.canvas,
      sidebarSurface: sidebarSurface ?? this.sidebarSurface,
      cardSurface: cardSurface ?? this.cardSurface,
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
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
    );
  }

  @override
  FamilyPalette lerp(ThemeExtension<FamilyPalette>? other, double t) {
    if (other is! FamilyPalette) return this;
    return FamilyPalette(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      sidebarSurface: Color.lerp(sidebarSurface, other.sidebarSurface, t)!,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      primaryPine: Color.lerp(primaryPine, other.primaryPine, t)!,
      secondaryTerracotta: Color.lerp(secondaryTerracotta, other.secondaryTerracotta, t)!,
      outgoingBubble: Color.lerp(outgoingBubble, other.outgoingBubble, t)!,
      outgoingText: Color.lerp(outgoingText, other.outgoingText, t)!,
      incomingBubble: Color.lerp(incomingBubble, other.incomingBubble, t)!,
      incomingText: Color.lerp(incomingText, other.incomingText, t)!,
      verifiedBadgeBg: Color.lerp(verifiedBadgeBg, other.verifiedBadgeBg, t)!,
      verifiedBadgeFg: Color.lerp(verifiedBadgeFg, other.verifiedBadgeFg, t)!,
      warningBannerBg: Color.lerp(warningBannerBg, other.warningBannerBg, t)!,
      warningBannerFg: Color.lerp(warningBannerFg, other.warningBannerFg, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
    );
  }
}

/// Spacing scale tokens (4px base grid).
class FamilySpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double desktopSplitBreakpoint = 760;
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
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.cardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: palette.borderSubtle),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.cardSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.primaryPine, width: 1.5),
        ),
      ),
    );
  }
}

/// Pill badge displaying E2EE status (Megolm verified or unencrypted warning).
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
    final palette = Theme.of(context).extension<FamilyPalette>() ?? FamilyPalette.light;
    final bg = encrypted ? palette.verifiedBadgeBg : palette.warningBannerBg;
    final fg = encrypted ? palette.verifiedBadgeFg : palette.warningBannerFg;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            encrypted ? Icons.verified_user_outlined : Icons.lock_open_outlined,
            size: 14,
            color: fg,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w600,
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
    final palette = Theme.of(context).extension<FamilyPalette>() ?? FamilyPalette.light;

    return Material(
      color: palette.warningBannerBg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined, size: 18, color: palette.warningBannerFg),
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
                child: Text(
                  'Повторить',
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

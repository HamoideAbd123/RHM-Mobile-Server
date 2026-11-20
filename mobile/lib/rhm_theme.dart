import 'package:material_ui/material_ui.dart';

/// Canonical spacing, layout, shape and motion scales shared by mobile screens.
abstract final class RhmDesignTokens {
  static const spacing4 = 4.0;
  static const spacing8 = 8.0;
  static const spacing12 = 12.0;
  static const spacing16 = 16.0;
  static const spacing20 = 20.0;
  static const spacing24 = 24.0;
  static const spacing32 = 32.0;
  static const spacing40 = 40.0;
  static const spacing48 = 48.0;

  static const radiusSmall = 8.0;
  static const radiusControl = 10.0;
  static const radiusCard = 12.0;
  static const radiusDialog = 16.0;
  static const radiusPill = 999.0;

  static const elevationFlat = 0.0;
  static const elevationFloating = 3.0;
  static const elevationModal = 8.0;

  static const motionFast = Duration(milliseconds: 160);
  static const motionStandard = Duration(milliseconds: 220);
  static const motionSlow = Duration(milliseconds: 320);

  static const mobileGutter = 12.0;
  static const contentGutter = 22.0;
  static const contentMaxWidth = 1040.0;
  static const sidebarWidth = 280.0;
  static const tabletBreakpoint = 720.0;
  static const minimumTouchTarget = 48.0;
}

/// Semantic mobile tokens mapped from the RHM Web design system.
@immutable
class RhmUiTokens extends ThemeExtension<RhmUiTokens> {
  const RhmUiTokens({
    required this.surfaceRaised,
    required this.sidebar,
    required this.accentSoft,
    required this.muted,
    required this.border,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
  });

  final Color surfaceRaised;
  final Color sidebar;
  final Color accentSoft;
  final Color muted;
  final Color border;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  @override
  RhmUiTokens copyWith({
    Color? surfaceRaised,
    Color? sidebar,
    Color? accentSoft,
    Color? muted,
    Color? border,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
  }) =>
      RhmUiTokens(
        surfaceRaised: surfaceRaised ?? this.surfaceRaised,
        sidebar: sidebar ?? this.sidebar,
        accentSoft: accentSoft ?? this.accentSoft,
        muted: muted ?? this.muted,
        border: border ?? this.border,
        success: success ?? this.success,
        warning: warning ?? this.warning,
        danger: danger ?? this.danger,
        info: info ?? this.info,
      );

  @override
  RhmUiTokens lerp(ThemeExtension<RhmUiTokens>? other, double t) {
    if (other is! RhmUiTokens) return this;
    return RhmUiTokens(
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      border: Color.lerp(border, other.border, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

abstract final class RhmTheme {
  static ThemeData get light => _build(
        brightness: Brightness.light,
        background: const Color(0xfff7f8f5),
        surface: const Color(0xffffffff),
        surfaceRaised: const Color(0xfff3f5f1),
        sidebar: const Color(0xfff0f2ee),
        foreground: const Color(0xff202521),
        muted: const Color(0xff667266),
        primary: const Color(0xff345f40),
        onPrimary: const Color(0xffffffff),
        secondary: const Color(0xffe9ece7),
        onSecondary: const Color(0xff2c342e),
        accentSoft: const Color(0xffe9eee8),
        border: const Color(0xffe1e6df),
        danger: const Color(0xffb3423c),
        success: const Color(0xff376d57),
        warning: const Color(0xff9b6a2f),
        info: const Color(0xff426d88),
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        background: const Color(0xff111312),
        surface: const Color(0xff181a19),
        surfaceRaised: const Color(0xff1d201e),
        sidebar: const Color(0xff151716),
        foreground: const Color(0xfff2f4f1),
        muted: const Color(0xff969d97),
        primary: const Color(0xffc3f36b),
        onPrimary: const Color(0xff17200c),
        secondary: const Color(0xff242724),
        onSecondary: const Color(0xffe7eae5),
        accentSoft: const Color(0xff292e2a),
        border: const Color(0xff2a2e2b),
        danger: const Color(0xff8d3936),
        success: const Color(0xff80b993),
        warning: const Color(0xffd7b26a),
        info: const Color(0xff86aeca),
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color surfaceRaised,
    required Color sidebar,
    required Color foreground,
    required Color muted,
    required Color primary,
    required Color onPrimary,
    required Color secondary,
    required Color onSecondary,
    required Color accentSoft,
    required Color border,
    required Color danger,
    required Color success,
    required Color warning,
    required Color info,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
    ).copyWith(
      primary: primary,
      onPrimary: onPrimary,
      secondary: secondary,
      onSecondary: onSecondary,
      surface: surface,
      onSurface: foreground,
      onSurfaceVariant: muted,
      outline: border,
      outlineVariant: border,
      error: danger,
      onError: brightness == Brightness.dark
          ? const Color(0xfffff4f3)
          : const Color(0xffffffff),
      tertiary: info,
    );

    return ThemeData.from(colorScheme: scheme, useMaterial3: true).copyWith(
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      textTheme: TextTheme(
        displayLarge: TextStyle(fontSize: 32, height: 1.2, fontWeight: FontWeight.w700, color: foreground),
        headlineSmall: TextStyle(fontSize: 20, height: 1.3, fontWeight: FontWeight.w700, color: foreground),
        titleLarge: TextStyle(fontSize: 18, height: 1.35, fontWeight: FontWeight.w700, color: foreground),
        titleMedium: TextStyle(fontSize: 16, height: 1.35, fontWeight: FontWeight.w600, color: foreground),
        bodyLarge: TextStyle(fontSize: 15, height: 1.55, color: foreground),
        bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: foreground),
        bodySmall: TextStyle(fontSize: 12, height: 1.45, color: muted),
        labelLarge: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: foreground),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: muted),
      ),
      dividerColor: border,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: foreground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: foreground,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceRaised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: TextStyle(color: muted),
        labelStyle: TextStyle(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RhmDesignTokens.radiusControl),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RhmDesignTokens.radiusControl),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RhmDesignTokens.radiusControl),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RhmDesignTokens.radiusControl),
          borderSide: BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RhmDesignTokens.radiusControl),
          borderSide: BorderSide(color: danger, width: 1.5),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(
            RhmDesignTokens.minimumTouchTarget,
            RhmDesignTokens.minimumTouchTarget,
          ),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: sidebar,
        surfaceTintColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(RhmDesignTokens.minimumTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RhmDesignTokens.radiusControl),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(RhmDesignTokens.minimumTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RhmDesignTokens.radiusControl),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size.fromHeight(RhmDesignTokens.minimumTouchTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RhmDesignTokens.radiusControl),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: accentSoft,
        elevation: 0,
        height: 72,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: background,
        indicatorColor: accentSoft,
        useIndicator: true,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        textColor: foreground,
        minVerticalPadding: RhmDesignTokens.spacing8,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      iconTheme: IconThemeData(color: muted),
      extensions: <ThemeExtension<dynamic>>[
        RhmUiTokens(
          surfaceRaised: surfaceRaised,
          sidebar: sidebar,
          accentSoft: accentSoft,
          muted: muted,
          border: border,
          success: success,
          warning: warning,
          danger: danger,
          info: info,
        ),
      ],
    );
  }
}

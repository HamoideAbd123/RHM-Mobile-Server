import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rhm_mobile/rhm_theme.dart';

void main() {
  test('dark theme matches the approved RHM web palette', () {
    final theme = RhmTheme.dark;
    final tokens = theme.extension<RhmUiTokens>()!;

    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, const Color(0xff111312));
    expect(theme.colorScheme.surface, const Color(0xff181a19));
    expect(theme.colorScheme.primary, const Color(0xffc3f36b));
    expect(theme.colorScheme.onSurface, const Color(0xfff2f4f1));
    expect(tokens.sidebar, const Color(0xff151716));
    expect(tokens.border, const Color(0xff2a2e2b));
    expect(tokens.danger, const Color(0xff8d3936));
  });

  test('light theme matches the approved RHM web palette', () {
    final theme = RhmTheme.light;
    final tokens = theme.extension<RhmUiTokens>()!;

    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, const Color(0xfff7f8f5));
    expect(theme.colorScheme.surface, const Color(0xffffffff));
    expect(theme.colorScheme.primary, const Color(0xff345f40));
    expect(theme.colorScheme.onSurface, const Color(0xff202521));
    expect(tokens.sidebar, const Color(0xfff0f2ee));
    expect(tokens.border, const Color(0xffe1e6df));
    expect(tokens.muted, const Color(0xff667266));
    expect(RhmDesignTokens.minimumTouchTarget, 48);
    expect(RhmDesignTokens.spacing16, 16);
    expect(RhmDesignTokens.radiusCard, 12);
    expect(RhmDesignTokens.tabletBreakpoint, 720);
  });
}

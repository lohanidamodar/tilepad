# Tilepad Design System — Design

**Date:** 2026-06-02
**Status:** Approved direction (autonomous build)
**Branch:** `worktree-design-system`

## Goal

A single, shared, token-based design system for both the **server** (desktop
control panel) and the **client** (mobile/web deck). Clean, consistent, compact,
beautiful, minimal, and **personalizable**. **No hardcoded visual values** in
UI code — everything resolves from tokens.

## Aesthetic direction

**Refined "control-surface" minimalism.** Neutral-forward surfaces with a single
configurable accent; hairline borders; near-flat elevation with soft, sparing
shadows; a tight 4px spatial grid for compactness; crisp typography — a
characterful geometric sans (**Onest**) for UI paired with a mono
(**JetBrains Mono**) for technical readouts (IP addresses, ports, clocks,
key combos). Intentional restraint, not decoration.

Fonts load via `google_fonts` (cached). If unavailable offline on first run, the
system font is used — layout and tokens are unaffected.

## Architecture

```
lib/src/design/
  tokens.dart          Primitive tokens (raw scales): color ramps, space,
                       radius, type sizes/weights, borders, icon sizes,
                       elevation/shadows, motion, opacity, density.
  app_tokens.dart      AppTokens — a ThemeExtension carrying *semantic* tokens
                       resolved per brightness+accent+density. The shared design
                       system surface both apps read via `context.tokens`.
  app_theme.dart       buildAppTheme({brightness, accent, density}) -> ThemeData.
                       Derives ColorScheme + every component theme from tokens.
                       No hardcoded hex.
  app_typography.dart  Token-driven TextTheme + the display/mono families.
  personalization.dart Personalization model + Riverpod Notifier persisted to
                       SharedPreferences (themeMode, accent, density). Shared.
  personalization_panel.dart  Shared UI to pick theme mode / accent / density.
  design.dart          Barrel export.
```

### Token layers

1. **Primitive** (`tokens.dart`) — raw, theme-agnostic scales:
   - **Space:** `space0..space12` on a 4px grid (0,2,4,8,12,16,20,24,32,40,48,64).
   - **Radius:** `radiusXs..radiusXl` (4,8,12,16,20) + `radiusFull`.
   - **Type:** size scale (11,12,13,14,16,18,22,28,34), weights, line-heights,
     tracking.
   - **Border:** `hairline` (1), `strong` (1.5), `focus` (2).
   - **Icon:** 14,16,18,20,24,28.
   - **Elevation/shadow:** `shadowNone/sm/md/lg` (token BoxShadow lists).
   - **Motion:** durations (fast 120, base 200, slow 320) + standard curves.
   - **Opacity:** `disabled`, `muted`, `hover`, `scrim`.
   - **Neutral & accent ramps:** generated from a seed for light/dark.
   - **Density:** comfortable/compact multipliers applied to space + control
     heights.

2. **Semantic** (`AppTokens` ThemeExtension) — resolved per theme:
   - Color roles beyond `ColorScheme`: `surface`, `surfaceSubtle`,
     `surfaceRaised`, `border`, `borderStrong`, `textPrimary`,
     `textSecondary`, `textMuted`, `accent`, `accentSubtle`, plus status
     (`success`, `warning`, `danger`, `info`) each with a subtle variant.
   - Spacing, radii, typography, icon sizes, shadows, motion accessors.
   - `density` factor and derived `controlHeight`, `gap`, `pagePadding`.
   - `lerp` implemented so theme transitions animate.

3. **Access:** `extension TokenContext on BuildContext { AppTokens get tokens }`
   → `context.tokens.space.md`, `context.tokens.color.border`,
   `context.tokens.radius.lg`, `context.tokens.text.title`, etc. Color *roles*
   that already exist in `ColorScheme` are used via `Theme.of(context)
   .colorScheme` to stay idiomatic; app-specific roles come from `AppTokens`.

### Theme builder

`buildAppTheme(brightness, accent, density)` produces a `ThemeData` whose
`ColorScheme` is seeded from the chosen accent and whose component themes
(`appBar`, `card`, `input`, all buttons, `dialog`, `snackBar`, `chip`, `fab`,
`listTile`, `switch`, `divider`, `progressIndicator`, `navigationBar`,
`segmentedButton`, `popupMenu`, `tooltip`) are all derived from tokens. The
`AppTokens` extension is attached so widgets can read semantic tokens.

## Personalization

Persisted (SharedPreferences, shared keys so both apps honor the same choices on
one device):
- **Theme mode** — light / dark / system.
- **Accent** — a curated palette (indigo default, plus blue, teal, emerald,
  amber, rose, violet, slate) selectable; drives the seed.
- **Density** — comfortable / compact.

`PersonalizationNotifier` exposes the current `Personalization` and setters;
`personalizationProvider` is read by both `main.dart`s to build the theme. A
shared `PersonalizationPanel` widget provides the picker (used in client Settings
and a server settings entry).

## Refactor rubric (applied to every UI file)

Replace hardcoded values with tokens — no exceptions in UI code:
- `Color(0x…)` / `Colors.x` (except `Colors.transparent`) → `colorScheme.*` or
  `context.tokens.color.*`.
- numeric `EdgeInsets` / `SizedBox` / `gap` → `context.tokens.space.*`.
- `BorderRadius.circular(n)` → `context.tokens.radius.*`.
- `fontSize:` / inline `TextStyle` sizes/weights → `Theme.of(context)
  .textTheme.*` (or `context.tokens.text.*`), tweaking via `copyWith` only for
  color/weight from tokens.
- border widths → `context.tokens.border.*`; icon sizes → `context.tokens
  .icon.*`; `withValues(alpha:)` magic → token opacities.
- `Duration`/`Curve` literals in animations → `context.tokens.motion.*`.

Button *content* colors chosen by users (the per-button color field) remain
user data, not design tokens — those stay.

The legacy `AppTheme` constants and `lightTheme`/`darkTheme` in
`lib/src/utils/theme.dart` are replaced by the new system; `ThemeModeSelector`
is superseded by `PersonalizationPanel`.

## Testing & verification

- Unit: `AppTokens.lerp` continuity; personalization persistence round-trip;
  `buildAppTheme` produces attached `AppTokens` for both brightnesses; a
  "no raw hex in UICode" guard is impractical as a test, enforced by review.
- Widget: existing boot test stays green; theme builds without exceptions.
- `flutter analyze` clean; `flutter build windows` OK.
- Device: server desktop + mobile client — verify the new look, switch
  theme/accent/density live, confirm consistency across both.

## Build order

1. Spec (this) + token foundation (tokens, typography, AppTokens, theme builder,
   personalization, barrel).
2. Wire client + server `main.dart` to the token theme + personalization; shared
   personalization panel.
3. Refactor client screens/widgets to tokens.
4. Refactor server screens/widgets/dialogs to tokens.
5. Verify (analyze/test/build) + device smoke test + PR.

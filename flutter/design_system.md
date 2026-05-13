# Flutter App Design System

The Flutter app follows the shared token model in `../design-tokens/tokens.json` and exposes platform-native Dart APIs.

## Files

- `lib/core/design_system/app_tokens.dart`: color, type, space, radius, shadow, and compatibility aliases.
- `lib/core/design_system/app_theme.dart`: Material 3 `ThemeData`.
- `lib/core/design_system/widgets/`: Flutter design-system widgets.
- `lib/core/theme/*`: compatibility facades for older imports.

## Components

- `DsButton`: `variant`, `size`, `loading`, `disabled`, `leftIcon`, `rightIcon`.
- `DsTextField`: label, error/success/helper text, readonly/disabled states.
- `DsCard`: repeated content containers.
- `DsBadge`: `real`, `suspicious`, `ad`, `info`, `success`, `warning`, `error`.
- `DsToast`: SnackBar-based feedback.
- `DsDialog`: Material dialog wrapper.
- `DsBottomSheet`: modal bottom-sheet surface with handle.
- `DsAppLogo`: logo + service name lockup.

## Platform Rules

- Keep Material 3 enabled through `AppTheme.light`.
- iOS and Android should keep platform navigation conventions; only visual tokens are shared.
- Bottom sheets are preferred for mobile contextual actions, while web can use dialogs or panels.
- Do not bypass compatibility facades when editing older screens unless the whole file is being migrated.

## Accessibility

- Preserve semantic labels on icon-only buttons.
- Use text labels alongside color-coded trust states.
- Keep primary touch targets at 44px or larger where possible.

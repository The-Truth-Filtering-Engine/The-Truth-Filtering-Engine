# Web Design System

The web app consumes the shared token names as CSS variables.

## Files

- `src/design-system/tokens.css`: CSS variable implementation of shared tokens.
- `src/design-system/components.css`: reusable component classes.
- `src/design-system/index.tsx`: React primitives for new web UI.

## Components

- `DsButton`: `variant`, `size`, `loading`, `disabled`, `leftIcon`, `rightIcon`.
- `DsIconButton`: icon-only action with required accessible label.
- `DsTextField`: label, helper/error/success text, leading icon, readonly/disabled states.
- `DsCard`: repeated content containers.
- `DsBadge`: status and feedback tones.
- `DsToast`: transient feedback.
- `DsDialog`: modal content.

## Usage Rules

- Prefer `var(--color-text-primary)` and component classes over raw hex values.
- Use `--focus-ring`, `--focus-width`, and `--focus-offset` for visible keyboard focus.
- Keep hover styles web-only; mobile behavior should be expressed through pressed/disabled states.
- Do not add one-off colors for review trust states. Use `real`, `suspicious`, and `ad` tones.

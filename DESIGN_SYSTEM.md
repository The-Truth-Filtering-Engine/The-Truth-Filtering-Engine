# Truth Filtering Engine Design System

This repo uses a token-first design system for the web app and the Flutter app.

## Source Of Truth

- Shared tokens live in `design-tokens/tokens.json`.
- Use semantic tokens in product UI: prefer `color.text.brand` over raw values such as `brand500`.
- Component tokens are reserved for their component only, for example `button.primary.bg` and `input.focusBorder`.

## Layers

1. Foundation: color, typography, spacing, radius, shadow, focus, icon rules.
2. Design Token: named values in the shared JSON file.
3. Components: Button, TextField/Input, Badge, Card/List, Toast, Dialog/Bottom Sheet.
4. Patterns: login, search, filtering, review status, settings, recommendation flows.
5. Governance: changes must update tokens, platform implementation, and docs together.

## Accessibility Baseline

- Text contrast should target WCAG 2.2 AA, normally 4.5:1 or better.
- Every interactive control needs a visible focus style and an accessible name.
- Touch/click targets should be at least 36px for compact controls and 44px for primary mobile controls.
- Status should not rely on color alone; pair color with labels such as `진성`, `의심`, `광고`.

## Naming

- Primitive: `primitive.color.brand500`, `primitive.font.weight.bold`.
- Semantic: `color.bg.default`, `color.text.primary`, `color.status.real.bg`.
- Component: `button.primary.bg`, `input.focusBorder`, `toast.shadow`.

## Change Rule

Token values should be changed in one place first. Platform code can alias or expose those values, but should not introduce a conflicting source of truth.

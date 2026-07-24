# Accessibility

Accessibility lives in the views, not in a bolt-on module. What is applied and
why:

- **Headers**: every screen title uses `.accessibilityAddTraits(.isHeader)` so
  VoiceOver users can jump between sections.
- **Combined elements**: composite rows (icon + title + text on the consent
  screen, numbered recommendations on the advice screen) are merged with
  `.accessibilityElement(children: .combine)` — one swipe reads one thought,
  instead of three fragments.
- **Decorative images are hidden**: icons that repeat adjacent text carry
  `.accessibilityHidden(true)`; the capture preview uses `Image(decorative:)`.
- **Live guidance**: the camera quality banner ("Hold the phone still", "Find
  more light") carries the `.updatesFrequently` trait so VoiceOver re-polls the
  changing guidance instead of reading a stale instruction.
- **Meaningful values**: the intake progress bar exposes "2 of 3 questions
  answered" via `accessibilityValue`, not a bare percentage.
- **Hints on consequential actions**: "Agree and continue" and "Revoke
  consent" carry `accessibilityHint` explaining what actually happens.
- **Dynamic Type**: all text uses semantic font styles (`.title2`, `.callout`,
  `.footnote`); no fixed point sizes, so the entire UI scales.
- **No color-only signals**: capture readiness pairs color with an icon and
  text (`checkmark` vs `exclamationmark.triangle` + guidance sentence).

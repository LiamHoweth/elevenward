# Accessibility and visual QA

## Implementation requirements

- Interactive targets are 44–48 px minimum; primary buttons are 52–56 px.
- Every icon-only action has a tooltip and screen-reader label.
- Decorative atmospheric imagery is excluded from accessibility semantics.
- Selection, ownership, failure and success have text/icon indicators in
  addition to color.
- All primary screens use `SafeArea`, slivers or scroll views and remain usable
  at 200% text scale. Horizontal segmented groups are scrollable when needed.
- Reduced-motion users receive zero-duration transitions and no required timed
  animation. The match transition remains tap-to-continue.

## Manual matrix

Run EN, ES, PT-BR and FR in portrait at 320×568, 390×844, 430×932 and a tablet
portrait size. Repeat the narrow-phone pass at 200% text, and repeat motion
flows with reduced motion enabled.

Verify:

- no clipped price, button, title, score or bottom navigation label;
- focus, matchup, spotlight, recap and any career event are reachable;
- VoiceOver/TalkBack reads product name, benefit and state once in a sensible
  order;
- offline Shop never invents a price and provides retry only when configured;
- onboarding, career creation, Life tabs and More destinations remain scrollable;
- image crops retain text contrast on phone and tablet;
- owned/included/disabled product states remain understandable in grayscale.

Physical-device RevenueCat tests remain a release gate because unit/widget tests
cannot validate App Store or Play billing sheets.


# Elevenward interaction patterns

## Navigation and continuity

- The bottom bar always contains Career, World, Life and More in that order.
- Detail destinations use pushed routes with a standard back action; switching
  bottom tabs preserves the current tab state.
- The matchweek CTA remains the last primary action in the Career flow.
- Career switching is explicit and returns to slots. It never deletes or
  silently replaces the active save.

## Selection and feedback

- Selected controls include a check, filled treatment or selected semantic—not
  color alone.
- Search results use full-row radio targets. Career creation keeps selections
  while moving backward and does not write a save until final confirmation.
- Long-running work disables only relevant actions and shows a progress
  indicator in the action region.
- Empty, unavailable and failure states explain whether retrying is useful and
  explicitly say when local career data is unaffected.

## Purchase behavior

- Shop has explicit Loading, Available, Processing, Owned, Included with
  All-Access and Unavailable product states.
- Cancellation, failure and restoration use separate feedback messages.
- Storefront-localized prices are the only prices rendered. Configuration
  reference prices are never used as fallback copy.
- If VIP, 2× Development or 2× Money is already owned, All-Access is disabled
  with a no-proration explanation; unowned focused passes remain purchasable.
- There are no unsolicited offers, countdowns, interstitials or gameplay
  interruptions.

## Match feedback

The recap shows score, rating, trained attribute gain, income and trust. It also
shows retained fractional development and any applied development/money
multiplier before continuing to a career event or the next focus week.


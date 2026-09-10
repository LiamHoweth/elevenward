# Elevenward experience specification

Status: implementation baseline for the portrait iOS and Android client.

## Product promise

Elevenward should feel like a composed night-match broadcast, not a control
panel. Each screen answers one player question first:

- Career: what should I do this matchweek?
- World: where do my league, club and competitions stand?
- Life: what needs attention away from the pitch?
- More: where are the less frequent destinations?

The primary Career viewport keeps identity, OVR, fitness, form, trust,
season/week, opponent and the next action visible before secondary detail.
Purchases are player-initiated only and never interrupt simulation, onboarding,
match transitions, events or recaps.

## Core journeys

1. First launch: choose a language, learn offline play and the weekly loop in
   three concise pages, then enter career slots.
2. New career: identity/archetype, searchable nationality/club, then difficulty
   and a complete review before committing the save.
3. Matchweek: choose focus and load, view the matchup, make one spotlight
   decision, then read a compact result/development/income recap.
4. Life: use Overview for national-team and agent decisions, Market for
   available items, and Collection for owned/equipped items.
5. Shop: enter from career slots or More, compare four permanent passes, buy or
   restore explicitly, and return without losing place.
6. World: lead with the player’s league and pinned club row, then open each
   competition into a dedicated, scroll-safe fixture and bracket view.
7. Player-requested transfer: open Player from More, search for a league,
   optionally nominate a club, review the one-time eight-point manager-trust
   consequence, and file the request for the next offseason. The offseason
   offer view keeps the target visible and permits editing before a decision.

## Information architecture

More is a navigation hub rather than a second player dashboard. Its destinations
are grouped as Career (Player, Legacy), Personalization (Appearance), Online
(Account, Shop, Leaderboards), and App (Settings, Switch Career). Player,
Legacy, Appearance, Settings, and Account are separate routes that update while
open. Leaderboards remain one shared surface. Boost evidence is submission
metadata, not a separate board or a public player label.

Player is read-only except for transfer-request actions. Transfer requests use
football terminology, can target the current or another league, and never move
the player during the season. Legacy separates the active projection from the
retired verdict. Appearance applies unlocked choices immediately and rolls back
failed persistence. Settings contains language, analytics/privacy, offline data,
and versions only. Account owns identity, cloud status/conflicts, sign-out, and
confirmed deletion while retaining visible local-career safety messaging.

## Review and change workflow

1. Design: state the player question, primary action, hierarchy and failure
   states before code.
2. Review: check purchase pressure, safe-area behavior, localization expansion,
   semantics and 200% text before implementation.
3. Implement: use theme tokens, `BroadcastPanel`, code-native marks and explicit
   state labels. Atmospheric images are decorative only.
4. QA: run automated analysis/tests, then the device and storefront matrix in
   `ACCESSIBILITY_QA.md`. Record any accepted exception with an owner and date.

# Changelog

All notable changes to AsylumAlerts are recorded here. New work should first be
listed under **Unreleased**, then moved into a numbered section when a version is
prepared for testing or release.

## Unreleased

- No changes yet.

## 0.5.0 - 2026-10-18

- Promoted the Forever potion and buff-tracking work to a stable feature release.
- Removed Retail from the accepted interface metadata so distributors classify
  this package as Forever-only.
- Added default-on potion cooldown tracking with localized names, icons, and ready
  alerts while excluding healing, health, rejuvenation, and Swiftness potions.
- Kept potion-effect expiry separate from the actual potion cooldown reminder.
- Corrected Retail ownership and expiry handling for self buffs, passive procs,
  external buffs, and aura scans interrupted by hearthstone or portal transitions.
- Recognized **Well Fed** as a self-applied consumable on Forever without weakening
  its stricter external-buff ownership checks.

## 0.4.27 - 2026-10-18

- Prevented Retail hearthstone, portal, and loading transitions from falsely
  announcing that still-active auras such as Power Word: Fortitude expired.
- Left Forever's existing early aura-removal detection unchanged.

## 0.4.26 - 2026-10-18

- Prevented passive Retail proc buffs from producing personal **recast it** spam.
  Their duration bars remain visible, while player-initiated maintenance buffs
  retain expiry reminders.

## 0.4.25 - 2026-10-18

- Suppressed personal-buff recast warnings when a tracked potion's temporary
  effect expires; its separate cooldown bar and ready alert continue normally.

## 0.4.24 - 2026-10-18

- Added Retail (`120100`) to the accepted client interface versions so the add-on
  can be loaded for compatibility testing alongside Forever.
- Trusted Retail's player-source aura metadata so self-applied food and item buffs
  are not categorized as buffs from other players, without changing Forever's
  stricter ownership fallback.
- Recognized the exact **Well Fed** aura as a self-applied consumable on Forever,
  while retaining strict ownership checks for other player-cast buffs.
- Added default-on potion cooldown tracking for Forever and compatible Retail
  clients, using the consumed potion's localized name and icon.
- Excluded healing, health, rejuvenation, and Swiftness potions from cooldown
  tracking, and consolidated shared potion cooldowns into one bar and ready alert.

## 0.4.23 - 2026-10-15

- Added a saved **Show minimap button** toggle to `/aa`, enabled by default.
- Applied minimap-button visibility changes immediately without requiring `/reload`.

## 0.4.22 - 2026-10-15

- Removed the final inherited project-name reference from AsylumAlerts documentation.

## 0.4.21 - 2026-10-15

- Added a saved **Print alerts in chat** toggle to `/aa`, disabled by default.
- Mirrored each ready or expiry alert once to the player's local chat window when
  enabled, without sending messages to party, raid, guild, or public channels.
- Allowed chat alerts to remain enabled independently of the center-screen visual
  announcement toggle.

## 0.4.20 - 2026-10-15

- Added a compact minimap emblem derived from the Asylum logo, preserving the red
  moon, gothic castle silhouette, metallic rim, and red diamond ornaments while
  removing text and tiny details for readability at minimap size.
- Added a draggable minimap button with saved positioning.
- Added left-click to open settings and right-click to lock or unlock bar and alert
  positioning.

## 0.4.19 - 2026-10-15

- Preserved the saved seconds component of a Firestone or Spellstone expiration
  across `/reload` while Forever is displaying a rounded whole-minute value.
- Kept whole-minute values authoritative when they materially disagree with the
  earlier whole-hour estimate, and kept later second-precision values authoritative.

## 0.4.18 - 2026-10-15

- Parsed the seconds portion of compound Firestone and Spellstone durations, such
  as `2 min 40 sec`, and used it to correct the persisted expiration.
- Accepted seconds-only duration lines for Firestone and Spellstone while rejecting
  unrelated short proc lines, preventing approximately 40 seconds of reload drift.

## 0.4.17 - 2026-10-15

- Made the exact weapon-slot millisecond timer authoritative for the matching oil
  or API-backed poison.
- Kept an oil or poison bar active when its tooltip line disappears shortly before
  expiry, preventing an early expiry alert.
- Kept Firestone and Spellstone isolated from the oil/poison timer-matching path.
- Corrected all AsylumAlerts author credits to **Freddykr**.

## 0.4.16 - 2026-10-15

- Allowed precise minute tooltip values such as `90 min` to correct an earlier
  rounded Firestone or Spellstone estimate.
- Persisted the corrected expiration through `/reload` and relogging.

## 0.4.15 - 2026-10-15

- Persisted estimated Firestone and Spellstone expirations using server time so a
  rounded `2 hours` tooltip no longer restarts the timer after every `/reload`.
- Added `/aa resync` to establish a fresh stone timer after applying a new stone.

## 0.4.14 - 2026-10-15

- Preferred a matching player aura's exact expiration for Firestone and
  Spellstone when that aura information is available.
- Matched ranked and unranked stone names, including `Firestone 1` and
  `Firestone (Rank 1)`.

## 0.4.13 - 2026-10-15

- Set stable full-duration bar scales: 30 minutes for oils and two hours for
  Firestone and Spellstone.
- Selected the shorter live timer when duplicate stone-related tooltip lines were
  present.
- Corrected bar fill after reload so remaining time is not mistaken for the full
  duration.

## 0.4.12 - 2026-10-15

- Added compound duration parsing for values such as `1 hr 52 min`.
- Prevented a stacked stone from borrowing an oil's shorter timer when its own
  tooltip duration was available.

## 0.4.11 - 2026-10-15

- Made the weapon-effect name cache aware of stacked effects on Forever.
- Restored Firestone and Spellstone tracking alongside oils and other temporary
  weapon effects.
- Recognized stone tooltip lines that omit a conventional parenthesized timer.

## 0.4.10 - 2026-10-15

- Preserved the last known oil or weapon-enchant name when detailed tooltip text
  disappears near expiry.
- Prevented the named entry from being replaced by a generic main-hand or
  off-hand entry and producing a duplicate early warning.

## 0.4.9 - 2026-10-15

- Displayed active trinket proc buffs as duration bars.
- Kept trinket proc expiration silent while retaining the ready alert for the
  actual item cooldown.

## 0.4.8 - 2026-10-15

- Forced bar icons onto a high overlay layer so status-bar fill cannot hide them
  after `/reload`.

## 0.4.7 and earlier - Initial development

- Added movable, lockable duration bars and a separately movable alert message.
- Added tracking for personal buffs, external buffs, flasks, weapon oils and
  stones, trinket cooldowns, trinket proc buffs, and Soulstone cooldowns.
- Added configurable alert font, size, colour, duration, and optional sounds.
- Added the `/aa` configuration window and slash commands.
- Added external-buff visibility control and player-cast ownership filtering.
- Added actual equipped trinket names and ready announcements.
- Added icon resolution fallbacks, maintenance-bar ordering, and normalized
  Firestone/Spellstone rank labels.
- Prevented trinket proc expiration from producing personal-buff recast warnings.

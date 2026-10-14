# PersonaCard

A portrait card for one Naija bot, shown in a horizontal carousel on the Play screen and in the bot picker.

## Anatomy

- 148px wide, `surface`, `radius-md`, `shadow-1`, clipped.
- Stage: 148px square in the stage colour for the bot's band: `stage-mint` up to 1000, `stage-sand` 1200 to 1600, `stage-clay` 1800 to 2200, `stage-indigo` 2400 and up. The portrait multiplies onto the stage so its white backdrop takes the stage colour (Flutter: `colorBlendMode: BlendMode.multiply` with the stage colour).
- Rating chip, bottom-left of the stage: `forest` pill, `on-forest` 13px bold tabular, with grouping ("1,400").
- Body padding `space-3`: name (`title-sm`), hometown with a 14px `location_on` (`body-sm`, `ink-2`), catchphrase in curly quotes (`body-sm`, `ink-3`, two lines max).

## States

- Plus bot for a free player: the Plus badge top-right and a lock in the rating chip. The portrait stays in full colour; tapping opens the Plus sheet, not a snackbar.
- Low-data mode: no portrait download; the bot's initials in 34px bold `forest` on the stage.
- Bots above the phone's memory limit are hidden, with one line under the carousel saying so.

## Content

Name, hometown, rating, catchphrase and tier come from `/config` (`bots[]`). Copy them as written; do not add emoji.

Flutter: `PersonaCard({required Map bot, required bool locked, required bool lowData, VoidCallback? onTap})`. Carousel: `ListView` horizontal, height 290, `space-3` gaps, gutter `space-4` at both ends.

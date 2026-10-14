# Hamduk Chess mobile app

Flutter app for Android and iOS; backend is the Hamduk Chess platform API (see README.md).

## Before any UI work

Read `DESIGN.md` and follow it. For a screen, open its mockup in `design/mockups/`, its section in `design/screens.md`, and the guideline for each component it uses in `design/components/`. Build with the tokens (`context.hc`, `HcColors`, `HcText`, `HcSpace`, `HcRadius`, `HcSize`) and the shared widgets in `lib/core/hc_widgets.dart`. No raw colours, font sizes or paddings in feature code.

## Checks before you finish

- `flutter analyze` and `flutter test` pass (CI runs both; infos fail the build).
- The screen matches its mockup in dark and light, at 1.3× text size, on a 360dp-wide phone.

## Other rules

- No GPL or AGPL packages (README, "Licences").
- `lib/core/tokens.dart` is generated from `design/tokens.json` by `python3 design/tools/tokens_to_dart.py`; never edit it by hand.

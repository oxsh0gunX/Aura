# Aura ⚡

A Raiden-themed, fully offline Android workout tracker, built with Flutter.
No login, no account, no internet needed. Your data lives only on your phone.

## What it does

- **Categories and workouts, all created by you** — nothing is preloaded.
  Each workout has a name and a unit (reps, seconds, kg, or time).
- **One count per workout per day.** Saving a day replaces that day's number
  for the workouts you enter; skipped workouts keep their old values.
- **Graphs** — a main graph across all categories, plus a graph inside each
  category. X is the logged day (Day 1, 2, 3…), Y is the total count that day.
  Chart styles: Snake, Line, Bars, Area.
- **Body-map Muscle Focus on Home** — a body figure that lights up green
  for the parts you trained and stays faint for the parts you haven't.
  Categories map to body parts by name (neck, chest, shoulders, arms, core,
  legs, full-body, and more).
- **AI coach, two ways** — a fully offline coach that compares your days,
  points out weaknesses, and can roast you (roast mode on/off), plus a
  Gemini chatbot when you add your own API key in Settings.
- **Full customisation** — theme presets, background/text/accent colours,
  background image (built-in gradients or your own gallery photo), opacity
  sliders, and animation/roast switches.
- **Animated splash** — a short animated picture on cold start, then Home.
- **Category icons** — 41 bundled icons, picked when you create a category,
  with an "Auto" option that picks by keyword.

## Install

Grab the APK from the
[Releases](https://github.com/oxsh0gunX/Aura/releases) page and install it
on your Android phone. Install new versions **over** the old one — do not
uninstall first, or your workout data will be lost.

## Data

Workouts and logs are stored on the phone in `aura.json` (via the
`aura/files` method channel). Nothing is uploaded anywhere. Leaving the
Coach page clears the chat, but your workout data is untouched.

## Building (manual, no Gradle)

This project is built with a manual no-Gradle route, because the usual
Gradle build is blocked in some environments (Java networking). The script
in `scripts/` shows the exact steps:

1. `flutter assemble` the AOT snapshot per ABI.
2. Package with `aapt2`, `d8`, `zipalign`, and `apksigner`.
3. The Android side is hand-maintained: `manual/AndroidManifest.xml`,
   `manual/res/` (dark launch background, styles), and
   `android/app/src/main/java/com/example/aura/MainActivity.java`
   (plain `FlutterActivity` + the `aura/files` method channel).

You need a Flutter SDK, JDK 17, and Android SDK build-tools 34. The script
references a local `debug.keystore` — that file is intentionally **not**
in this repo; use your own debug keystore to sign your builds.

Note: the picture assets (category icons, splash animation, launcher
icon) are binary files and are not part of this code snapshot; they are
attached to the Releases alongside the APK.

## Version

v9.17 — Coach now uses the `gemini-3.8-flash` model (Google retired
`gemini-2.0-flash`), and Gemini errors are shown plainly with the
offline coach reply underneath instead of a cryptic crash message.
Also fixes a double full stop at the end of error lines.

v9.15 — the first version with the animated-picture splash (earlier
native-video splash attempts did not play on the test phone, so the
video player was replaced with a Flutter-native animated image).

## AI coach note

The Gemini chatbot needs your own API key in Settings. A Google AI Plus
subscription covers the Gemini app, not Gemini API billing — API calls are
billed through a separate Cloud project. On a free-tier Cloud project the
API can return HTTP 403, in which case the app shows the error plainly and
the fully offline coach still answers underneath.

## GitHub achievements

See [ACHIEVEMENTS.md](ACHIEVEMENTS.md) for the badge hunt on this profile.

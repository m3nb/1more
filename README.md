# 1More

A push-your-luck number card game for 2–8 players. Play the computer, pass one device around, or open an online room and send friends the link.

## Get the builds

Every push to `main` builds the app on GitHub Actions. Open the **Actions** tab, pick the latest run, and download:

- **1More-android**: the `.apk` to install on an Android phone
- **1More-windows**: unzip and run `one_more.exe`
- **1More-macos**: the Mac app (unsigned: right-click, Open)

The web version is published to GitHub Pages, at `https://<your-username>.github.io/1more/`. Invite links point there, so friends can join from a phone browser without installing anything.

iPhone builds are compiled to check the code, but installing on a real iPhone or publishing to the App Store needs an Apple Developer account.

## Online play

Rooms use Supabase Realtime. The project URL and its publishable (public) key are in `lib/config.dart`.

## Run it on your own computer

Install Flutter, then from this folder:

```
bash tool/prepare.sh
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

## Code map

- `lib/engine/`: the rules as a pure-Dart state machine, plus the computer players. Covered by `test/engine_test.dart`.
- `lib/net/`: rooms. The host's device runs the engine and broadcasts the state; other devices send their moves.
- `lib/ui/`: screens.

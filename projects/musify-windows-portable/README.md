# Musify Windows Portable

A portable Windows x64 port of [gokadzev/Musify](https://github.com/gokadzev/Musify).

The GitHub Actions workflow downloads the current upstream source, generates the Flutter Windows runner, applies the Windows compatibility layer, builds the application, bundles the Microsoft Visual C++ runtime, and publishes both binary and corresponding patched-source ZIP files.

## Portable behaviour

- No installer.
- Application, downloads, settings, cache, playlists and Hive databases stay under `portable-data` beside `Musify.exe`.
- Windows audio playback uses `just_audio_media_kit` and the audio-only MediaKit Windows libraries.
- Windows System Media Transport Controls are supplied by `audio_service_win`.
- Android-only equalizer, sharing-intent and system-UI calls are disabled on Windows.
- The complete Release directory and Visual C++ runtime DLLs are shipped together.

Extract the binary ZIP to a writable directory and launch `START-MUSIFY.cmd` or `Musify.exe`.

## Build

Run the **Musify Windows Portable** workflow from GitHub Actions. It also runs automatically when the port files change.

The workflow publishes:

- `Musify-Windows-Portable-v<version>-x64.zip`
- `Musify-Windows-Portable-v<version>-source.zip`
- `SHA256SUMS.txt`

## Licensing

Musify is GPL-3.0-or-later. Modified source is distributed with every binary release. The Windows compatibility packages retain their own licenses. This project does not host music and does not change upstream service or copyright responsibilities.

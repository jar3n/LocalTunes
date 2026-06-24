# LocalTunes

A bare-bones local music player for jailbroken iOS (built for iPod touch 5G,
iOS 6–9.3, armv7). It doesn't touch the iOS Music library at all — you copy
music files in with **Filza**, and LocalTunes just plays whatever's in that
folder.

## How it works

- On first launch, LocalTunes creates `/var/mobile/Media/LocalTunes/`.
- Open Filza, navigate there, and copy/move any `.mp3`, `.m4a`, `.wav`,
  `.aac`, `.aiff`, or `.caf` files into it.
- Open LocalTunes and tap the refresh (circular arrow) button top-right to
  rescan. Songs are read directly from file metadata (ID3/iTunes tags), so
  titles/artists show up automatically if the files have tags — otherwise it
  just uses the filename.
- Tap a song to play it. Tap the mini-player bar at the bottom to open the
  full Now Playing screen with a scrub bar and prev/play/next.
- Playback continues with the screen locked, and lock-screen / Control
  Center transport controls work (iOS 7.1+).
- The "Folder" button (top-left) always shows you the exact path to drop
  files into, in case your jailbreak's sandbox forces it to fall back to the
  app's own container instead.

This is intentionally simple — no playlists, no queue editing, no
shuffle/repeat. Treat it as a starting point; the code is small enough to
extend easily (see `Sources/`).

## Project layout

```
LocalTunes/
├── Makefile                 # Theos build config (armv7 + arm64, iOS 6.0+)
├── control                  # Cydia package metadata
├── Sources/                 # Objective-C source
└── Resources/
    ├── Info.plist
    ├── Icon.png / Icon@2x.png
```

## Building

You don't need a Mac. Push to `main` (or run the workflow manually from the
**Actions** tab) and GitHub Actions builds the `.deb` for you on a macOS
runner, then attaches it as a downloadable artifact named `LocalTunes-deb`.

Why a macOS runner and not Linux, if Theos can cross-compile on Linux too?
Apple's modern Xcode/SDKs dropped armv7 support entirely, so either way you
need an old SDK. The workflow pulls a community-maintained
[`iPhoneOS10.3.sdk`](https://github.com/theos/sdks) into Theos's `sdks/`
folder before building, which supports both armv7 and arm64 (needed for
iPod Touch 6th gen and newer devices).

### Building locally instead (optional)

If you'd rather build on your own Mac or Linux machine:

```bash
git clone --recursive https://github.com/theos/theos.git ~/theos
export THEOS=~/theos
git clone --depth 1 https://github.com/theos/sdks.git /tmp/sdks
cp -R /tmp/sdks/iPhoneOS10.3.sdk $THEOS/sdks/

git clone <this repo>
cd LocalTunes
make package FINALPACKAGE=1
```

The resulting `.deb` will be in `packages/`.

## Installing on your iPod

Pick whichever is easiest:

- **As a Cydia source** (recommended — see below): add the repo URL once,
  install from inside Cydia, get update notifications automatically.
- **Filza**: download the `.deb` to your iPod (e.g. AirDrop, a download
  link, or `scp`), then tap it in Filza and choose **Install**.
- **SSH**: `scp` the `.deb` to the device, then `dpkg -i LocalTunes.deb`
  over SSH, followed by `killall SpringBoard` (or just respring from
  Cydia/your tweak manager).

### Adding this repo as a Cydia source

Every push to `main` builds the `.deb` *and* publishes a tiny Cydia/APT
repo (`Packages`, `Packages.bz2`, `Release`, the `.deb` itself) to GitHub
Pages via the `deploy` job in the workflow.

One-time setup after you push this repo to GitHub:

1. Go to your repo's **Settings → Pages**.
2. Under "Build and deployment", set **Source** to **GitHub Actions**.
3. Push a commit (or re-run the workflow from the **Actions** tab) so the
   `deploy` job runs. Once it finishes, your repo will be live at:
   `https://<your-username>.github.io/<repo-name>/`

Then on your iPod:

1. Open **Cydia → Sources → Edit → Add**.
2. Enter `https://<your-username>.github.io/<repo-name>/` (with the
   trailing slash).
3. Pull to refresh, find **LocalTunes** under your new source, and install
   it like any other Cydia package.

If your iPod's system clock is way off (common after a device has sat
unused for a while), HTTPS requests can fail TLS validation — set the date
correctly in Settings first if Cydia can't reach the source.

To ship an update later: bump `Version` in `control` and
`Resources/Info.plist`, push, and Cydia will offer the update next time it
refreshes that source.

## Customizing

- Bundle ID / package name: change `com.yourname.localtunes` in `control`
  and `Resources/Info.plist`.
- Supported file types: edit the `supportedExtensions` set in
  `Sources/MusicLibrary.m`.
- Music folder location: edit `resolveMusicDirectory` in
  `Sources/MusicLibrary.m`.

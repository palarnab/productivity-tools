# 5 — Usage Guide

> Companion documents in this folder: [`0-problem-statement.md`](0-problem-statement.md)
> (overview), [`1-architecture.md`](1-architecture.md) (architecture), `2-*.md`
> (internals/components), [`3-roadmap.md`](3-roadmap.md) (limitations & next steps), and
> [`4-features.md`](4-features.md) (full feature list). See also
> [`../README.md`](../README.md), [`../plan.md`](../plan.md), and
> [`../scripts/README.md`](../scripts/README.md).

A practical, copy-paste guide to installing, building, and using the Screen Recorder.

## Download

**[Download ScreenRecorder-Setup-0.2.0.exe](https://github.com/palarnab/quick-sys-management/releases/download/SR-0.2/ScreenRecorder-Setup-0.2.0.exe)** — the latest Windows installer.

---

## Prerequisites

| Requirement | Needed for | Notes |
|---|---|---|
| **Windows 10 (1903+) or 11** | Running the app | WGC window capture needs 1903+; otherwise `gdigrab` fallback |
| **FFmpeg** (`ffmpeg.exe` + `ffprobe.exe`) | Recording & stitching | A **full / GPL** build (e.g. gyan.dev "full" or BtbN GPL) is recommended for `ddagrab`, NVENC/QSV/AMF, `dshow`, `gdigrab` |
| **.NET 10 SDK** | *Building from source only* | Not required to run a packaged/self-contained build |
| Inno Setup 6 | *Building the installer only* | `build-installer.ps1 -InstallInno` can install it via winget |

### Where to put FFmpeg
The app looks for FFmpeg in this order (`Services/FfmpegLocator.cs`):

1. `ScreenRecorder.exe`'s folder — `ffmpeg.exe` / `ffprobe.exe`
2. an `ffmpeg\` subfolder next to the exe
3. an `ffmpeg\bin\` subfolder
4. a `tools\ffmpeg\` subfolder
5. finally, whatever is on your **PATH**

Packaged builds bundle FFmpeg under `ffmpeg\` automatically, so this only matters for a
plain `dotnet build` run (see below). Simplest manual placement:

```text
...\net10.0-windows10.0.19041.0\
  ScreenRecorder.exe
  ffmpeg\
    ffmpeg.exe
    ffprobe.exe
```

If FFmpeg is missing, the app still starts but shows **"FFmpeg not found"** and recording is
disabled until you add it and re-detect encoders from Settings.

---

## Building from source

From the repo root (`Project - Recording`):

```powershell
dotnet build -c Release
```

Run the built app:

```powershell
.\src\ScreenRecorder\bin\Release\net10.0-windows10.0.19041.0\ScreenRecorder.exe
```

On first launch it probes encoders (a few seconds) and caches the result to
`%AppData%\ScreenRecorder\settings.json`. The app appears in the **system tray** —
**right-click** it for all actions.

> A plain `dotnet build` does **not** bundle FFmpeg. Either place `ffmpeg.exe`/`ffprobe.exe`
> next to the built exe (or in an `ffmpeg\` subfolder), or have them on your PATH.

### Optional: headless self-test
Verify capture + audio + stitching end to end without touching the UI:

```powershell
# Record 6s of full screen with system audio, 2s segments, then stitch and report:
.\ScreenRecorder.exe --selftest --audio=system --seconds=6 --seg=2

# Capture a window (matched by title substring), no audio:
.\ScreenRecorder.exe --selftest --source=window --window="Chrome" --audio=none
```

Flags: `--audio=system|mic|both|none`, `--seconds=N`, `--seg=N`, `--out=<folder>`,
`--source=fullscreen|window`, `--window=<title substring>`. Results print to the console and to
`selftest.log` in the output folder.

---

## Packaging (shippable, no .NET runtime on target)

### Portable zip

```powershell
# Uses ffmpeg/ffprobe from PATH if present, otherwise downloads them:
./scripts/build-bundle.ps1
# -> dist/ScreenRecorder-<version>-win-x64.zip
```

Useful options:

```powershell
# Bundle a specific FFmpeg build you already have:
./scripts/build-bundle.ps1 -FfmpegDir 'C:\ffmpeg\bin'

# Always download FFmpeg (ignore PATH):
./scripts/build-bundle.ps1 -ForceDownloadFfmpeg

# Different RID / config, or skip zipping:
./scripts/build-bundle.ps1 -Runtime win-arm64 -Configuration Release -SkipZip
```

The staged bundle (`dist/ScreenRecorder/`) contains:

```text
ScreenRecorder.exe        # single self-contained exe (embeds the .NET runtime)
ffmpeg/ffmpeg.exe
ffmpeg/ffprobe.exe
README.txt
```

### Windows installer (Setup.exe)

```powershell
# Builds dist/ScreenRecorder-Setup-<version>.exe (installs Inno Setup via winget if needed):
./scripts/build-installer.ps1 -InstallInno
```

The installer adds Start Menu + optional Desktop shortcuts, an uninstaller (Add/Remove Programs),
and an optional run-at-login entry. It is **per-user by default** (no admin/UAC); users may elevate
to install for all users.

### Installing via Setup.exe
Double-click `ScreenRecorder-Setup-<version>.exe` and follow the wizard. During setup you can opt
into a **desktop shortcut** and **"Start automatically when I sign in"**.

### Silent install / uninstall (deployment)

```powershell
# Silent install:
ScreenRecorder-Setup-<version>.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART

# Silent uninstall (run the app's uninstaller from its install folder):
"%LOCALAPPDATA%\Programs\Screen Recorder\unins000.exe" /VERYSILENT
```

> The exact uninstaller path depends on where you installed (per-user `%LOCALAPPDATA%\Programs\…`
> vs. an elevated all-users Program Files location).

---

## Day-to-day usage

The app lives in the tray. **Right-click** the icon for the full menu; **double-click** toggles
start/stop.

### Start / stop recording
- **Right-click → Start recording → (pick a source)**, or
- **Double-click** the tray icon (records the full screen), or
- Press **`Ctrl+Alt+R`**.
- Stop the same way (`Ctrl+Alt+R`, double-click, or **Stop** in the menu). The tray icon turns
  **red** while recording.

### Choosing / switching the source
- **Start recording → Full screen** (choose a display if you have several),
  **Select region…**, or **Window ▸** (pick from the list).
- While recording, the top entry becomes **Switch source** — pick a new full screen / region /
  window and it continues the **same session** (a sub-second pause happens at the switch).

### Region selection
Choose **Select region…**; the screen dims. **Drag** a rectangle (a live `W x H` label shows the
size), release to confirm, or press **Esc** to cancel.

### Audio toggles
**Right-click → Audio → None / System sound / Microphone / System + Mic.** System audio uses WASAPI
loopback (no driver needed). If a chosen source can't initialize, recording continues without audio.

### Pause / resume
Press **`Ctrl+Alt+P`** or use the menu. (Pausing finalizes the current segment and resuming starts
a new one; the stitched output is still seamless.)

### Screenshots
Press **`Ctrl+Alt+S`** or **Take screenshot**. The PNG matches the current capture area exactly.
During a session it lands in the session's `screenshots/`; otherwise under
`<OutputFolder>\screenshots\`.

### Stitching (combine segments into one video)
- **Right-click → Stitch → Current / last session** to stitch what you just recorded.
- **Stitch → Choose session folder…** to stitch any session folder (must contain a `segments`
  subfolder).
- If past sessions were never stitched (e.g. a shutdown at session end), an **Unstitched sessions**
  submenu appears with **Stitch all** and per-session entries. On startup the app also notifies you
  if any unstitched sessions exist.
- Enable **Settings → "Automatically stitch when recording stops"** to stitch on every stop.

Stitching is lossless (`concat -c copy`, no re-encode) and runs in the background; you'll get a
balloon tip when it completes.

---

## Hotkeys

| Hotkey | Action |
|---|---|
| `Ctrl+Alt+R` | Start / stop recording (full screen) |
| `Ctrl+Alt+P` | Pause / resume |
| `Ctrl+Alt+S` | Screenshot |

---

## Where recordings are saved

Default output folder: `%USERPROFILE%\Videos\ScreenRecorder` (configurable in Settings). Each
session is a timestamped folder:

```text
<OutputFolder>\<yyyy-MM-dd_HH-mm-ss>\
  segments\      seg_00001.mkv, seg_00002.mkv, ...   (≈1 min each)
  screenshots\   shot_00001.png, ...
  manifest.json                                       (fps, codec, encoder, canvas, source switches)
  session_full.mp4                                    (created when you stitch)
```

Because each minute becomes a finished file the instant the next begins, an abrupt shutdown costs
at most the final partial minute — and you can stitch later. Open the folder any time via
**Right-click → Open recordings folder**.

---

## Settings explained

Open **Right-click → Settings…**. Stored at `%AppData%\ScreenRecorder\settings.json`.

| Setting | What it does | Default |
|---|---|---|
| **Output folder** | Where sessions are written | `%USERPROFILE%\Videos\ScreenRecorder` |
| **Codec** | H264 / HEVC / AV1 family (actual encoder chosen by probe) | H264 |
| **Frame rate** | 30 or 60 fps CFR (locked while recording; 30 halves capture/encode work) | 60 |
| **Quality** | 0 (best) – 51 (worst); maps to CRF/CQ/QP per encoder | 20 |
| **Segment length** | Seconds per segment (10–600) | 60 |
| **Prefer hardware encoder** | Steer the probe toward NVENC/QuickSync/AMF | On |
| **Auto-stitch on stop** | Stitch immediately when recording stops | Off |
| **Start with Windows** | Per-user run-at-login (`HKCU\...\Run`) | Off |
| **Re-detect encoders** | Re-run capability probing (after adding FFmpeg or changing hardware) | — |

Recording options (codec/fps/segment) apply to the **next** session; they're locked while a
session is active.

---

## Troubleshooting

### "FFmpeg not found"
- Place `ffmpeg.exe` + `ffprobe.exe` next to `ScreenRecorder.exe` (or in an `ffmpeg\` subfolder),
  or add them to your PATH. Then **Settings → Re-detect encoders**. Verify manually:

```powershell
.\ffmpeg\ffmpeg.exe -hide_banner -version
```

### No hardware encoder (falls back to software)
- This is expected behavior, not an error — the probe test-encodes each candidate and uses the
  first that works (`libx264`/software always works). Common causes: no compatible GPU, an old
  driver, or a laptop Optimus/driver quirk (NVENC can fail even with an NVIDIA GPU).
- Check the selected encoder in **Right-click → About** (or the tray tooltip). Update GPU drivers,
  ensure a **full/GPL** FFmpeg build (so `*_nvenc`/`*_qsv`/`*_amf` exist), then **Re-detect
  encoders**. Software encoding is higher CPU but produces the same-quality output.

### No system audio in the recording
- Make sure **Audio** is set to **System** or **System + Mic** (default is **None**).
- WASAPI loopback follows the **default playback device** — set the right output as default and
  ensure sound is actually playing.
- For **mic**, grant microphone permission (Windows Settings → Privacy → Microphone) and set a
  **Mic device hint** if you have multiple mics. Confirm with the self-test:

```powershell
.\ScreenRecorder.exe --selftest --audio=both --seconds=6
```

The log reports whether an audio track exists and its measured loudness (silent / quiet / audible).

### WGC unavailable (window capture)
- Windows Graphics Capture needs Windows 10 1903+ (and a working D3D11 device). On older builds,
  some VMs, or RDP it's unsupported and the app automatically uses **`gdigrab`** for windows
  (higher CPU, and possible black frames on GPU-composited windows). Check **About** — it reports
  the capture path.

### Black window capture
- This happens on the `gdigrab` fallback for hardware-accelerated / DirectComposition windows
  (GPU-composited apps like some browsers/games). Options:
  - Prefer a machine/OS where **WGC** is available (it captures these correctly), or
  - Record **Full screen** or a **Region** over the window instead of window mode.

### Recording seems to lag the recorded app
- FFmpeg already runs at **BelowNormal** priority. Reduce load by lowering **fps to 30**, using a
  hardware encoder, capturing a **region** instead of 4K full-screen, or raising the **Quality**
  number (lower bitrate).

### A session didn't stitch (app/PC closed at the end)
- On next launch you'll be notified of unstitched sessions. Use **Stitch → Unstitched sessions →
  Stitch all** (or pick one). The stitcher validates and **repairs a truncated final segment**
  automatically, so you rarely lose more than the last partial minute.

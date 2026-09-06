# Audio Recorder — Usability & Usage Guide

> A task-oriented walkthrough of every screen, control, and workflow.
> For build/packaging instructions see [`5-usage-guide.md`](5-usage-guide.md); for the internals
> behind each feature see [`4-features.md`](4-features.md).

## Download

**[Download AudioRecorder-Setup-0.1.0.exe](https://github.com/palarnab/productivity-tools/releases/download/AR-0.1/AudioRecorder-Setup-0.1.0.exe)** — the latest Windows installer.

---

## Table of contents

1. [First run](#1-first-run)
2. [The record window](#2-the-record-window)
3. [The system tray](#3-the-system-tray)
4. [Recording workflows](#4-recording-workflows)
5. [Reviewing a recording](#5-reviewing-a-recording)
6. [Exporting for publishing](#6-exporting-for-publishing)
7. [The recordings browser](#7-the-recordings-browser)
8. [Stitching](#8-stitching)
9. [Settings reference](#9-settings-reference)
10. [Hotkeys](#10-hotkeys)
11. [Files on disk](#11-files-on-disk)
12. [Notifications you may see](#12-notifications-you-may-see)
13. [Troubleshooting](#13-troubleshooting)
14. [Command line](#14-command-line)
15. [Recipes](#15-recipes)

---

## 1. First run

Launch `AudioRecorder.exe`. Two things happen:

- The **record window** ("Audio Recorder") opens.
- A **tray icon** appears in the notification area (a microphone glyph, blue while idle).

In the background the app probes FFmpeg for the `aac` and `libmp3lame` encoders and the `loudnorm`
filter. The result is cached in `%AppData%\AudioRecorder\settings.json`, so this only happens once.

**Settings opens maximized the very first time** so the full layout is visible; after that the app
remembers the size you left it at.

### If FFmpeg is missing

You will see the balloon **"FFmpeg not found — Place ffmpeg.exe next to the app or on PATH, then
re-detect in Settings."** The app still runs, but **recording, stitching, and export are disabled**.

Fix it by putting `ffmpeg.exe` and `ffprobe.exe` in any of these locations (searched in order):

| # | Location |
|---|---|
| 1 | Next to `AudioRecorder.exe` |
| 2 | `ffmpeg\` beside the exe |
| 3 | `ffmpeg\bin\` beside the exe |
| 4 | `tools\ffmpeg\` beside the exe |
| 5 | Anywhere on `PATH` |

Then open **Settings → Advanced → Re-detect audio encoders**. Installer and portable-zip builds
bundle FFmpeg, so this only affects a plain `dotnet build`.

### Single instance

Only one copy runs at a time. Launching a second shows **"Audio Recorder is already running (check
the system tray)."** — the existing instance is in the tray.

---

## 2. The record window

Opens on launch, from the tray (**Open Audio Recorder**), or by double-clicking the tray icon.
Closing it does **not** quit the app — it keeps running in the tray. Use **Quit** in the tray menu to
exit.

```text
┌────────────────────────────────────────────────┐
│  Audio Recorder                Idle   00:00:00 │  ← header: title · status · elapsed
├────────────────────────────────────────────────┤
│  Sources                             [Refresh] │
│   ☑ System sound        [▁▃▅▇▅▃▁      ]        │
│       Speakers (Realtek)                       │
│   ☑ Microphone (USB)    [▁▃▁          ]        │
│       Microphone                               │
│   ☐ Headset Mic         [              ]       │
├────────────────────────────────────────────────┤
│  Layout  [ Mixed (one file)              ▾ ]   │
│                                                │
│   [ ●  Record ]  [ ❚❚  Pause ]  [ ■  Stop ]    │
├────────────────────────────────────────────────┤
│  [Recordings…]  [Settings…]                    │
│  Tip: use Ctrl + Alt + R to start/stop …       │
└────────────────────────────────────────────────┘
```

### Header

| Element | Values |
|---|---|
| Status | `Idle` · `● Recording` · `Paused` |
| Elapsed | `mm:ss` under an hour, `H:mm:ss` beyond |

### Sources card

One row per capture endpoint:

- **System sound** — WASAPI loopback. The subtext shows the current **default playback device**,
  because loopback always follows it. No "Stereo Mix" driver is required.
- **Each microphone** — listed by its Windows friendly name, subtext `Microphone`.

Tick every source you want in the recording. If no devices are found the card shows
**"No audio devices found."** — plug the device in and press **Refresh**.

### Live meters

Each row has a peak meter with attack/decay smoothing and a peak-hold tick.

| App state | Meter source |
|---|---|
| Idle | A lightweight preview tap on the ticked sources (no encoding) |
| Recording | The real capture graph, tapped **before** mixing, so each level is that source alone |
| Paused | Frozen |

**Always watch the meters before pressing Record.** A flat meter means that source is silent — the
single most common cause of an unusable recording. Aim for peaks in the upper half without pinning
the top.

### Layout

| Option | Result |
|---|---|
| **Mixed (one file)** | All ticked sources summed into a single track named `mix` |
| **Multitrack (file per source)** | One file per source (`system`, `<mic-name>`, …) |

Choose **Multitrack** when you plan to edit — you can then duck the system audio under narration,
fix one speaker, or drop a source entirely. Choose **Mixed** for a quick capture you will publish
as-is.

### Transport

| Button | Enabled when | Label |
|---|---|---|
| Record | Idle | `●  Record` |
| Pause | Recording / Paused | `❚❚  Pause` → `▶  Resume` |
| Stop | Recording / Paused | `■  Stop` |

**Locked while a session is active:** the Record button, the Layout dropdown, and the source
checkboxes. Layout, bitrate and segment length always apply to the **next** session.

### Footer

- **Recordings…** — opens the browser (section 7).
- **Settings…** — opens Settings as a modal dialog.
- The hint line reminds you of the global start/stop hotkey.

---

## 3. The system tray

The tray icon is always available, even with every window closed. Its tooltip reads
**"Audio Recorder (idle | recording | paused)"** and the glyph is colour-coded:

| Colour | State |
|---|---|
| Blue | Idle |
| Red (with glow) | Recording |
| Amber | Paused |

**Double-click** opens the record window. **Right-click** opens the menu:

| Item | Notes |
|---|---|
| *Status line* | Non-clickable. `Idle`, `● Recording — System + 1 mic(s) · Mixed`, or `❚❚ Paused` |
| **Open Audio Recorder** | Shows/restores the record window |
| **Start recording** / **Pause** / **Resume** | Changes with state; shows `Ctrl + Alt + R` / `Ctrl + Alt + P` |
| **Stop** | Only while recording or paused |
| **Stitch ▸** | `Current / last session`, `Choose session folder…`, `Unstitched sessions (N)` |
| **Recordings…** | Opens the browser |
| **Open recordings folder** | Explorer at your output folder |
| **Start with Windows** | Checkable; same per-user run-at-login toggle as Settings → Advanced |
| **Settings…** | Opens Settings |
| **About** | Version, detected encoders, output folder, hotkeys |
| **Quit** | Exits the app |

You can drive an entire recording from the tray without ever opening a window.

---

## 4. Recording workflows

### Standard flow

1. Open the record window and **tick your sources**.
2. Confirm the **meters** move when you speak / play audio.
3. Choose a **Layout**.
4. Press **Record** (or `Ctrl+Alt+R` from any app).
5. Use **Pause** (`Ctrl+Alt+P`) for breaks — the elapsed timer holds and segment numbering continues.
6. Press **Stop**. With **auto-stitch on stop** enabled (the default) the tracks are combined
   immediately in the background.

While recording you can close every window; the tray icon stays red and the hotkeys keep working.

### What "crash-safe" means for you

Capture is written as ~60-second AAC-in-MKV segments. **Each segment becomes a finished, playable
file the instant the next one starts.** If Windows reboots or the app is killed mid-session, you lose
at most the final partial segment — everything before it is intact and can be stitched later.

### Recording a call or an interview

Tick **System sound** (the far end) plus **your microphone**, and set Layout to **Multitrack**. You
then get separate files for each side, which makes levelling and editing far easier. Recording both
sides of a conversation may require consent — check the rules for your jurisdiction.

### Recording several microphones

Tick as many mics as you like. In **Multitrack** each mic gets its own folder and file; duplicate
device names are automatically disambiguated. Sources that fail to initialise are dropped and logged
rather than aborting the session — check the meters if a track is missing.

---

## 5. Reviewing a recording

Open **Recordings…**, select a session and click **▶ Play / Review** (or double-click the row). If
the session has not been stitched you are asked **"This recording hasn't been stitched yet. Stitch it
now?"** — answer **Yes** and it becomes playable.

The player window is titled **"Player — {session}"** and shows:

| Control | Behaviour |
|---|---|
| **Track** dropdown | Lists stitched tracks; `mix` shows as *Mixed*, `system` as *System sound* |
| **Waveform** | Mirrored peak bars with a playhead. **Click or drag anywhere to seek.** |
| `▶ Play` / `❚❚ Pause` | Toggles playback |
| `■ Stop` | Stops and rewinds |
| Time readout | `elapsed / total` — `mm:ss`, or `HH:mm:ss` past an hour |
| **Vol** slider | 0–100, defaults to 90 |
| **Export…** | Opens the export dialog for the currently selected track |

The waveform is decoded in the background, so it may fill in a moment after the window opens on a
long recording. If a file cannot be opened you get a **"Cannot open track"** message with the
underlying error.

---

## 6. Exporting for publishing

From the player, click **Export…**:

| Field | Options |
|---|---|
| **Format** | `M4A (AAC)` · `MP3` · `WAV (PCM)` |
| **Loudness normalization** | `Off` · `YouTube (-14 LUFS)` · `Podcast (-16 LUFS)` |

Both default to your Settings values. Press **Export**, then choose a destination — the suggested
name is `{session}_{track}.{ext}` (e.g. `2025-01-15_10-30-45_mix.m4a`) and the dialog starts in the
session folder.

### Choosing a format

| Format | Use it for | Note |
|---|---|---|
| **M4A** | Uploading, sharing, archiving | With loudness **Off** this is a **stream copy** — instant and lossless |
| **MP3** | Maximum compatibility | Needs `libmp3lame`; greyed out on FFmpeg builds without it |
| **WAV** | Handing off to an editor / DAW | Always available; large files |

### Choosing a loudness target

Normalization applies EBU R128 (`loudnorm`, true peak -1.5 dBTP, LRA 11):

- **YouTube (-14 LUFS)** — matches YouTube/Spotify playback loudness.
- **Podcast (-16 LUFS)** — the common spoken-word target for podcast platforms.
- **Off** — leave levels untouched (and keep the fast M4A stream copy).

You will see **"Exported to: {path}"** on success or **"Export failed: {reason}"** on error.

---

## 7. The recordings browser

Titled **"Recordings"**. The header summarises the library: *"{N} recording(s) · {size} total"*, or
**"No recordings yet"**.

### Columns

| Column | Content |
|---|---|
| **Date** | `yyyy-MM-dd HH:mm:ss` from the manifest (falls back to the folder name) |
| **Duration** | `mm:ss` / `HH:mm:ss`, or `—` if unknown |
| **Tracks** | Number of tracks in the session |
| **Size** | Total on-disk size |
| **Status** | Badge — see below |

Click a header to sort; click again to reverse. A ▲/▼ indicator marks the active column. The default
sort is newest first.

### Status badges

| Badge | Meaning |
|---|---|
| **Stitched** (green) | Combined files exist; raw segments still present |
| **Stitched · cleaned** (blue) | Combined files exist; raw segments deleted (space reclaimed) |
| **Not stitched** (amber) | Segments only — stitch before playing or exporting |
| **Empty** (grey) | No audio found in the folder |

### Actions

Available as buttons and on the right-click menu. Multi-select is supported for the bulk actions.

| Action | Enabled when | Effect |
|---|---|---|
| **▶ Play / Review** | Exactly one **stitched** row | Opens the player |
| **Stitch** | Selection has segments | Combines segments losslessly |
| **Open folder** | Exactly one row | Opens the session folder in Explorer |
| **Clean segments** | Selection has segments | Deletes raw `.mkv` segments, keeps stitched audio |
| **Delete** | Any selection | Permanently deletes the sessions and all files |
| **Refresh** | Always | Rescans the output folder |

Both destructive actions confirm first:

- *"Delete the raw segment files for {N} recording(s)? This frees space and keeps the stitched
  audio."* — with an extra warning if any selected session is **not** stitched, because its audio
  would be lost.
- *"Permanently delete {N} recording(s) and all their files?"*

Results appear in the status line at the bottom: *"Stitched 3/3 session(s)."*, *"Freed 1.4 GB."*,
*"Deleted 2/2 recording(s)."*

> **Housekeeping tip:** once you have exported what you need, **Clean segments** typically halves the
> space a session occupies while leaving it fully playable.

---

## 8. Stitching

Stitching concatenates each track's segments into a single `<track>.m4a` using `concat -c copy` —
**no re-encoding, no quality loss**, and fast even on long sessions.

Four ways to trigger it:

1. **Automatically on stop** — Settings → Export → *Automatically stitch tracks when recording
   stops* (on by default).
2. **Tray → Stitch → Current / last session**.
3. **Tray → Stitch → Choose session folder…** — point at any session folder, including one copied
   from another machine.
4. **Recordings → Stitch** — works on a multi-row selection.

### Crash recovery

At startup the app scans for sessions that have segments but no stitched output and notifies you:
**"{N} recording(s) not yet stitched — Right-click the tray → Stitch."** Use **Stitch → Unstitched
sessions (N)** to fix them all in one go. A final segment that was truncated by an abrupt shutdown is
repaired automatically; if it is unrecoverable it is skipped so the rest of the recording still
stitches.

Stitching runs in the background and reports **"Stitch complete"** or **"Stitch failed"**.

---

## 9. Settings reference

Open from the tray or the record window. Stored as JSON at
`%AppData%\AudioRecorder\settings.json`. Five groups in the left sidebar; **Save** applies, **Cancel**
discards.

### General

| Setting | Description | Default |
|---|---|---|
| **Save recordings to** | Root folder; each session gets a timestamped subfolder | `%USERPROFILE%\Music\AudioRecorder` |
| **Theme** | Light or Dark — applies to windows opened afterwards | Light |

### Recording

| Setting | Description | Default |
|---|---|---|
| **Track layout** | Mixed (one file) or Multitrack (file per source) | Mixed |
| **Recording bitrate (kbit/s)** | AAC bitrate of the crash-safe segments — 128 / 160 / 192 / 256 / 320 | 192 |
| **Segment length (seconds)** | 10–600. Shorter = less possible loss on a crash, more files | 60 |

All three take effect on the **next** session.

### Export & publishing

| Setting | Description | Default |
|---|---|---|
| **Default export format** | Pre-selected in the export dialog | M4A (AAC) |
| **Loudness normalization** | Pre-selected loudness target | Off |
| **Automatically stitch tracks when recording stops** | Combine segments as soon as you press Stop | On |

### Hotkeys

Every shortcut is `Ctrl + Alt` plus a key you pick. The list is deliberately restricted to keys that
do not clash with common Windows shortcuts:

`R` · `S` · `P` · `G` · `T` · `B` · `M` · `F7` · `F8` · `F9` · `F10` · `F11` · `F12`

| Setting | Default |
|---|---|
| **Start / stop recording** | `R` |
| **Pause / resume** | `P` |

Changes apply immediately.

### Advanced

| Setting | Description |
|---|---|
| **Start with Windows (run at login)** | Per-user `HKCU\...\Run` entry — no admin rights needed |
| **Re-detect audio encoders** | Re-probes FFmpeg. Run this after installing or replacing FFmpeg |

### About

**Tray → About** confirms what the app actually detected — useful when something is greyed out:

| Row | Values |
|---|---|
| FFmpeg | `available` / `not found` |
| AAC encoder | `yes` / `no` |
| MP3 encoder | `yes (libmp3lame)` / `no` |
| Loudness (loudnorm) | `yes` / `no` |
| Output folder | Full path |
| Hotkeys | Your current bindings |

---

## 10. Hotkeys

Global — they work from any application, including full-screen games and calls.

| Hotkey | Action |
|---|---|
| `Ctrl + Alt + R` | Start / stop recording |
| `Ctrl + Alt + P` | Pause / resume |

If another program has already claimed a combination, Audio Recorder silently skips registering it.
If a hotkey seems dead, pick a different key in **Settings → Hotkeys** (for example `F9` / `F10`).

---

## 11. Files on disk

```text
<OutputFolder>\2025-01-15_10-30-45\
  manifest.json
  tracks\
    mix\                       (Mixed layout)
      segments\
        seg_00001.mkv
        seg_00002.mkv
      mix.m4a                  (created by stitching)
```

Multitrack replaces `mix\` with one folder per source (`system\`, `microphone-usb\`, …), each with
its own `segments\` folder and stitched `.m4a`.

`manifest.json` records `StartedUtc`, `StoppedUtc`, `Layout`, `SampleRate` (48000), `BitrateKbps`,
the `Tracks` list and the human-readable `Sources` list — this is what the browser reads for the date
and duration columns.

Other locations:

| Path | Contents |
|---|---|
| `%AppData%\AudioRecorder\settings.json` | All settings and cached capability probe results |
| `<app folder>\logs\yyyy-MM-dd.log` | Daily rotating diagnostic log — attach this to bug reports |

Session folders are self-contained: copy one to another machine and **Stitch → Choose session
folder…** will process it.

---

## 12. Notifications you may see

| Balloon | Meaning |
|---|---|
| **FFmpeg not found** | Add FFmpeg, then Settings → Re-detect audio encoders |
| **{N} recording(s) not yet stitched** | Crash recovery available — Tray → Stitch |
| **Cannot record** — *FFmpeg is not available.* | Recording is blocked until FFmpeg is present |
| **Choose a source** | Nothing was ticked — select System sound and/or a mic |
| **Recording started** — *System + 1 mic(s) · Mixed* | Confirms exactly what is being captured |
| **Recording failed** — *No source could be initialized.* | Devices were unavailable; check the log |
| **Paused** / **Resumed** | Transport confirmation |
| **Recording stopped** — *Saved to {folder}* | Where the session landed |
| **Stitching…** / **Stitch complete** / **Stitch failed** | Background stitching progress |
| **Detection complete** — *AAC ready.* / *AAC unavailable.* | Result of re-detecting encoders |

Dialogs from the record window:

- *"FFmpeg is not available. Place ffmpeg.exe next to the app or on PATH, then re-detect in
  Settings."*
- *"Select at least one source (System sound or a microphone)."*
- *"Could not start recording (no source could be initialized)."*

---

## 13. Troubleshooting

### The Record button does nothing / says FFmpeg is unavailable
FFmpeg was not found. Place `ffmpeg.exe` + `ffprobe.exe` in one of the locations in section 1, then
**Settings → Advanced → Re-detect audio encoders**. Verify in **About** that FFmpeg reads
*available*.

### No system audio in the recording
- Confirm **System sound** is ticked and its meter moves while audio is playing.
- Loopback follows the **default playback device**. If you switch outputs (headphones ↔ speakers)
  *mid-session*, the capture stays on the device that was default at start — stop, switch, restart.
- Exclusive-mode apps (some pro audio tools) can block loopback; close them.

### A microphone shows no level
- Tick the mic in the Sources card.
- Grant access: **Windows Settings → Privacy & security → Microphone** — enable *Let desktop apps
  access your microphone*.
- Check the device is not muted and its Windows input level is not at 0.
- Confirm the device is visible at all: `AudioRecorder.exe --devices`.
- Prove capture end to end: `AudioRecorder.exe --selftest --audio=mic --seconds=6`.

### MP3 export is greyed out
Your FFmpeg build has no `libmp3lame`. Install a **GPL / "full"** build (BtbN GPL or gyan.dev full),
re-detect encoders, or export **M4A** / **WAV**, which are always available.

### Loudness normalization is unavailable
Same cause — the `loudnorm` filter is missing from your FFmpeg build. Check **About**.

### The session shows "Not stitched"
The app closed before stitching finished, or auto-stitch is off. Select the row and press **Stitch**,
or use **Tray → Stitch → Unstitched sessions**. Truncated final segments are repaired automatically.

### Recording stopped early / files stop mid-session
Check the log at `<app folder>\logs\<date>.log`. The most common causes are a device being unplugged
and the output drive filling up.

### The app disappeared
It is in the tray, not on the taskbar — closing the record window only hides it. Double-click the
tray icon, or use **Open Audio Recorder**.

### Recordings take too much space
Use **Clean segments** in the browser after exporting, lower the **Recording bitrate**, or record a
single **Mixed** track instead of multitrack.

### Levels are too quiet or clipping
Adjust the device level in Windows before recording — the meters reflect it live. For material that
is already recorded, use **Loudness normalization** on export instead of re-recording.

---

## 14. Command line

| Command | Purpose |
|---|---|
| `AudioRecorder.exe` | Normal launch (record window + tray) |
| `AudioRecorder.exe --devices` | Print the default playback device and every detected microphone with its id, then exit |
| `AudioRecorder.exe --selftest [options]` | Headless end-to-end capture + stitch + loudness check |

Self-test options: `--audio=system|mic|both|none`, `--layout=mixed|multitrack`, `--seconds=N`,
`--seg=N`, `--out=<folder>`.

```powershell
# 6 seconds of system audio, 2-second segments
.\AudioRecorder.exe --selftest --audio=system --seconds=6 --seg=2

# system + default mic as separate tracks
.\AudioRecorder.exe --selftest --audio=both --layout=multitrack --seconds=6
```

It records, stops, counts the segments per track, stitches, and measures each track's loudness,
classifying it as *silent*, *quiet*, or *clearly audible*. Results print to the console and to
`selftest.log` in the output folder — the fastest way to prove whether a device is actually
producing audio.

---

## 15. Recipes

### Screen-recording narration (voice over app audio)
Sources: **System sound** + your mic · Layout: **Multitrack** · Export: **M4A**, **YouTube
(-14 LUFS)**. Separate tracks let you duck the app audio under your voice in the editor.

### Podcast episode, solo
Sources: your mic only · Layout: **Mixed** · Export: **MP3** or **M4A**, **Podcast (-16 LUFS)**.
Consider a 30-second test recording and a listen-back before the real take.

### Meeting or interview capture
Sources: **System sound** + your mic · Layout: **Multitrack** · Auto-stitch **on**. Start with
`Ctrl+Alt+R` before the call connects and leave every window closed.

### Long unattended session
Keep **Segment length** at 60 s (or lower it to 30 s), enable **Start with Windows**, and rely on
crash-safe segments. If the machine reboots, stitch the leftovers from the tray on next launch.

### Capturing a music stream at best quality
Sources: **System sound** only · **Recording bitrate 320** · Export **WAV** if it is going into an
editor, otherwise **M4A** with loudness **Off** for a lossless stream copy.

# 5 — Usage Guide

A practical, end-to-end guide: prerequisites, building/running, packaging/installing, the full
authoring workflow, the on-disk project layout, markup syntax, and troubleshooting.

See also [`4-features.md`](4-features.md) for what each feature does, [`3-roadmap.md`](3-roadmap.md)
for current limitations, and [`plan.md`](../plan.md) / [`README.md`](../README.md) for design and
status. Product/architecture background lives in the companion docs
[`0-problem-statement.md`](0-problem-statement.md), [`1-architecture.md`](1-architecture.md), and
[`2-technology-choices.md`](2-technology-choices.md).

## Download

**[Download PresentationNarrator-Setup-0.3.0.exe](https://github.com/palarnab/productivity-tools/releases/download/PN-0.3/PresentationNarrator-Setup-0.3.0.exe)** — the latest Windows installer.

---

## 1. Prerequisites

| Requirement | Needed for | Notes |
|-------------|-----------|-------|
| **Windows 10 / 11 (x64)** | Everything | The app is WinForms + DPAPI + (optional) COM. |
| **FFmpeg — full/GPL build with libass** | All export + subtitles | `ffmpeg.exe` + `ffprobe.exe` next to the app (in an `ffmpeg/` subfolder) or on `PATH`. **libass is mandatory** for subtitle burn-in. |
| **.NET 10 SDK** | Building from source | Not needed for the packaged/self-contained build. |
| **Microsoft PowerPoint** *(optional)* | Highest-fidelity PPTX slides | If absent, LibreOffice or the built-in GDI renderer is used. |
| **LibreOffice** *(optional)* | PPTX fidelity without Office | Detected at `…\LibreOffice\program\soffice.exe`. |
| **WebView2 runtime** *(optional)* | HTML import | Preinstalled on most Windows 10/11; required only for `.html` decks. |
| **OpenAI, ElevenLabs, and/or Amazon Polly credentials** *(optional)* | Cloud voices + alignment | Cloud is optional — the app works fully offline with the Windows voice. |

Resolution order for FFmpeg is defined in `Services/FfmpegLocator.cs`: app-local `ffmpeg.exe`,
`ffmpeg/ffmpeg.exe`, `ffmpeg/bin/ffmpeg.exe`, `tools/ffmpeg/ffmpeg.exe`, then `PATH`.

---

## 2. Building and running from source

```powershell
# From the repo root (Project - Presentation):
dotnet build -c Release

# Run the built app:
.\src\PresentationNarrator\bin\Release\net10.0-windows\PresentationNarrator.exe
```

For a debug run (used by the self-test example below), the exe is under
`.\src\PresentationNarrator\bin\Debug\net10.0-windows\`.

> Make sure `ffmpeg.exe` + `ffprobe.exe` (a GPL build with libass) are on `PATH` or copied next to
> the exe, or the status bar will show *"FFmpeg not found"* and export will fail.

---

## 3. Packaging and installing

The packaging scripts live in `scripts/` (see [`scripts/README.md`](../scripts/README.md)). They
produce a **self-contained** build: the .NET runtime and the native pdfium are embedded, and FFmpeg
is bundled — nothing needs to be installed on the target.

### Portable ZIP

```powershell
# Publishes a single-file self-contained exe + bundles FFmpeg + zips into dist/.
# FFmpeg source order: -FfmpegDir  ->  ffmpeg on PATH  ->  download (BtbN GPL "latest").
./scripts/build-bundle.ps1
# -> dist/PresentationNarrator-<version>-win-x64.zip
```

Useful options:

```powershell
./scripts/build-bundle.ps1 -FfmpegDir 'C:\ffmpeg\bin'    # bundle a specific FFmpeg
./scripts/build-bundle.ps1 -ForceDownloadFfmpeg -SkipZip # always download; leave staged
```

### Windows installer (Inno Setup)

```powershell
# Builds Setup.exe (Start Menu + optional Desktop shortcut, uninstaller in Add/Remove Programs).
# -InstallInno installs the Inno Setup compiler via winget if it is missing.
./scripts/build-installer.ps1 -InstallInno
# -> dist/PresentationNarrator-Setup-<version>.exe
```

The installer (`installer/PresentationNarrator.iss`) is **per-user by default** (no admin/UAC),
creates a Start Menu group and optional desktop shortcut, and registers an uninstaller. Run the
resulting `PresentationNarrator-Setup-<version>.exe` to install; uninstall from **Settings →
Apps** or the Start Menu **Uninstall** entry.

> **libass reminder:** the default download (BtbN GPL) includes libass and the hardware encoders. If
> you supply your own FFmpeg via `-FfmpegDir`, it **must** be a full/GPL build with libass.

---

## 4. Step-by-step authoring workflow

### 4.1 New project

**File → New project…** and choose a folder — that folder *becomes* the `.pnproj` (it will contain
`project.json` + `assets/`). The path is remembered as the last project and reopened next launch.

### 4.2 Import your source

| Menu | Source | Result |
|------|--------|--------|
| **File → Import PowerPoint…** | `.pptx` | Slides with titles + notes; narrative **prefilled from notes**; images rendered by the best renderer. |
| **File → Import PDF…** | `.pdf` | One slide per page (pdfium raster); narrative starts empty. |
| **File → Import HTML…** | `.html` / `.htm` | reveal.js → one slide per deck slide; otherwise a single captured page. Requires WebView2. |

### 4.3 Edit the narrative

Select a slide in the left navigator; the right pane shows the **Narrative** editor (prefilled from
notes for PPTX). Edit freely — this is the text that gets **spoken and captioned**. Editing clears
that slide's audio cache so it re-synthesizes next preview/export.

Use the markup:

- **Emphasis:** wrap words in asterisks — `*this* is emphasized`.
- **Pronunciation:** managed globally in Settings (see 4.5) as `term = alias` lines.

### 4.4 Set voice / provider / articulation (global)

**Tools → Settings…** opens the global settings dialog:

- **Voice:** pick a provider (`LocalSapi` offline / `OpenAi` / `ElevenLabs` / `AmazonPolly`). The
  dialog shows **only the fields the chosen provider needs** — an API key for OpenAI/ElevenLabs, or
  AWS access key ID + secret + region + engine (neural/standard/generative/long-form) for Amazon
  Polly. Choose a voice, then click **Test provider** to validate the key/engine. Amazon Polly
  returns word-level timings (speech marks) for accurately-synced subtitles.
- **Articulation:** style (Documentary/Neutral/Energetic/Calm), rate multiplier, leading/trailing
  silence.
- These are **global defaults** every slide inherits.

### 4.5 Per-slide overrides

With a slide selected, click **Slide overrides…** (or use the inline lead/trail-silence toggles).
Override provider/voice, articulation (rate/pitch/style), and subtitle style **for that slide only**;
leave a field on "Inherit (global)" / unchecked to inherit. Applying an override invalidates that
slide's cached audio.

### 4.6 Preview narration

Click **▶ Preview narration**. The app synthesizes the current slide (respecting overrides and the
cache) and plays it back via NAudio, reporting duration and the number of subtitle cues. The center
preview shows a **live subtitle overlay** matching the exported style.

### 4.7 Insert a video

**Insert → Insert video…** (or the timeline **Insert video…** button) copies a clip into
`assets/video/` and inserts it after the selected timeline item. Use the timeline strip to
**reorder / remove** items. At export the clip is normalized to the project canvas so it stitches in
seamlessly.

### 4.8 Settings: subtitles, transitions, music, pronunciation

Still in **Tools → Settings…**:

- **Subtitles:** enable, font, size, background opacity %, bottom margin.
- **Pronunciation:** one `term = spoken-as` per line (e.g. `kubernetes = koo ber net eez`). The
  audio uses the alias; captions show the real term.
- **Transitions & music:** crossfade duration in ms (`0` = hard cuts), a background-music file,
  music volume (dB), and **Duck music under narration**.
- **Export:** frame rate and quality (0 best … 40).

### 4.9 Export

**Tools → Export video…**. If the project uses a **cloud** provider and has slides needing
(re)synthesis, a **confirmation dialog** first shows the provider, slide/character counts, an
**approximate cost**, and a **key-validation** result — you must confirm before any paid work
happens. Choose an output `.mp4`; a progress bar tracks the run, and you can open the finished video.

---

## 5. The `.pnproj` layout, caching, and autosave

A project is a self-contained folder:

```
<project>.pnproj/
  project.json          # schema-versioned project state (settings + ordered timeline + cache metadata)
  assets/
    source/             # the imported .pptx/.pdf/.html (copied in)
    slides/             # rendered slide images (PNG)
    video/              # inserted clips (copied in)
    cache/              # rendered narration audio, reused on re-export
    music/              # background-music file (if added)
```

- **Portable.** Assets are referenced by **relative paths**, so a `.pnproj` folder can be moved or
  copied and still opens. API keys are **not** stored here (see below).
- **Caching / fast re-export.** Each slide's audio is keyed by a hash of provider + voice + text +
  articulation (`Tts/TtsProviderFactory.CacheKey`). On re-export, unchanged slides reuse their
  cached audio, so only edited slides re-render (and cloud cost only counts stale slides). Editing
  the narrative or applying overrides clears that slide's cache.
- **Atomic saves + autosave.** Saves write `project.json.tmp` then atomically replace, so a crash
  mid-save can't corrupt the project. The editor **autosaves every 30 s** when there are unsaved
  changes and **on close**, and **reopens the last project** on startup.
- **Keys are separate.** OpenAI/ElevenLabs keys and Amazon Polly credentials (access key ID +
  secret) live in `%AppData%/PresentationNarrator/settings.json`, **DPAPI-encrypted per Windows
  user** — never in the project file. The Polly region and engine are stored there too (not secret).

---

## 6. Markup syntax reference

### Emphasis

```text
Welcome to the *Presentation* Narrator.
```

The asterisks are stripped from captions and mapped to emphasis in speech (SSML `<emphasis>` for the
offline SAPI voice; a natural-emphasis instruction for cloud voices).

### Pronunciation (Settings → Pronunciation)

```text
kubernetes = koo ber net eez
PostgreSQL = post gres cue el
Narrator = nar ay tor
```

Each line is `term = spoken-as`. The **audio** uses the alias (whole-word, case-insensitive), while
**captions restore the original term** so viewers read the real word.

---

## 7. Command reference

```powershell
# Build (Release) and run:
dotnet build -c Release
.\src\PresentationNarrator\bin\Release\net10.0-windows\PresentationNarrator.exe

# Package a portable zip:
./scripts/build-bundle.ps1

# Build the Windows installer (installs Inno Setup if needed):
./scripts/build-installer.ps1 -InstallInno

# Download FFmpeg into a folder (used by the bundle script, or standalone):
./scripts/fetch-ffmpeg.ps1 -OutDir C:\tmp\ffmpeg
```

### Headless self-test

Builds a 3-slide project with an inserted video, narrates it offline (SAPI), burns synced
subtitles, exercises pitch/pronunciation/crossfades/ducked-music, exports, and writes a transcript
to `selftest.log`:

```powershell
.\src\PresentationNarrator\bin\Debug\net10.0-windows\PresentationNarrator.exe --selftest --out=C:\tmp\pntest
```

Variations:

```powershell
# Import and narrate a real PDF instead of the canned slides:
.\PresentationNarrator.exe --selftest --pdf=C:\decks\demo.pdf --out=C:\tmp\pntest

# Exercise the HTML import path (WebView2):
.\PresentationNarrator.exe --selftest --html=C:\decks\slides.html --out=C:\tmp\pntest
```

After a run, inspect `C:\tmp\pntest\selftest.log` and the exported `output.mp4`.

---

## 8. Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| **Subtitles don't appear / export fails on the subtitle step** | FFmpeg build lacks **libass** (the `ass=` filter fails) | Use a full/GPL FFmpeg build with libass (the bundled BtbN GPL build has it). Verify with `ffmpeg -filters` containing `ass`. |
| **"FFmpeg not found" in the status bar** | `ffmpeg.exe`/`ffprobe.exe` not next to the app or on `PATH` | Copy them into an `ffmpeg/` folder beside the exe, or add to `PATH`. |
| **HTML import fails** | **WebView2 runtime** missing | Install the Microsoft Edge WebView2 Runtime, then retry. |
| **Non-reveal.js HTML imports as one big slide** | Segmentation currently relies on the reveal.js convention | Expected today; use reveal.js or import as PDF/PPTX (see [`3-roadmap.md`](3-roadmap.md) B2). |
| **Cloud narration sounds like the offline voice** | Invalid/empty API key → automatic **offline fallback** | Re-check the key in Settings → **Test provider**; the export confirm dialog also reports key status. |
| **PPTX slides look plain/generic** | Neither PowerPoint COM nor LibreOffice was available → **GDI fallback** | Install PowerPoint (best fidelity) or LibreOffice; the status bar shows `PowerPoint yes/no`. |
| **Cloud export costs a surprise** | Many stale cloud slides | The pre-export dialog shows character/cost estimate; only changed slides are (re)billed thanks to caching. |
| **Subtitles unreadable on light slides** | *(Fixed)* Text used to blend into bright backgrounds | Resolved: captions render on an **opacity-controlled black box** (`Subtitles/AssWriter.cs`, `BorderStyle=3`). Increase background opacity in Settings if needed. |
| **Inserted video audio too loud/quiet vs. narration** | No automatic loudness matching yet | Adjust the clip's volume (dB); see [`3-roadmap.md`](3-roadmap.md) C3. |

---

### Quick recap

1. **New project** → 2. **Import** (PPTX/PDF/HTML) → 3. **edit narrative** → 4. **set voice +
articulation** (global) and **per-slide overrides** → 5. **Preview** → 6. **Insert video** →
7. **Settings** (subtitles/transitions/music/pronunciation) → 8. **Export** (confirm the cloud
cost/validation dialog if using cloud voices).

The offline path (Windows voice + built-in renderer + subtitles + export) needs **only FFmpeg with
libass** — everything else is optional fidelity/quality upgrades.

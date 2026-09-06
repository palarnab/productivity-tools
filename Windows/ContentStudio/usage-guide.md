# 5 — Usage Guide

> A quick tour of the editor. See [`4-features.md`](4-features.md) for what each feature does.

## Download

**[Download VideoEditor-Setup-0.1.0.exe](https://github.com/palarnab/productivity-tools/releases/download/CS-0.1/VideoEditor-Setup-0.1.0.exe)** — the latest Windows installer.

---

## First launch
On first run the app probes your machine's encoders in the background (a few seconds) and caches
the result. The status bar shows FFmpeg readiness. If it says **"FFmpeg NOT found"**, place
`ffmpeg.exe` + `ffprobe.exe` next to `VideoEditor.exe` (or in an `ffmpeg\` subfolder), or add them
to your `PATH`.

## The window
- **Left — Media**: your imported files. Select one and click **＋ Add to timeline**.
- **Center — Preview + Timeline**: the composited preview, the playhead scrubber, transport
  controls, and the horizontal clip timeline.
- **Right — Properties**: tabs for **Clip · Text · Image · Audio · Export**.
- **Bottom — Status**: messages and a render progress bar with **Cancel**.

## Typical workflow
1. **Import media…** (toolbar) and select files.
2. Select a video → **＋ Add to timeline**. Repeat to **join** several clips; use **◀/▶ Move** to
   reorder and **Remove** to delete.
3. **Trim** on the *Clip* tab: type In/Out seconds, or drag the scrubber and click **Set ⟵**.
4. **Text**: *Text* tab → **＋ Add text**, then edit the content, timing, position (9-anchor),
   font size/color, and box. Move the playhead into the text's time range to see it.
5. **Image/logo**: *Image* tab → **＋ Add image…**, set timing, position, scale, opacity.
6. **Audio**: *Audio* tab → **＋ Add audio…**, choose **Mix** or **Replace**, toggle **Loop**, set
   volume.
7. **Preview**: scrub the timeline; use ⏮ ◀ǀ ▶ ǀ▶ ⏭ and **⟳ Refresh**.
8. **Export**: set container/codec/aspect/quality on the *Export* tab, then **Export video…**.
9. **Save** to write a `.vproj` you can reopen later with **Open…**.

## Export tips
- **YouTube (landscape)**: Aspect = `Widescreen16x9`, Height = 1080/1440/2160, tick
  **Normalize loudness (−14 LUFS)**.
- **Shorts / Reels**: Aspect = `Vertical9x16`.
- **Quality**: lower number = better/larger (CRF/CQ/QP ~18–24 is a good range).
- **Prefer hardware encoder** uses NVENC/QuickSync/AMF when they passed the probe, else software.

## Utilities (Export tab)
- **Grab frame…** — save the current composite as an image (thumbnail).
- **Copy chapters** — copy a `mm:ss Chapter n` list from clip boundaries for the description.
- **Extract audio… / Extract video…** — pull a stream from the selected media-bin item.

## Troubleshooting
- **No preview**: ensure a clip is on the timeline and FFmpeg is available.
- **Text shows no font / errors**: your FFmpeg build needs `drawtext` (libfreetype). Use a
  full/GPL build; specify a `FontFile` on the overlay if the default can't be found.
- **Export failed**: the exact ffmpeg error is shown and written to `logs/` next to the exe.
- **Mixed sources look letterboxed**: clips are scaled+padded to the canvas — set the canvas
  (Export tab) to your dominant source's resolution.

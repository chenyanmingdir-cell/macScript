---
name: macscript
description: Build and export macScript storyboard PDFs (分镜脚本) — cut reference frames from footage, assemble the .macscript shot table, render the PDF with the app's own layout, and check the pages visually.
---

# macScript storyboards

macScript is the user's macOS storyboard app. A `.macscript` project is plain
JSON, so a storyboard can be produced end to end without the UI: frames come out
of the reference footage with ffmpeg, the shot table is assembled from a small
spec file, and the PDF is rendered by the app's own layout code.

Use this for 分镜脚本 / storyboard / shot-list PDFs, especially when the user
supplies reference videos to cut frames from. For prose scriptwriting with no
frame column, a plain document is usually a better deliverable.

## Workflow

1. **Choose frames by looking at them.** Sample candidates, then open the actual
   frames before deciding — do not pick timestamps blind.

   ```bash
   ffmpeg -y -ss 12 -i ref.m4v -frames:v 1 out/01.jpg          # single frame
   ffmpeg -y -i ref.m4v -vf "fps=1/6,scale=320:-1,tile=5x3" -frames:v 1 sheet.jpg
   ```

   Name output frames with their shot number (`01_…jpg`) so the spec stays readable.

2. **Write a spec** — title, team name, aspect, columns, shots. See
   [references/format.md](references/format.md) for the full schema and every
   column role.

3. **Build the project**:

   ```bash
   ~/.codex/skills/macscript/scripts/build_macscript.py spec.json -o "…/Projects/NAME.macscript"
   ```

   To have it show up inside the app, write it to the app's project folder:
   `~/Library/Containers/com.chenyanming.macScript/Data/Documents/macScript Projects/`.
   Writing a copy next to the other deliverables is usually welcome too, and the
   user often opens projects straight from `~/Documents`.

4. **Build a print copy and export the PDF from that**:

   ```bash
   ~/.codex/skills/macscript/scripts/build_macscript.py spec.json --hide order -o "…/NAME_打印版.macscript"
   ~/.codex/skills/macscript/bin/macscript-pdf "…/NAME_打印版.macscript" "…/NAME.pdf"
   ```

   `--hide order` drops the mostly-empty 排序 column from the PDF only; the
   project the user edits keeps it (see below). Keep the print copy in the output
   folder rather than the app's project folder so it does not clutter the app's
   project list.

5. **Verify the pages**, not just the exit code: render and look.

   ```bash
   pdftoppm -png -r 96 NAME.pdf /tmp/check   # Poppler; also in the bundled runtime
   ```

   Check that the table's right edge is inside the page, frames are the intended
   moments, and the durations add up to the target length.

## Layout rules that decide whether the PDF is usable

The page is 1440×900 pt for 16:9 (1000×1440 for 9:16), with **4 shots per page**
and 40 pt padding. Nothing is scaled: the table is laid out at its natural column
widths, so **the visible columns must total ≤ 1360** or the right edge runs off
the page. Short pages are padded with empty rows, so 8 shots fill exactly two
pages and 16 fill four. Only the first page carries the title header.

`rowHeight = max(minimumRowHeight, (frameWidth-24)/aspect + 24)`. With 16:9,
`frameWidth = 300` gives ≈179 pt rows, which is about the tallest that still
leaves room for four rows plus header and footer; four rows at that height is
what the app's own projects use, so treat 300 as the practical ceiling for the
frame column. Column widths clamp to 72…520 and `minimumRowHeight` to 96…180.

**Two app behaviours that silently ruin a project's look:**

**Never hide the 排序 (`order`) column in a project the user will edit.** It looks
empty, but every row's drag handle, insert (+) and delete (trash) buttons are
drawn inside that column's cell. Setting `isVisible: false` removes the whole
column along with those controls, and the storyboard can no longer be reordered,
extended or trimmed — the file still opens and looks fine in the PDF, so the
damage is easy to miss. Hiding 排序 is only acceptable in a throwaway copy that
exists purely to be exported; keep the editable file intact. `build_macscript.py`
warns when a spec hides it.

**Avoid custom columns in a project the user will edit.** As soon as a project
contains one, the app's `normalize()` squeezes 景别 / 时长 / 内容 / 备注 down to
their minimum widths (90 / 86 / 220 / 150) to make room, so the text the user
sees in the app ends up cramped and oversized-looking next to their own files.
Put extra content in a built-in column and retitle it instead — the app lets a
column's title be edited freely, so `{"role": "note", "title": "旁白"}` gives a
seven-column storyboard that looks exactly as comfortable as the user's own
projects. (The cell placeholder text still reads 备注, because the app hardcodes
prompts per role.)

Column order is not worth fighting either: the app sorts columns to 排序 / 镜号 /
画面 / 景别 / 时长 / 内容 / 备注 on open and on save.

## Files

- `scripts/build_macscript.py` — spec JSON → `.macscript` (embeds frames as base64, downscales with sips).
- `bin/macscript-pdf` — headless PDF export; takes a `.macscript` and an output path.
- `scripts/build.sh` — rebuilds the exporter from `scripts/vendor/`.
- `scripts/sync_vendor.sh` — re-copies `ScriptDocument.swift` and `PDFExporter.swift`
  from the macScript Xcode project and rebuilds. Run it after the user changes the
  app's layout so exports keep matching the app.

`vendor/` is a byte-identical copy of the app sources; `build.sh` applies a single
build-time `@MainActor` annotation that a command-line target needs and a SwiftUI
app gets implicitly. Keep the vendored copy pristine so it stays diffable.

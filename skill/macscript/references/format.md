# .macscript format reference

A project file is JSON written with sorted keys. The app tolerates missing
fields; `normalize()` fills in built-in columns and renumbers shot numbers.

```json
{
  "title": "AMK×何晟铭 秋季 40s 正片分镜",
  "teamName": "AMK 2026 AW",
  "frameAspectRatio": 1.7777777777777777,
  "minimumRowHeight": 116,
  "columns": [
    { "id": "shotNumber", "title": "镜号", "width": 76, "isVisible": true, "role": "shotNumber" }
  ],
  "shots": [
    {
      "id": "B1C4…UUID…", "shotNumber": 1, "shotSize": "一镜到底", "duration": "6",
      "content": "画面内容", "note": "备注",
      "customValues": { "custom-旁白-1": "旁白文字" },
      "imageData": "<base64 of the raw image bytes>"
    }
  ]
}
```

## Columns

`role` decides how a cell is drawn and edited. Built-in roles and their default
titles/widths:

| role | title | width | notes |
| --- | --- | --- | --- |
| `order` | 排序 | 78 | renders the per-row drag / insert / delete controls — keep it visible |
| `shotNumber` | 镜号 | 92 | auto-numbered from the shot array |
| `frameImage` | 画面 | 300 | the only image column; width drives row height |
| `shotSize` | 景别 | 118 | free text: 远景 / 特写 / 一镜到底 / 左右分屏 … |
| `duration` | 时长(秒) | 110 | free text, summed into 总时长 |
| `content` | 内容 | 360 | the shot description |
| `note` | 备注 | 250 | production notes |
| `customText` | (your title) | 180 | extra columns; values live in `customValues` |

Custom column ids are stable strings; the app writes them as
`custom-<uuid>-<n>`. Values are addressed by column id, not by title, so
`build_macscript.py` maps `"custom": {"旁白": "…"}` through the column titles.

## Shots

- `id` must be a UUID string; the app rewrites them if you get it wrong.
- `imageData` is absent when a shot has no frame. Any format `NSImage` can decode
  works; the app itself writes PNG, but JPEG keeps a storyboard project to a
  megabyte or two instead of tens of megabytes.
- `duration` is a string and may be empty.

## Aspect and page geometry

`frameAspectRatio >= 1` means landscape (page 1440×900, frames drawn 16:9-ish);
below 1 it is portrait (page 1000×1440, frames drawn in a narrow column). The
frame cell clips with `scaledToFill`, so an off-aspect source image is centre
cropped rather than letterboxed.

## What the app changes on open

`normalize()` runs every time a project is opened or saved:

- shot numbers are renumbered from the array order;
- columns are sorted 排序 / 镜号 / 画面 / 景别 / 时长 / 内容 / 备注, with custom
  columns last, and widths are clamped to 72…520;
- built-in columns the file is missing are appended, and empty titles fall back
  to the role's default;
- **if the project has any custom column, 景别 / 时长 / 内容 / 备注 are squeezed
  to 90 / 86 / 220 / 150** so the new column gets roughly 130. This is the usual
  reason a generated project looks cramped in the app compared to one the user
  made by hand — prefer retitling a built-in column over adding a custom one.

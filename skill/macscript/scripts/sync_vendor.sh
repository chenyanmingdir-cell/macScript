#!/bin/bash
# Re-copy ScriptDocument.swift + PDFExporter.swift from the macScript app source,
# so the headless exporter keeps matching the app's own PDF layout.
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Prefer the copy of the app that ships next to this skill (repo layout:
# <repo>/app/macScript, <repo>/skill/macscript/scripts/), then fall back to the
# author's working copy. The old macScript / macScript2 projects export a
# different PDF layout (1280x800 scaled page) — do not vendor from those.
APP_SRC="${MACSCRIPT_APP_SRC:-}"
if [ -z "$APP_SRC" ]; then
  for candidate in \
    "$SKILL_DIR/../../app/macScript" \
    "/Users/nois/Desktop/01/0317 明的时间机器/macScript3/macScript"
  do
    if [ -f "$candidate/PDFExporter.swift" ]; then
      APP_SRC="$candidate"
      break
    fi
  done
fi

if [ ! -f "$APP_SRC/PDFExporter.swift" ]; then
  APP_SRC="$(dirname "$(mdfind -name PDFExporter.swift 2>/dev/null | grep -v '\.codex' | head -1)")"
fi

if [ ! -f "$APP_SRC/PDFExporter.swift" ]; then
  echo "找不到 macScript 源码目录，请设置 MACSCRIPT_APP_SRC" >&2
  exit 1
fi

cp "$APP_SRC/ScriptDocument.swift" "$APP_SRC/PDFExporter.swift" "$SKILL_DIR/scripts/vendor/"
echo "synced from: $APP_SRC"
"$SKILL_DIR/scripts/build.sh"

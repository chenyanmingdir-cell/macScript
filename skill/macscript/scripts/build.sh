#!/bin/bash
# Build the headless exporter from the vendored macScript sources.
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$SKILL_DIR/bin" "$SKILL_DIR/scripts/build"

# vendor/ stays byte-identical to the app. The only build-time edit is marking
# makePDF as @MainActor, because SwiftUI's ImageRenderer is main-actor isolated
# and a command-line target has no implicit main actor like the SwiftUI app has.
cp "$SKILL_DIR/scripts/vendor/ScriptDocument.swift" "$SKILL_DIR/scripts/build/"
awk '{ if ($0 ~ /static func makePDF\(project: ScriptProject\)/) print "    @MainActor"; print }' \
  "$SKILL_DIR/scripts/vendor/PDFExporter.swift" > "$SKILL_DIR/scripts/build/PDFExporter.swift"

swiftc -O -swift-version 5 \
  -o "$SKILL_DIR/bin/macscript-pdf" \
  "$SKILL_DIR/scripts/main.swift" \
  "$SKILL_DIR/scripts/build/ScriptDocument.swift" \
  "$SKILL_DIR/scripts/build/PDFExporter.swift"

echo "built: $SKILL_DIR/bin/macscript-pdf"

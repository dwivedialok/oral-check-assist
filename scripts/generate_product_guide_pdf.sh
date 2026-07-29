#!/usr/bin/env bash
# Generate product guide PDF from Markdown.
# Uses pandoc (MD -> HTML) then weasyprint (HTML+CSS -> PDF) so the cover logo resolves.
# Requires: pandoc, weasyprint (and its system libs).
#
# Usage (from repo root):
#   ./scripts/generate_product_guide_pdf.sh
#   ./scripts/generate_product_guide_pdf.sh -o path/to/custom.pdf
#
# WeasyPrint system deps (macOS): brew install cairo pango gdk-pixbuf libffi

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOCS_DIR="$REPO_ROOT/docs"
cd "$REPO_ROOT"

mkdir -p "$DOCS_DIR/product_guide_assets"

# Copy a cover icon into docs/ so the MD path product_guide_assets/app_icon.png resolves
# (WeasyPrint uses --base-url=file://$DOCS_DIR/). Try repo-root Flutter asset first, then fallbacks.
ICON_OUT="$DOCS_DIR/product_guide_assets/app_icon.png"
ICON_COPIED=""
for src in \
  "$REPO_ROOT/assets/app_icon.png" \
  "$REPO_ROOT/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png" \
  "$REPO_ROOT/web/og-image.png"
do
  if [[ -f "$src" ]]; then
    cp "$src" "$ICON_OUT"
    ICON_COPIED="$src"
    break
  fi
done

if [[ -z "$ICON_COPIED" ]]; then
  echo "Warning: no app icon found (checked assets/app_icon.png, macOS app_icon_1024.png, web/og-image.png)." >&2
  echo "         Add assets/app_icon.png or run from a full checkout; cover image will be missing." >&2
fi

MD="${MD:-docs/APP_CLINICIAN_GUIDE.md}"
CSS="${CSS:-docs/product_guide.css}"
OUT="${OUT:-docs/product_guide.pdf}"

OUT_ABS="$OUT"
[[ "$OUT" != /* ]] && OUT_ABS="$REPO_ROOT/$OUT"

cd "$DOCS_DIR"
MD_BASE="$(basename "$MD")"
CSS_BASE="$(basename "$CSS")"
pandoc "$REPO_ROOT/$MD" -t html5 -s -o _guide.html --css="$CSS_BASE"
weasyprint _guide.html "$OUT_ABS" --base-url="file://$DOCS_DIR/"
rm -f _guide.html
cd "$REPO_ROOT"

echo "Generated: $OUT_ABS"

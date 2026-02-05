#!/bin/bash
set -e

OUTDIR="html"
TIKZDIR="$OUTDIR/tikz_build"

rm -rf "$OUTDIR"
mkdir -p "$OUTDIR" "$TIKZDIR"

TEXFILE="ap_csp_summary.tex"

# --- Step 1: Extract and pre-render tikzpicture environments as PNGs ---
echo "==> Extracting and rendering tikz pictures..."

# Extract each tikzpicture block and compile as standalone PDF, then convert to PNG
COUNT=0
IN_TIKZ=0
TIKZ_BLOCK=""

while IFS= read -r line; do
    if echo "$line" | grep -q '\\begin{tikzpicture}'; then
        IN_TIKZ=1
        TIKZ_BLOCK="$line"
    elif echo "$line" | grep -q '\\end{tikzpicture}'; then
        TIKZ_BLOCK="$TIKZ_BLOCK
$line"
        IN_TIKZ=0

        # Write standalone tex file
        TIKZ_TEX="$TIKZDIR/tikz_${COUNT}.tex"
        cat > "$TIKZ_TEX" <<TEXEOF
\\documentclass[tikz,border=10pt]{standalone}
\\usepackage{xcolor}
\\usepackage{amsmath}
\\usepackage{amssymb}

\\definecolor{codegreen}{rgb}{0,0.6,0}
\\definecolor{codegray}{rgb}{0.5,0.5,0.5}
\\definecolor{codepurple}{rgb}{0.58,0,0.82}
\\definecolor{backcolour}{rgb}{0.95,0.95,0.92}
\\definecolor{hlyellow}{HTML}{FFFACD}
\\definecolor{hlred}{HTML}{FFCCCB}
\\definecolor{hlblue}{HTML}{ADD8E6}
\\definecolor{codeblue}{rgb}{0,0,0.9}
\\definecolor{codeorange}{rgb}{0.8,0.4,0}
\\definecolor{commentcolor}{rgb}{0.5,0.5,0.5}

\\begin{document}
${TIKZ_BLOCK}
\\end{document}
TEXEOF

        # Compile to PDF
        echo "    Compiling tikz_${COUNT}..."
        pdflatex -output-directory="$TIKZDIR" -interaction=nonstopmode "$TIKZ_TEX" > /dev/null 2>&1 || true

        # Convert PDF to PNG
        if [ -f "$TIKZDIR/tikz_${COUNT}.pdf" ]; then
            pdftoppm -png -r 300 -singlefile "$TIKZDIR/tikz_${COUNT}.pdf" "$OUTDIR/tikz_${COUNT}"
            echo "    -> tikz_${COUNT}.png created"
        else
            echo "    WARNING: tikz_${COUNT}.pdf not generated"
        fi

        COUNT=$((COUNT + 1))
    elif [ $IN_TIKZ -eq 1 ]; then
        TIKZ_BLOCK="$TIKZ_BLOCK
$line"
    fi
done < "$TEXFILE"

echo "==> Extracted $COUNT tikz pictures"

# --- Step 2: Run make4ht to generate HTML ---
echo "==> Running make4ht..."
make4ht -u -d "$OUTDIR" "$TEXFILE" "" "" "" "-interaction=nonstopmode"

# --- Step 3: Replace broken SVGs with rendered PNGs in the HTML ---
echo "==> Patching HTML to use rendered PNGs..."
HTMLFILE="$OUTDIR/ap_csp_summary.html"

for i in $(seq 0 $((COUNT - 1))); do
    SVG_NAME="ap_csp_summary${i}x.svg"
    PNG_NAME="tikz_${i}.png"

    if [ -f "$OUTDIR/$PNG_NAME" ]; then
        # Replace the SVG reference with PNG, and add a reasonable style
        sed -i '' "s|src='${SVG_NAME}'|src='${PNG_NAME}' style='max-width:100%;height:auto'|g" "$HTMLFILE"
        # Remove the broken SVG
        rm -f "$OUTDIR/$SVG_NAME"
        echo "    Replaced $SVG_NAME -> $PNG_NAME"
    fi
done

# --- Step 4: Clean up build artifacts ---
rm -rf "$TIKZDIR"

# make4ht leaves intermediate files in the working directory
BASENAME="${TEXFILE%.tex}"
rm -f "${BASENAME}.4ct" "${BASENAME}.4tc" "${BASENAME}.dvi" \
      "${BASENAME}.idv" "${BASENAME}.lg" "${BASENAME}.tmp" \
      "${BASENAME}.xref" "${BASENAME}"*x.svg

echo "==> Done. Output in $OUTDIR/"

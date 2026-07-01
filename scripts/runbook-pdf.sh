#!/usr/bin/env bash
# Render every runbook/*.md to a booklet-imposed PDF.
#   Logical pages: 5.5"x8.5" portrait, 0.5" margins, 10pt body, page numbers.
#   Imposition: pdfjam --booklet onto letter landscape (11"x8.5"), 2-up,
#   page order rearranged so a stack of letter sheets folded in half forms
#   a 5.5"x8.5" booklet.
#   TOC policy:  nvim-tutorial.md + everything except nvim-cheatsheet.md get a TOC.
#   Cover policy: rendered without a cover by default; if the logical PDF would
#   leave exactly one trailing blank after imposition (N mod 4 == 3), a cover
#   page is added so the booklet closes cleanly. Cheatsheet never gets a cover.
# Pipeline: pandoc (markdown -> typst) + typst (typeset -> PDF) + pdfjam (impose).
# Output: runbook/<name>.pdf, gitignored via /runbook/*.pdf in .gitignore.
# Run: `pnpm pdf` or `bash scripts/runbook-pdf.sh`.
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")/.."   # repo root
repo_root=$PWD
runbook_dir="runbook"

for tool in pandoc typst pdfjam pdfinfo; do
  command -v "$tool" >/dev/null 2>&1 || { echo "Missing: $tool. Install via pacman."; exit 1; }
done

template=$(mktemp --suffix=.typ)
# pdfjam writes intermediate `toPdfViaTempFile<PID>-*.{source,pdf}` files into
# its CWD; on a clean run --tidy removes them, but on abort they leak. Run it
# from a per-invocation temp dir so debris can't land in the repo root.
pdf_workdir=$(mktemp -d)
trap 'rm -f "$template"; rm -rf "$pdf_workdir"' EXIT

cat > "$template" <<'TYPST'
// --- Pandoc helpers (kept from the default typst template) ---
#let horizontalrule = line(start: (25%, 0%), end: (75%, 0%))

#show terms: it => {
  it.children
    .map(child => [
      #strong[#child.term]
      #block(inset: (left: 1.5em, top: -0.4em))[#child.description]
    ])
    .join()
}

#set table(inset: 6pt, stroke: 0.5pt + luma(180))
#show table: set text(size: 0.92em)

// --- Page setup: 5.5x8.5 portrait (letter folded in half), 0.5" margins,
//     page numbers centered. Imposed onto letter landscape by pdfjam later.
#set page(
  width: 5.5in,
  height: 8.5in,
  margin: 0.5in,
  numbering: "1",
  number-align: center,
)

// --- Body text ---
#set text(
  size: $if(fontsize)$$fontsize$$else$10pt$endif$,
)
#set par(justify: false, leading: 0.55em, first-line-indent: 0pt)

// --- Headings ---
#show heading.where(level: 1): it => block(below: 0.7em, above: 1.3em)[
  #set text(weight: "bold", size: 1.5em)
  #it.body
]
#show heading.where(level: 2): it => block(below: 0.5em, above: 1.1em)[
  #set text(weight: "bold", size: 1.2em)
  #it.body
]
#show heading.where(level: 3): it => block(below: 0.3em, above: 0.8em)[
  #set text(weight: "bold", size: 1.05em)
  #it.body
]

// Keep headings with their following content; avoid orphan headings stranded
// at the bottom of a page (sticky pulls the heading to the next page if its
// content would break there). `dense` docs (cheatsheet) also make lead
// paragraphs sticky so a heading + one-line intro can't strand above a table.
#show heading: it => block(it, breakable: false, sticky: true)
$if(dense)$
#show par: it => block(it, sticky: true)
$endif$

// --- Code blocks ---
// Non-breakable: these docs' code blocks are short (<=~5 lines), so keep each
// intact and let it move to the next page as a unit rather than split mid-block.
#show raw.where(block: true): it => block(
  fill: luma(245),
  inset: (x: 8pt, y: 6pt),
  radius: 2pt,
  width: 100%,
  breakable: false,
)[#set text(size: 0.82em); #it]

#show raw.where(block: false): it => box(
  fill: luma(240),
  inset: (x: 2pt, y: 0pt),
  outset: (y: 2pt),
  radius: 1pt,
)[#it]

$for(header-includes)$
$header-includes$

$endfor$

$if(cover)$
// --- Cover page (unnumbered, added only when imposition would otherwise
//     leave a trailing blank — see runbook-pdf.sh for the rule) ---
#page(numbering: none, margin: 0.5in)[
  #set align(center + horizon)
  #text(26pt, weight: "bold")[$title$]
  $if(date)$
  #v(2em)
  #text(11pt)[$date$]
  $endif$
]
$endif$

$if(toc)$
// --- TOC pages numbered with roman numerals ---
#set page(numbering: "i")
#counter(page).update(1)
#outline(
  title: [Contents],
  depth: $if(toc-depth)$$toc-depth$$else$2$endif$,
  indent: auto,
)
#pagebreak()
#set page(numbering: "1")
#counter(page).update(1)
$endif$

$if(title)$
// --- Title block: title + subtitle (the doc's lead line) + date, at the top
//     of the content. The H1 and lead paragraph are stripped from the body by
//     render_logical so they aren't duplicated here.
#block(below: 1.3em)[
  #text(size: 1.9em, weight: "bold")[$title$]
  $if(subtitle)$
  #v(0.35em)
  #block(width: 100%)[#text(size: 1.05em, fill: luma(90))[#emph[$subtitle$]]]
  $endif$
  $if(date)$
  #v(0.4em)
  #text(size: 0.85em, fill: luma(130))[$date$]
  $endif$
]
$endif$

$body$
TYPST

# Render a single markdown file to a logical (un-imposed) 5.5x8.5 PDF.
# Args: md_path, out_pdf, want_toc (0|1), want_cover (0|1), title, want_dense (0|1)
render_logical() {
  local md=$1 outpdf=$2 want_toc=$3 want_cover=$4 title=$5 want_dense=${6:-0}

  # Subtitle = the doc's first non-empty paragraph (its lead line); date = today.
  # Both feed the rendered title block; strip backticks so inline-code markup in
  # the lead line doesn't show as literal backticks in the subtitle.
  local subtitle date_str
  subtitle=$(awk 'seen && NF { gsub(/`/, ""); print; exit } /^# / { seen = 1 }' "$md")
  date_str=$(date +'%B %-d, %Y')

  local body
  body=$(mktemp --suffix=.md)
  # Strip the first H1 (title) and the first non-empty paragraph (subtitle) from
  # the body — they are rendered in the title block instead of inline.
  awk '
    !h1 && /^# / { h1 = 1; next }
    h1 && !subseen && NF { subseen = 1; next }
    { print }
  ' "$md" > "$body"

  local args=(
    --from=markdown-citations
    --pdf-engine=typst
    --template="$template"
    -V fontsize=10pt
    -M title="$title"
    -M subtitle="$subtitle"
    -M date="$date_str"
  )
  if [[ $want_toc -eq 1 ]]; then
    args+=(--toc --toc-depth=2)
  fi
  if [[ $want_cover -eq 1 ]]; then
    args+=(-V cover=true)
  fi
  if [[ $want_dense -eq 1 ]]; then
    args+=(-V dense=true)
  fi

  pandoc "$body" -o "$outpdf" "${args[@]}"
  local rc=$?
  rm -f "$body"
  return $rc
}

mapfile -t mds < <(find "$runbook_dir" -maxdepth 1 -name '*.md' -type f | sort)
if [[ ${#mds[@]} -eq 0 ]]; then
  echo "No .md files in $runbook_dir"
  exit 1
fi

failures=0
for md in "${mds[@]}"; do
  out="${md%.md}.pdf"
  base=$(basename "${md%.md}")

  # Title: first H1 (sans "# "), or fall back to filename.
  title=$(grep -m1 '^# ' "$md" 2>/dev/null | sed 's/^# *//' || true)
  if [[ -z "$title" ]]; then
    title=$base
  fi

  # Per-doc TOC + cover policy.
  case "$base" in
    nvim-cheatsheet)
      want_toc=0
      allow_cover=0   # dense reference; accept trailing blanks rather than pad
      want_dense=1    # keep heading+lead-para stuck to the following table
      ;;
    *)
      want_toc=1
      allow_cover=1
      want_dense=0
      ;;
  esac

  echo ">> $md -> $out"

  tmp_logical=$(mktemp --suffix=.pdf)

  if ! render_logical "$md" "$tmp_logical" "$want_toc" 0 "$title" "$want_dense"; then
    echo "  FAIL render: $md"
    failures=$((failures + 1))
    rm -f "$tmp_logical"
    continue
  fi

  # Cover-page rule: a single cover only helps when the page count mod 4 is
  # exactly 3 (cover + N = N+1 ≡ 0 mod 4 → no trailing blanks).
  if [[ $allow_cover -eq 1 ]]; then
    pages=$(pdfinfo "$tmp_logical" | awk '/^Pages:/ {print $2}')
    if (( pages % 4 == 3 )); then
      echo "   pages=$pages → adding cover to clear trailing blank"
      if ! render_logical "$md" "$tmp_logical" "$want_toc" 1 "$title" "$want_dense"; then
        echo "  FAIL re-render with cover: $md"
        failures=$((failures + 1))
        rm -f "$tmp_logical"
        continue
      fi
    else
      echo "   pages=$pages (mod 4 = $((pages % 4))) → no cover"
    fi
  fi

  # Booklet imposition: 2 logical pages per side of letter landscape, ordered
  # so a folded stack reads as a booklet. pdfjam pads to a multiple of 4 with
  # trailing blanks automatically.
  if ! ( cd "$pdf_workdir" && pdfjam --quiet --booklet true --paper letterpaper \
          --landscape --outfile "$repo_root/$out" "$tmp_logical" ); then
    echo "  FAIL pdfjam: $md"
    failures=$((failures + 1))
  fi

  rm -f "$tmp_logical"
done

echo
if [[ $failures -gt 0 ]]; then
  echo "$failures failure(s)"
  exit 1
fi
echo "Generated:"
ls -lh "$runbook_dir"/*.pdf

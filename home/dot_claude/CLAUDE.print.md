# Printing

Covers how to print on Tom's machine — the printers and, above all,
booklet printing. **A markdown or PDF prints as a folded booklet by
default** — when asked to "print" a doc, render/impose it as a booklet
(see the booklet section) unless told otherwise (e.g. "print flat /
single pages"). Always verify a generated PDF (page count + content, or a
rendered preview image) before sending a physical job — a broken render
silently yields a near-empty PDF that wastes paper.

## HP Color LaserJet Pro M252dw (the main printer)

- CUPS queue `hp_m252dw`, the system default on this machine. Device
  `hp:/net/HP_Color_LaserJet_Pro_M252dw?hostname=NPI0DFEC4.local`.
  Networked color laser with an automatic duplexer.
- Basic print: `lp -d hp_m252dw -o media=letter [opts] <file.pdf>`.
- Options that matter:
  - Color: `-o print-color-mode=color` or `-o print-color-mode=monochrome`.
  - Duplex (PPD-native): `-o Duplex=DuplexTumble` (short-edge) /
    `-o Duplex=DuplexNoTumble` (long-edge) / `-o Duplex=None`.
  - Duplex (portable IPP equivalents CUPS maps to the above):
    `-o sides=two-sided-short-edge` / `two-sided-long-edge` / `one-sided`.
- Inspect: `lpstat -p hp_m252dw` (state), `lpstat -o hp_m252dw` (queued
  jobs), `lpstat -W completed -o hp_m252dw` (recent), `lpoptions -p
  hp_m252dw -l` (capabilities/choices).
- Cancel: `cancel <job-id>` or `cancel -a hp_m252dw`. A short job may
  finish before the cancel lands — hence: verify before printing.
- Recovering the options a PAST job used (there's often no `lp` command
  in shell history — jobs get sent via GUIs or space-prefixed): CUPS
  keeps per-job control files at `/var/spool/cups/c#####` (root-readable).
  `sudoa strings /var/spool/cups/cNNNNN | grep -iE 'sides|Duplex|media|color'`
  reveals the exact settings.

## Canon Pixma Pro 9000 Mark II (INCOMPLETE — do not investigate)

**Stub only.** What's known is only what's in the arch-setup repo; fill
in the real queue name / device URI / options when the Canon is actually
used. Do NOT go investigate now.

- Known: a Canon Pixma Pro 9000 Mark II photo inkjet, USB-attached.
  arch-setup's `phase-3-arch-postinstall/postinstall.sh` §1-print installs
  CUPS + gutenprint (open-source PPDs) naming this printer.
- Caveat: on the current machine the live default is the HP network laser
  above, not the Canon — the arch-setup Canon reference may be stale or
  for a different machine. Treat the queue name/URI as unknown until
  verified.

## Booklet printing (the default for markdowns/PDFs)

- Generator: `scripts/runbook-pdf.sh` (present in both the `dots` and
  `arch-setup` repos), run via `npm run pdf` / `pnpm pdf` from the repo
  root. Pipeline: pandoc (markdown → typst) → typst (typeset to
  5.5"×8.5" logical pages) → pdfjam `--booklet` (impose 2-up onto
  letter-landscape, reordered so a folded stack reads as a booklet).
  Needs `pandoc`, `typst`, `pdfjam` (texlive-binextra), `pdfinfo`
  (poppler).
- The generated PDFs are ALREADY IMPOSED (2-up, letter-landscape). Print
  them as-is, double-sided — do NOT have CUPS re-impose (no `number-up`,
  no booklet filter).
- **Correct duplex is short-edge**: `-o Duplex=DuplexTumble` (==
  `-o sides=two-sided-short-edge`). That yields a 5.5"×8.5", left-bound,
  portrait booklet from letter sheets folded in half. Long-edge is WRONG.
  (Why: the landscape imposition rotates content 90°, so the logical
  long-edge fold becomes a physical short-edge flip.)
- Full booklet command:
  ```sh
  lp -d hp_m252dw -o media=letter -o Duplex=DuplexTumble -o print-color-mode=color runbook/<name>.pdf
  ```
- To assemble: stack the printed sheets, fold in half — the crease is the
  left spine.
- Template conventions inside `runbook-pdf.sh` (typst): headings are
  `sticky: true` (a section heading is never orphaned at a page bottom,
  away from its table); code blocks are `breakable: false` (they're
  short — never split one across a page); "dense" docs (the cheatsheet,
  rendered with `-V dense=true`) also make lead paragraphs sticky so a
  heading + one-line intro stays with the table it introduces; a title
  block (H1 as title, the doc's first paragraph as subtitle, today's
  date) renders at the top of the content; per-doc policy gives most
  docs a TOC but the cheatsheet none, and a padding cover page is only
  added when the logical page count mod 4 == 3.
- awk gotcha in that script: never name an awk variable `sub` (it's a
  reserved function) — it errors silently and produces a near-empty PDF.
- Cover / title page: the title block currently renders *after* the TOC
  (inside the content), which is not a real front cover. For a proper
  cover, print a single-sheet wrap-around: a letter-LANDSCAPE page
  (compile with `typst`) whose title/subtitle/date are vertically AND
  horizontally centered in the RIGHT half (that half becomes the front
  cover when folded — it matches the booklet's page-1 position), left
  half blank, printed single-sided (`-o sides=one-sided`). Fold the
  blank half behind and wrap it around the finished booklet, crease on
  the left spine. (Known TODO: make the pipeline emit a title page
  *before* the TOC so a wrap-around isn't needed.)
- Cross-reference: there is a project memory `project_booklet_printing`
  with the same operational details for the dots repo.

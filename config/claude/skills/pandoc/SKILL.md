---
name: pandoc
description: >
  Pandoc universal document converter between Markdown, DOCX, PDF, HTML, EPUB, LaTeX, and PPTX, with templates, reference docs, citations/bibliography, table of contents, syntax highlighting, and metadata.
  Use any time a document is converted between formats (Markdown, DOCX, PDF, HTML, EPUB, LaTeX), or when a conversion needs templates, citations, or a TOC.
---

Pandoc converts between markup formats. Source format inferred from input extension, target from `-o` extension (or force with `-f`/`-t`).

## Common Operations

### Markdown -> PDF

```bash
# Requires a LaTeX engine (see Rules). Default engine:
pandoc input.md -o output.pdf

# Pick engine + nicer defaults
pandoc input.md -o output.pdf --pdf-engine=xelatex \
  -V geometry:margin=1in -V mainfont="Helvetica Neue"

# With TOC and section numbering
pandoc input.md -o output.pdf --toc --number-sections
```

### Markdown -> DOCX

```bash
# Plain conversion
pandoc input.md -o output.docx

# Using a styled reference document (corporate template)
pandoc input.md -o output.docx --reference-doc=template.docx

# Generate an editable reference doc to customize, then reuse:
pandoc -o reference.docx --print-default-data-file reference.docx
```

### Markdown -> HTML

```bash
# Standalone page (full <html> wrapper)
pandoc input.md -o output.html --standalone

# Self-contained (CSS/images inlined, single portable file)
pandoc input.md -o output.html --standalone --embed-resources

# With custom CSS + TOC
pandoc input.md -o output.html -s --toc -c styles.css
```

### DOCX / HTML -> Markdown

```bash
# Word -> Markdown, extract embedded images to ./media
pandoc input.docx -o output.md --extract-media=./media

# HTML -> GitHub-flavored Markdown
pandoc input.html -f html -t gfm -o output.md
```

### Markdown -> PPTX (slides)

```bash
# Slides split on headings (## = new slide)
pandoc slides.md -o slides.pptx

# With a branded template
pandoc slides.md -o slides.pptx --reference-doc=brand.pptx
```

### Markdown -> EPUB

```bash
pandoc book.md -o book.epub --toc \
  --metadata title="My Book" --metadata author="Author" \
  --epub-cover-image=cover.png
```

### Markdown -> Beamer / reveal.js

```bash
# PDF slide deck (LaTeX Beamer)
pandoc slides.md -t beamer -o slides.pdf

# HTML reveal.js deck
pandoc slides.md -t revealjs -s -o slides.html \
  -V revealjs-url=https://unpkg.com/reveal.js
```

### Citations / Bibliography

```bash
# CSL citations from a .bib file
pandoc paper.md --citeproc --bibliography=refs.bib -o paper.pdf

# Specific citation style
pandoc paper.md --citeproc --bibliography=refs.bib \
  --csl=ieee.csl -o paper.pdf
```

## Metadata

YAML front matter drives titles, authors, TOC, and template variables:

```markdown
---
title: "Document Title"
author: "Your Name"
date: "2026-06-04"
lang: es
toc: true
number-sections: true
---
```

Or pass inline: `--metadata title="X"` / `-V key=value` for template variables.

## Useful Flags

```bash
--toc                      # table of contents
--number-sections          # numbered headings
--standalone / -s          # full document wrapper, not a fragment
--embed-resources          # inline all assets (HTML)
--reference-doc=FILE       # DOCX/PPTX styling template
--template=FILE            # custom output template
--highlight-style=kate     # code syntax theme (kate, pygments, breezedark...)
--resource-path=DIR        # where to find images/includes
--from gfm --to docx       # force formats explicitly
--toc-depth=2              # limit TOC nesting
```

## Rules

- PDF output needs a LaTeX engine that is not installed in the host base. Do not
  install one automatically; use a project-provided engine or report the
  limitation and deliver HTML/DOCX instead.
- For Word/PowerPoint styling, edit a `--reference-doc`, don't fight raw output.
- `--embed-resources --standalone` for a single portable HTML file (email, archive).
- `--extract-media` when importing DOCX, or images get lost.
- Force formats with `-f`/`-t` when extensions are ambiguous or piping.
- `--citeproc` is required for `--bibliography` to render citations (not automatic).
- Math renders natively to LaTeX/PDF; for HTML add `--mathjax`.

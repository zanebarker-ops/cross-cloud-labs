# Interactive HTML templates

Source-of-truth doc for `.claude/interactive-diagram-template.md` and `.claude/interactive-docs-template.md` — the two reusable single-file HTML templates Claude uses when the user asks for a browser-editable diagram or document.

## 1. Purpose

Both templates produce a **single self-contained HTML file** (no build step, no external runtime dependency beyond a one-time CDN fetch for PNG export) with:

- Drag-and-drop positioning of every box / section
- Inline text editing (double-click any text to edit, Enter or click-out to commit)
- Resize handles
- Save/Load layout to `localStorage` (per-document key derived from `<title>`)
- Reset Layout to snap back to defaults
- Export PNG via `html2canvas` (pulled from CDN on first export)
- Dark theme (GitHub dark palette)

The diagram template adds:
- Auto-drawing SVG connectors between linked boxes (`data-connect-to`)
- Mandatory environment color scheme (Dev=green, Test=blue, Prod=red, etc.)

The docs template adds:
- Multiple section types (`doc-section`, `doc-table`, `doc-flow`, `doc-code`, `doc-callout`, `doc-collapse`, `doc-toc`)
- Editable tables with Add/Remove Row buttons
- Code blocks with syntax-highlighting spans and Copy button
- Auto-generated TOC from h2/h3 headings
- Auto-layout that stacks sections vertically with 20px gaps after measuring real heights

## 2. Components

| File | Purpose |
|---|---|
| `.claude/interactive-diagram-template.md` | Skeleton + skeleton CSS + JS engine for **diagrams**. ~460 lines. Use when the deliverable is a network/architecture/topology diagram. |
| `.claude/interactive-docs-template.md` | Skeleton + skeleton CSS + JS engine for **docs**. ~810 lines. Use when the deliverable is technical documentation that the user will edit and re-export. |

Both files are Markdown wrappers around an HTML skeleton. Claude copies the HTML, replaces placeholder content, and writes the result to a `.html` file.

## 3. Trigger / scope

- **User asks** for a diagram, network topology, architecture sketch, flow chart, or "something I can edit in the browser" → diagram template.
- **User asks** for documentation, runbook, decision record, technical write-up that needs to be edited and re-exported → docs template.
- For static reference architecture (this directory), Markdown is preferred over HTML — the templates are for *user-facing artifacts* like a one-off topology diagram a stakeholder will edit, not for `docs/reference-architectures/*.md` itself.

## 4. Behavior contract

When using either template, Claude must:

1. **Copy the skeleton verbatim.** Do not "improve" the JS engine inline — it's been iterated on and small changes break edit mode, drag, or PNG export.
2. **Replace placeholder content only.** Box IDs, positions, themes, and content go in the HTML body. Engine code stays.
3. **Use the environment color scheme** for any item belonging to a specific environment (Dev/Test/Prod/Collab/Hub/Firewall/EDW). Do not invent generic "route table" or "VNet" colors. The template files spell out the rule under "Environment Color Scheme (MANDATORY)".
4. **Use highlight classes correctly:**
   - `highlight-old` (red + strikethrough) only for values being directly replaced
   - `highlight-new` (green + bold) for the replacement value
   - `highlight-warn` (red + bold, no strikethrough) for warnings, references, action items — never for replacements
5. **Calculate box heights honestly** when stacking sections. The docs template includes a "Box Sizing Reference" table — a 40-line code block is ~885px tall, not 200–300px.

## 5. Cost / blast radius

Non-monetary. Failure modes:

- **Engine code edited inline:** breaks save/load, edit mode, or PNG export. Symptoms: clicking Reset Layout doesn't reset, text edits don't persist after refresh, exported PNG is blank.
- **Wrong environment color:** a Prod resource shown in green misleads the reader at a glance — the whole point of the color scheme is at-glance environment identification.
- **`highlight-old` used for non-replacements:** strikethrough on text that isn't being replaced reads as "this is wrong/deleted" — confusing when the intent was "this is important."
- **Boxes overlap because heights weren't measured:** the docs template's `autoLayout()` recovers from this on init by measuring `offsetHeight` and re-stacking, but the diagram template does not — initial overlap stays until the user drags.

## 6. Gotchas

- **`localStorage` key is derived from `<title>`.** Two diagrams with the same `<title>` will overwrite each other's saved layouts. Give every artifact a unique title.
- **PNG export hits a public CDN** (`cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js`) on first use. Air-gapped environments will see Export PNG fail silently — provide the optional Playwright-based `render-png.py` script (in the diagram template appendix) as a fallback.
- **Edit Mode is global.** Toggling it on disables drag for all boxes; toggling it off finalizes any in-progress contenteditable. Don't ship a template variant that conditionally enables edit per-box — the engine assumes a single-mode toggle.
- **The docs template's auto-TOC walks `.doc-section h2/h3`, `.doc-flow h3`, `.doc-table h3`.** Headings inside other section types won't appear in the TOC. If a new section type is added, update `generateTOC()` to include it.
- **Reset Layout in the docs template re-runs `autoLayout()` and `captureDefaults()`** — meaning if you've added boxes after init, their positions are recaptured as defaults. This is desirable for human-edited variants but surprising if you expected the original positions back.
- **The templates are large** (~460 and ~810 lines). When Claude generates output from them, that's a meaningful chunk of context. Reference them; don't paraphrase or partially reproduce.

## 7. Related files

- `.claude/interactive-diagram-template.md` — diagram template
- `.claude/interactive-docs-template.md` — docs template
- [`architecture.html`](architecture.html) — example: interactive diagram of how this `.claude/` config + reviewer subagents + hooks + routines fit together (built from the diagram template)
- [`operating-guide.md`](operating-guide.md), [`subagents.md`](subagents.md), [`hooks.md`](hooks.md), [`settings.md`](settings.md), [`routines.md`](routines.md) — sibling ref-arch docs

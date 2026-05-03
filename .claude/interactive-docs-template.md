# Interactive Technical Documentation Template

When the user asks for technical documentation that they can edit in a browser, use this template pattern. It produces a single self-contained HTML file with:

- **Drag-and-drop** sections — reorder and reposition any content block
- **Inline text editing** — double-click any text to edit (headings, paragraphs, table cells, list items)
- **Editable tables** — add/remove rows, edit cells inline
- **Flow diagrams** — box-and-connector diagrams embedded within docs
- **Code blocks** — syntax-highlighted, editable code snippets
- **Callout blocks** — info, warning, success, error alert boxes
- **Collapsible sections** — expand/collapse detail panels
- **Table of Contents** — auto-generated, clickable TOC
- **Resize handles** on every section
- **Save/Load** to localStorage (persists all edits + positions)
- **Reset Layout** to snap back to defaults
- **Export PNG** via html2canvas CDN
- **Dark theme** (GitHub dark palette)

## How to Use

1. Copy the skeleton below
2. Replace placeholder sections with actual documentation content
3. Use the section types: `doc-section`, `doc-table`, `doc-flow`, `doc-code`, `doc-callout`
4. For flow diagrams within docs, use `data-connect-to` / `data-color` on flow boxes
5. Set initial positions — spread sections vertically in a single column or use multi-column layout
6. Set canvas height large enough for all content

## Highlight Spans (IMPORTANT)

When showing before/after changes (e.g., IP address replacements), use these CSS classes:

| Class | Style | Use When |
|---|---|---|
| `highlight-old` | Red + **strikethrough** | Value is being REPLACED — must be paired with `highlight-new` showing the new value (e.g., "from ~~10.10.29.0/24~~ to **10.10.10.0/24**") |
| `highlight-new` | Green + bold | The replacement value paired with `highlight-old` |
| `highlight-warn` | Red + bold (NO strikethrough) | Warnings, standalone references to old/retiring values, action items, emphasis. NOT a replacement — just calling attention to something |

**Rule**: If the text shows `OLD → NEW`, use `highlight-old` + `highlight-new`. If the text just references a value for emphasis/warning (e.g., "DOWNTIME STARTS", "10.10.29.0/24 falls inside range", rollback instructions), use `highlight-warn`. Never strikethrough text that isn't being directly replaced.

CSS to include:
```css
.highlight-old { color: #f85149; text-decoration: line-through; }
.highlight-new { color: #3fb950; font-weight: 600; }
.highlight-warn { color: #f85149; font-weight: 700; }
```

## Section Types Reference

| Type | Class | Use For |
|---|---|---|
| Text section | `doc-section` | Headings, paragraphs, lists, general content |
| Table | `doc-table` | Data tables with editable cells |
| Flow diagram | `doc-flow` | Box-and-arrow diagrams (uses connectors) |
| Code block | `doc-code` | Code snippets, CLI commands, config examples |
| Callout | `doc-callout` + `callout-info/warn/success/error` | Alerts, notes, warnings, tips |
| Collapsible | `doc-collapse` | Expandable detail sections |
| TOC | `doc-toc` | Table of contents (auto-generated on load) |

## Skeleton HTML

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>DOC_TITLE</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: 'Segoe UI', Consolas, monospace; background: #0d1117; color: #c9d1d9; overflow: auto; }

  /* ---- Toolbar ---- */
  .toolbar { position: fixed; top: 0; left: 0; right: 0; z-index: 1000; background: #161b22; border-bottom: 1px solid #30363d; padding: 8px 20px; display: flex; align-items: center; gap: 12px; }
  .toolbar h1 { color: #58a6ff; font-size: 16px; flex: 1; }
  .toolbar button { background: #238636; color: #fff; border: none; border-radius: 6px; padding: 6px 14px; font-size: 12px; cursor: pointer; font-family: inherit; }
  .toolbar button:hover { background: #2ea043; }
  .toolbar button.secondary { background: #30363d; }
  .toolbar button.secondary:hover { background: #484f58; }
  .toolbar .info { color: #8b949e; font-size: 11px; }

  /* ---- Canvas ---- */
  .canvas { position: relative; width: 1400px; min-height: 2400px; margin: 60px auto 40px; padding: 20px; }

  /* ---- Draggable boxes (all sections) ---- */
  .box { position: absolute; border: 2px solid; border-radius: 10px; padding: 16px 18px 14px; cursor: grab; user-select: none; transition: box-shadow 0.15s; }
  .box:hover { box-shadow: 0 0 16px rgba(88,166,255,0.25); }
  .box.dragging { cursor: grabbing; box-shadow: 0 0 24px rgba(88,166,255,0.4); z-index: 500; opacity: 0.92; }
  .box.editing { cursor: text; }

  /* ---- Inline editing ---- */
  .editable-active { outline: 1px dashed #58a6ff; outline-offset: 2px; cursor: text; min-width: 20px; min-height: 1em; border-radius: 2px; background: rgba(88,166,255,0.06); }

  /* ---- Resize handle ---- */
  .resize-handle { position: absolute; bottom: 0; right: 0; width: 16px; height: 16px; cursor: nwse-resize; opacity: 0.3; }
  .resize-handle:hover { opacity: 0.7; }
  .resize-handle::after { content: ''; position: absolute; bottom: 3px; right: 3px; width: 8px; height: 8px; border-right: 2px solid #8b949e; border-bottom: 2px solid #8b949e; }

  /* ---- SVG connectors (for flow diagrams) ---- */
  svg.connectors { position: absolute; top: 0; left: 0; width: 100%; height: 100%; pointer-events: none; z-index: 0; }

  /* ==== DOCUMENT SECTION STYLES ==== */

  /* -- Generic doc section -- */
  .doc-section { border-color: #30363d; background: #161b22; }
  .doc-section h2 { color: #58a6ff; font-size: 18px; margin-bottom: 8px; border-bottom: 1px solid #21262d; padding-bottom: 6px; }
  .doc-section h3 { color: #d2a8ff; font-size: 14px; margin: 10px 0 6px; }
  .doc-section p { font-size: 13px; line-height: 1.7; color: #c9d1d9; margin-bottom: 8px; }
  .doc-section ul, .doc-section ol { font-size: 12px; color: #c9d1d9; padding-left: 20px; margin-bottom: 8px; line-height: 1.8; }
  .doc-section li { margin-bottom: 2px; }
  .doc-section strong { color: #f0f6fc; }
  .doc-section em { color: #8b949e; }
  .doc-section a { color: #58a6ff; text-decoration: none; }
  .doc-section a:hover { text-decoration: underline; }
  .doc-section .section-tag { display: inline-block; padding: 1px 6px; border-radius: 3px; font-size: 9px; font-weight: 600; margin-left: 8px; vertical-align: middle; }
  .tag-required { background: #f8514922; color: #f85149; border: 1px solid #f85149; }
  .tag-optional { background: #3fb95022; color: #3fb950; border: 1px solid #3fb950; }
  .tag-deprecated { background: #d2992222; color: #d29922; border: 1px solid #d29922; }

  /* -- Table section -- */
  .doc-table { border-color: #30363d; background: #161b22; }
  .doc-table h3 { color: #58a6ff; font-size: 14px; margin-bottom: 8px; }
  .doc-table table { width: 100%; border-collapse: collapse; font-size: 12px; }
  .doc-table th { background: #21262d; color: #f0f6fc; text-align: left; padding: 8px 10px; border: 1px solid #30363d; font-weight: 600; }
  .doc-table td { padding: 6px 10px; border: 1px solid #30363d; color: #c9d1d9; vertical-align: top; }
  .doc-table tr:hover td { background: rgba(88,166,255,0.04); }
  .doc-table .table-controls { margin-top: 6px; display: flex; gap: 6px; }
  .doc-table .table-controls button { background: #21262d; color: #8b949e; border: 1px solid #30363d; border-radius: 4px; padding: 3px 8px; font-size: 10px; cursor: pointer; font-family: inherit; }
  .doc-table .table-controls button:hover { background: #30363d; color: #c9d1d9; }

  /* -- Code block -- */
  .doc-code { border-color: #30363d; background: #0d1117; }
  .doc-code .code-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px; }
  .doc-code .code-lang { color: #8b949e; font-size: 10px; text-transform: uppercase; letter-spacing: 0.5px; }
  .doc-code .code-copy { background: #21262d; color: #8b949e; border: 1px solid #30363d; border-radius: 4px; padding: 2px 8px; font-size: 10px; cursor: pointer; }
  .doc-code .code-copy:hover { color: #c9d1d9; }
  .doc-code pre { background: #161b22; border: 1px solid #21262d; border-radius: 6px; padding: 12px 14px; overflow-x: auto; font-size: 12px; line-height: 1.6; color: #e6edf3; }
  .doc-code pre .kw { color: #ff7b72; }
  .doc-code pre .str { color: #a5d6ff; }
  .doc-code pre .cmt { color: #8b949e; font-style: italic; }
  .doc-code pre .fn { color: #d2a8ff; }
  .doc-code pre .var { color: #ffa657; }
  .doc-code pre .num { color: #79c0ff; }

  /* -- Callout blocks -- */
  .doc-callout { border-radius: 8px; }
  .doc-callout .callout-title { font-size: 12px; font-weight: 700; margin-bottom: 4px; display: flex; align-items: center; gap: 6px; }
  .doc-callout .callout-body { font-size: 12px; line-height: 1.6; }

  .callout-info    { border-color: #58a6ff; background: rgba(88,166,255,0.06); }
  .callout-info    .callout-title { color: #58a6ff; }
  .callout-info    .callout-title::before { content: 'ℹ'; }

  .callout-warn    { border-color: #d29922; background: rgba(210,153,34,0.06); }
  .callout-warn    .callout-title { color: #d29922; }
  .callout-warn    .callout-title::before { content: '⚠'; }

  .callout-success { border-color: #3fb950; background: rgba(63,185,80,0.06); }
  .callout-success .callout-title { color: #3fb950; }
  .callout-success .callout-title::before { content: '✓'; }

  .callout-error   { border-color: #f85149; background: rgba(248,81,73,0.06); }
  .callout-error   .callout-title { color: #f85149; }
  .callout-error   .callout-title::before { content: '✗'; }

  /* -- Collapsible section -- */
  .doc-collapse { border-color: #30363d; background: #161b22; }
  .doc-collapse summary { color: #58a6ff; font-size: 13px; font-weight: 600; cursor: pointer; padding: 4px 0; list-style: none; }
  .doc-collapse summary::before { content: '▶ '; font-size: 10px; color: #8b949e; }
  .doc-collapse details[open] summary::before { content: '▼ '; }
  .doc-collapse .collapse-body { margin-top: 8px; font-size: 12px; line-height: 1.7; color: #c9d1d9; }

  /* -- TOC -- */
  .doc-toc { border-color: #21262d; background: #0d1117; }
  .doc-toc h3 { color: #58a6ff; font-size: 13px; margin-bottom: 6px; }
  .doc-toc ul { list-style: none; padding: 0; }
  .doc-toc li { padding: 3px 0; font-size: 12px; }
  .doc-toc li a { color: #58a6ff; text-decoration: none; }
  .doc-toc li a:hover { text-decoration: underline; }
  .doc-toc li.toc-h2 { padding-left: 0; }
  .doc-toc li.toc-h3 { padding-left: 16px; color: #8b949e; }

  /* -- Flow diagram boxes (inside doc-flow) -- */
  .doc-flow { border-color: #30363d; background: #0d1117; }
  .doc-flow h3 { color: #58a6ff; font-size: 14px; margin-bottom: 8px; }
  .flow-box { display: inline-block; border: 2px solid; border-radius: 8px; padding: 8px 12px; font-size: 11px; text-align: center; vertical-align: middle; min-width: 100px; }
  .flow-arrow { display: inline-block; color: #8b949e; font-size: 18px; vertical-align: middle; margin: 0 8px; }
  .flow-row { display: flex; align-items: center; gap: 6px; flex-wrap: wrap; margin: 6px 0; }
  .flow-label { font-size: 9px; color: #8b949e; text-align: center; margin-top: 2px; }

  /* Flow box themes */
  .flow-blue   { border-color: #58a6ff; background: rgba(88,166,255,0.08); color: #58a6ff; }
  .flow-green  { border-color: #3fb950; background: rgba(63,185,80,0.08); color: #3fb950; }
  .flow-red    { border-color: #f85149; background: rgba(248,81,73,0.08); color: #f85149; }
  .flow-orange { border-color: #f78166; background: rgba(247,129,102,0.08); color: #f78166; }
  .flow-purple { border-color: #d2a8ff; background: rgba(210,168,255,0.08); color: #d2a8ff; }
  .flow-yellow { border-color: #d29922; background: rgba(210,153,34,0.08); color: #d29922; }
  .flow-gray   { border-color: #8b949e; background: rgba(139,148,158,0.08); color: #8b949e; }

  /* Decision diamond (use with flow-box) */
  .flow-decision { transform: rotate(0deg); border-radius: 4px; border-style: dashed; }

  /* -- Horizontal rule -- */
  .doc-hr { border: none; border-top: 1px solid #21262d; margin: 0; }

  /* -- Inline kbd -- */
  kbd { background: #21262d; border: 1px solid #30363d; border-radius: 3px; padding: 1px 5px; font-size: 11px; color: #c9d1d9; font-family: inherit; }

  /* -- Inline code -- */
  code { background: #21262d; border-radius: 3px; padding: 1px 5px; font-size: 11px; color: #f0883e; }
</style>
</head>
<body>

<div class="toolbar">
  <h1>DOC_TITLE</h1>
  <span class="info" id="mode-hint">Drag sections to reposition &bull; Double-click text to edit</span>
  <button class="secondary" id="editToggle" onclick="toggleEditMode()">Edit Mode: OFF</button>
  <button class="secondary" onclick="resetPositions()">Reset Layout</button>
  <button class="secondary" onclick="saveLayout()">Save Layout</button>
  <button onclick="exportPNG()">Export PNG</button>
</div>

<div class="canvas" id="canvas">

  <svg class="connectors" id="connectorSvg">
    <defs>
      <marker id="arr-gray" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto"><polygon points="0 0,8 3,0 6" fill="#8b949e"/></marker>
      <marker id="arr-green" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto"><polygon points="0 0,8 3,0 6" fill="#3fb950"/></marker>
      <marker id="arr-blue" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto"><polygon points="0 0,8 3,0 6" fill="#58a6ff"/></marker>
      <marker id="arr-red" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto"><polygon points="0 0,8 3,0 6" fill="#f85149"/></marker>
      <marker id="arr-purple" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto"><polygon points="0 0,8 3,0 6" fill="#d2a8ff"/></marker>
      <marker id="arr-orange" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto"><polygon points="0 0,8 3,0 6" fill="#f78166"/></marker>
    </defs>
  </svg>

  <!--
    ============================================================
    TABLE OF CONTENTS — Auto-generated from h2 elements on load.
    Or manually list anchors.
    ============================================================
  -->
  <div class="box doc-toc" id="toc" style="left:40px; top:20px; width:300px;">
    <h3>Table of Contents</h3>
    <ul id="toc-list">
      <!-- Auto-populated by JS, or add manual entries -->
    </ul>
    <div class="resize-handle"></div>
  </div>

  <!--
    ============================================================
    SECTION TEMPLATES — Copy these blocks for each doc section.
    ============================================================
  -->

  <!-- === TEXT SECTION === -->
  <div class="box doc-section" id="section-overview" style="left:40px; top:200px; width:700px;">
    <h2>1. Overview</h2>
    <p>Replace this with your overview content. This section supports <strong>bold</strong>, <em>italic</em>, <code>inline code</code>, and <kbd>keyboard</kbd> formatting.</p>
    <h3>Sub-heading</h3>
    <p>Additional paragraph with details. All text is editable — double-click to modify.</p>
    <ul>
      <li>Bullet point one</li>
      <li>Bullet point two</li>
      <li>Bullet point three</li>
    </ul>
    <div class="resize-handle"></div>
  </div>

  <!-- === TABLE SECTION === -->
  <div class="box doc-table" id="section-table" style="left:40px; top:520px; width:700px;">
    <h3>Parameters / Configuration</h3>
    <table>
      <thead>
        <tr><th>Name</th><th>Type</th><th>Required</th><th>Description</th></tr>
      </thead>
      <tbody>
        <tr><td>param_one</td><td>string</td><td>Yes</td><td>Description of parameter one</td></tr>
        <tr><td>param_two</td><td>integer</td><td>No</td><td>Description of parameter two</td></tr>
        <tr><td>param_three</td><td>boolean</td><td>No</td><td>Description of parameter three</td></tr>
      </tbody>
    </table>
    <div class="table-controls">
      <button onclick="addTableRow(this)">+ Add Row</button>
      <button onclick="removeTableRow(this)">- Remove Last Row</button>
    </div>
    <div class="resize-handle"></div>
  </div>

  <!-- === CODE BLOCK === -->
  <div class="box doc-code" id="section-code" style="left:40px; top:780px; width:700px;">
    <div class="code-header">
      <span class="code-lang">bash</span>
      <button class="code-copy" onclick="copyCode(this)">Copy</button>
    </div>
    <pre><span class="cmt"># Example command</span>
az network vnet create \
  --name <span class="str">vnet-example</span> \
  --resource-group <span class="var">$RG_NAME</span> \
  --address-prefix <span class="str">10.0.0.0/16</span> \
  --subnet-name <span class="str">default</span> \
  --subnet-prefix <span class="str">10.0.0.0/24</span></pre>
    <div class="resize-handle"></div>
  </div>

  <!-- === CALLOUT — INFO === -->
  <div class="box doc-callout callout-info" id="callout-info" style="left:40px; top:1000px; width:700px;">
    <div class="callout-title">Note</div>
    <div class="callout-body">This is an informational callout. Use it for tips, notes, and general guidance that the reader should be aware of.</div>
    <div class="resize-handle"></div>
  </div>

  <!-- === CALLOUT — WARNING === -->
  <div class="box doc-callout callout-warn" id="callout-warn" style="left:40px; top:1100px; width:700px;">
    <div class="callout-title">Warning</div>
    <div class="callout-body">This is a warning callout. Use it for potential pitfalls, breaking changes, or actions that require caution.</div>
    <div class="resize-handle"></div>
  </div>

  <!-- === CALLOUT — SUCCESS === -->
  <div class="box doc-callout callout-success" id="callout-success" style="left:40px; top:1190px; width:700px;">
    <div class="callout-title">Success</div>
    <div class="callout-body">This is a success callout. Use it for expected outcomes, verification steps, or completed milestones.</div>
    <div class="resize-handle"></div>
  </div>

  <!-- === CALLOUT — ERROR === -->
  <div class="box doc-callout callout-error" id="callout-error" style="left:40px; top:1280px; width:700px;">
    <div class="callout-title">Error</div>
    <div class="callout-body">This is an error callout. Use it for known issues, failure modes, or things to avoid.</div>
    <div class="resize-handle"></div>
  </div>

  <!-- === FLOW DIAGRAM (inline arrows) === -->
  <div class="box doc-flow" id="section-flow" style="left:40px; top:1400px; width:700px;">
    <h3>Process Flow</h3>
    <div class="flow-row">
      <div class="flow-box flow-blue">Step 1<br/><span class="flow-label">Description</span></div>
      <span class="flow-arrow">→</span>
      <div class="flow-box flow-green">Step 2<br/><span class="flow-label">Description</span></div>
      <span class="flow-arrow">→</span>
      <div class="flow-box flow-decision flow-yellow">Decision?<br/><span class="flow-label">Yes / No</span></div>
      <span class="flow-arrow">→</span>
      <div class="flow-box flow-purple">Step 3<br/><span class="flow-label">Description</span></div>
      <span class="flow-arrow">→</span>
      <div class="flow-box flow-red">Done<br/><span class="flow-label">Result</span></div>
    </div>
    <div class="resize-handle"></div>
  </div>

  <!-- === COLLAPSIBLE SECTION === -->
  <div class="box doc-collapse" id="section-collapse" style="left:40px; top:1560px; width:700px;">
    <details>
      <summary>Expand: Additional Details</summary>
      <div class="collapse-body">
        <p>This content is hidden by default. Click the summary to expand. Use collapsible sections for supplementary info, troubleshooting steps, or verbose output examples.</p>
        <p>You can nest any content here — tables, code, lists, etc.</p>
        <ul>
          <li>Detail item one</li>
          <li>Detail item two</li>
          <li>Detail item three</li>
        </ul>
      </div>
    </details>
    <div class="resize-handle"></div>
  </div>

  <!--
    ============================================================
    FLOW DIAGRAM (box-and-connector style) — Use data-connect-to
    for auto-drawn SVG lines, same as network diagram template.
    Place these boxes anywhere on the canvas.
    ============================================================
  -->

  <!-- Example: standalone flow boxes with connectors
  <div class="box doc-section" id="flow-a" style="left:800px; top:200px; width:200px;"
       data-connect-to="flow-b" data-color="#58a6ff" data-label="triggers">
    <h3 style="color:#58a6ff; font-size:13px;">Service A</h3>
    <p style="font-size:11px;">Handles ingestion</p>
    <div class="resize-handle"></div>
  </div>
  <div class="box doc-section" id="flow-b" style="left:1100px; top:200px; width:200px;">
    <h3 style="color:#3fb950; font-size:13px;">Service B</h3>
    <p style="font-size:11px;">Processes data</p>
    <div class="resize-handle"></div>
  </div>
  -->

</div><!-- end canvas -->

<script>
// ====================================================================
// CORE ENGINE — Drag, Resize, Edit, Connectors, Save/Load, Export
// Plus: Table controls, TOC generation, Code copy
// ====================================================================
const canvas = document.getElementById('canvas');
const boxes = document.querySelectorAll('.box');
const svg = document.getElementById('connectorSvg');
const STORAGE_KEY = 'doc-layout-' + document.title.replace(/\W+/g, '-').substring(0, 40);

let dragState = null;
let resizeState = null;
let editMode = false;

// --- Default positions (for reset) ---
const defaultPositions = {};
const defaultHTML = {};
boxes.forEach(box => {
  defaultPositions[box.id] = { left: box.style.left, top: box.style.top, width: box.style.width };
  defaultHTML[box.id] = box.innerHTML;
});

// --- Layout persistence ---
function loadLayout() {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (!saved) return;
    const layout = JSON.parse(saved);
    boxes.forEach(box => {
      if (layout[box.id]) {
        box.style.left = layout[box.id].left;
        box.style.top = layout[box.id].top;
        if (layout[box.id].width) box.style.width = layout[box.id].width;
      }
    });
  } catch(e) {}
}

function loadContent() {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (!saved) return;
    const layout = JSON.parse(saved);
    boxes.forEach(box => {
      if (layout[box.id] && layout[box.id].html) {
        box.innerHTML = layout[box.id].html;
      }
    });
  } catch(e) {}
}

function saveLayout() {
  const layout = {};
  boxes.forEach(box => {
    layout[box.id] = {
      left: box.style.left, top: box.style.top, width: box.style.width,
      html: box.innerHTML
    };
  });
  localStorage.setItem(STORAGE_KEY, JSON.stringify(layout));
  showToast('Layout + text edits saved');
}

function resetPositions() {
  boxes.forEach(box => {
    if (defaultPositions[box.id]) {
      box.style.left = defaultPositions[box.id].left;
      box.style.top = defaultPositions[box.id].top;
      box.style.width = defaultPositions[box.id].width;
    }
    if (defaultHTML[box.id]) {
      box.innerHTML = defaultHTML[box.id];
    }
  });
  localStorage.removeItem(STORAGE_KEY);
  autoLayout();
  captureDefaults();
  drawConnectors();
  generateTOC();
  showToast('Layout and content reset to default');
}

// --- Toast ---
function showToast(msg) {
  const t = document.createElement('div');
  t.textContent = msg;
  Object.assign(t.style, {
    position:'fixed', bottom:'20px', left:'50%', transform:'translateX(-50%)',
    background:'#238636', color:'#fff', padding:'8px 20px', borderRadius:'6px',
    fontSize:'13px', zIndex:'9999', fontFamily:'inherit'
  });
  document.body.appendChild(t);
  setTimeout(() => t.remove(), 2000);
}

// --- Drag ---
boxes.forEach(box => {
  box.addEventListener('mousedown', (e) => {
    if (e.target.classList.contains('resize-handle')) {
      resizeState = { box, startX: e.clientX, startWidth: box.offsetWidth };
      box.classList.add('dragging');
      e.preventDefault();
      return;
    }
    if (e.target.tagName === 'BUTTON' || e.target.tagName === 'SUMMARY' || e.target.tagName === 'A') return;
    if (editMode) return;
    const rect = box.getBoundingClientRect();
    dragState = { box, offsetX: e.clientX - rect.left, offsetY: e.clientY - rect.top };
    box.classList.add('dragging');
    e.preventDefault();
  });
});

document.addEventListener('mousemove', (e) => {
  if (dragState) {
    const r = canvas.getBoundingClientRect();
    dragState.box.style.left = Math.max(0, e.clientX - r.left - dragState.offsetX + canvas.scrollLeft) + 'px';
    dragState.box.style.top = Math.max(0, e.clientY - r.top - dragState.offsetY + canvas.scrollTop) + 'px';
    drawConnectors();
  }
  if (resizeState) {
    resizeState.box.style.width = Math.max(200, resizeState.startWidth + e.clientX - resizeState.startX) + 'px';
    drawConnectors();
  }
});

document.addEventListener('mouseup', () => {
  if (dragState) { dragState.box.classList.remove('dragging'); dragState = null; }
  if (resizeState) { resizeState.box.classList.remove('dragging'); resizeState = null; }
});

// --- Connectors ---
function getCenter(el) {
  return { x: (parseFloat(el.style.left)||0) + el.offsetWidth/2, y: (parseFloat(el.style.top)||0) + el.offsetHeight/2 };
}
function getEdgePoint(el, tc) {
  const l=parseFloat(el.style.left)||0, t=parseFloat(el.style.top)||0, w=el.offsetWidth, h=el.offsetHeight;
  const cx=l+w/2, cy=t+h/2, dx=tc.x-cx, dy=tc.y-cy, ax=Math.abs(dx), ay=Math.abs(dy);
  if (ax*h > ay*w) { const s=dx>0?1:-1; return {x:cx+s*w/2, y:cy+dy*(w/2)/ax}; }
  else { const s=dy>0?1:-1; return {x:cx+dx*(h/2)/ay, y:cy+s*h/2}; }
}
function drawConnectors() {
  svg.querySelectorAll('line, text.conn-label').forEach(el => el.remove());
  boxes.forEach(box => {
    const tid = box.dataset.connectTo;
    if (!tid) return;
    const target = document.getElementById(tid);
    if (!target) return;
    const color = box.dataset.color || '#8b949e';
    const label = box.dataset.label || '';
    const from = getEdgePoint(box, getCenter(target));
    const to = getEdgePoint(target, getCenter(box));
    let mc = 'gray';
    if (color.includes('3fb950')) mc='green'; else if (color.includes('58a6ff')) mc='blue';
    else if (color.includes('f85149')) mc='red'; else if (color.includes('d2a8ff')) mc='purple';
    else if (color.includes('f78166')) mc='orange';
    const line = document.createElementNS('http://www.w3.org/2000/svg','line');
    line.setAttribute('x1',from.x); line.setAttribute('y1',from.y);
    line.setAttribute('x2',to.x); line.setAttribute('y2',to.y);
    line.setAttribute('stroke',color); line.setAttribute('stroke-dasharray','6,3');
    line.setAttribute('stroke-width','2'); line.setAttribute('marker-end',`url(#arr-${mc})`);
    svg.appendChild(line);
    if (label) {
      const txt = document.createElementNS('http://www.w3.org/2000/svg','text');
      txt.classList.add('conn-label');
      txt.setAttribute('x',(from.x+to.x)/2); txt.setAttribute('y',(from.y+to.y)/2-6);
      txt.setAttribute('fill',color); txt.setAttribute('font-size','10');
      txt.setAttribute('font-family',"'Segoe UI',Consolas,monospace");
      txt.setAttribute('text-anchor','middle'); txt.textContent=label;
      svg.appendChild(txt);
    }
  });
}

// --- Edit Mode ---
function toggleEditMode() {
  editMode = !editMode;
  const btn = document.getElementById('editToggle');
  const hint = document.getElementById('mode-hint');
  if (editMode) {
    btn.textContent = 'Edit Mode: ON'; btn.style.background = '#238636'; btn.style.color = '#fff';
    hint.textContent = 'EDIT MODE — Double-click any text to edit. Click elsewhere to finish.';
    boxes.forEach(b => b.style.cursor = 'text');
  } else {
    btn.textContent = 'Edit Mode: OFF'; btn.style.background = '#30363d'; btn.style.color = '';
    hint.innerHTML = 'Drag sections to reposition &bull; Double-click text to edit';
    boxes.forEach(b => b.style.cursor = 'grab');
    document.querySelectorAll('[contenteditable="true"]').forEach(el => {
      el.removeAttribute('contenteditable'); el.classList.remove('editable-active');
    });
  }
}

canvas.addEventListener('dblclick', (e) => {
  const target = e.target;
  if (target.classList.contains('resize-handle') || target.classList.contains('box') ||
      target.closest('svg') || target.tagName === 'BUTTON' || target.tagName === 'SUMMARY') return;
  if (!editMode) toggleEditMode();
  const el = target.closest('h2, h3, h4, p, li, td, th, span, strong, em, div.callout-title, div.callout-body, div.collapse-body, pre, div.flow-box, div.flow-label, code');
  if (!el || el.classList.contains('box') || el.classList.contains('canvas')) return;
  if (el.getAttribute('contenteditable') === 'true') return;
  el.setAttribute('contenteditable', 'true');
  el.classList.add('editable-active');
  el.focus();
  const sel = window.getSelection(), range = document.createRange();
  range.selectNodeContents(el); sel.removeAllRanges(); sel.addRange(range);
  e.stopPropagation(); e.preventDefault();
  const finish = () => { el.removeAttribute('contenteditable'); el.classList.remove('editable-active'); el.removeEventListener('blur',finish); el.removeEventListener('keydown',onKey); };
  const onKey = (ke) => { if (ke.key==='Escape') el.blur(); };
  el.addEventListener('blur', finish); el.addEventListener('keydown', onKey);
});

// --- Table controls ---
function addTableRow(btn) {
  const table = btn.closest('.doc-table').querySelector('table');
  const cols = table.querySelector('thead tr').children.length;
  const row = table.querySelector('tbody').insertRow();
  for (let i = 0; i < cols; i++) {
    const cell = row.insertCell();
    cell.textContent = '—';
  }
}

function removeTableRow(btn) {
  const tbody = btn.closest('.doc-table').querySelector('tbody');
  if (tbody.rows.length > 1) tbody.deleteRow(tbody.rows.length - 1);
}

// --- Code copy ---
function copyCode(btn) {
  const pre = btn.closest('.doc-code').querySelector('pre');
  const text = pre.innerText || pre.textContent;
  navigator.clipboard.writeText(text).then(() => {
    btn.textContent = 'Copied!';
    setTimeout(() => btn.textContent = 'Copy', 1500);
  });
}

// --- TOC generation ---
function generateTOC() {
  const tocList = document.getElementById('toc-list');
  if (!tocList) return;
  tocList.innerHTML = '';
  const headings = canvas.querySelectorAll('.doc-section h2, .doc-section h3, .doc-flow h3, .doc-table h3, .doc-code .code-lang');
  headings.forEach(h => {
    if (h.classList.contains('code-lang')) return;
    const li = document.createElement('li');
    li.className = h.tagName === 'H2' ? 'toc-h2' : 'toc-h3';
    const a = document.createElement('a');
    a.textContent = h.textContent;
    const parentBox = h.closest('.box');
    if (parentBox) {
      a.href = '#';
      a.onclick = (e) => {
        e.preventDefault();
        parentBox.scrollIntoView({ behavior: 'smooth', block: 'start' });
        parentBox.style.boxShadow = '0 0 24px rgba(88,166,255,0.5)';
        setTimeout(() => parentBox.style.boxShadow = '', 1500);
      };
    }
    li.appendChild(a);
    tocList.appendChild(li);
  });
}

// --- PNG Export ---
async function exportPNG() {
  showToast('Generating PNG...');
  try {
    if (!window.html2canvas) {
      const s = document.createElement('script');
      s.src = 'https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js';
      document.head.appendChild(s);
      await new Promise((res, rej) => { s.onload=res; s.onerror=rej; });
    }
    const c = await html2canvas(document.getElementById('canvas'), { backgroundColor:'#0d1117', scale:2, useCORS:true, logging:false });
    const a = document.createElement('a');
    a.download = document.title.replace(/\W+/g,'-') + '.png';
    a.href = c.toDataURL('image/png'); a.click();
    showToast('PNG downloaded!');
  } catch(err) { showToast('Export failed: '+err.message); }
}

// --- Auto-layout: measure actual box heights, stack with 20px gaps ---
function autoLayout() {
  const GAP = 20;
  const toc = document.getElementById('toc');
  const header = document.getElementById('section-header');
  // Collect main-column boxes, excluding side-by-side TOC and header
  const mainBoxes = Array.from(boxes).filter(b => b !== toc && b !== header);
  // Sort by original top value (ascending)
  mainBoxes.sort((a, b) => (parseFloat(a.style.top)||0) - (parseFloat(b.style.top)||0));
  // Start below the taller of TOC or header
  const tocBottom = toc ? (parseFloat(toc.style.top)||0) + toc.offsetHeight : 0;
  const headerBottom = header ? (parseFloat(header.style.top)||0) + header.offsetHeight : 0;
  let cursor = Math.max(tocBottom, headerBottom) + GAP;
  mainBoxes.forEach(box => {
    box.style.top = cursor + 'px';
    cursor += box.offsetHeight + GAP;
  });
  // Update canvas height
  canvas.style.minHeight = (cursor + 100) + 'px';
}
// Store defaults AFTER auto-layout so Reset uses correct positions
function captureDefaults() {
  boxes.forEach(box => {
    defaultPositions[box.id] = { left: box.style.left, top: box.style.top, width: box.style.width };
  });
}

// --- Init ---
generateTOC();    // populate TOC first so its offsetHeight is accurate
autoLayout();     // measure all boxes and stack them with 20px gaps
captureDefaults();
loadLayout();
loadContent();
drawConnectors();
window.addEventListener('resize', drawConnectors);
</script>
</body>
</html>
```

## Quick Reference

| Feature | How |
|---|---|
| **Text section** | `<div class="box doc-section" id="..." style="left:Xpx; top:Ypx; width:Wpx;">` with `<h2>`, `<h3>`, `<p>`, `<ul>` inside |
| **Table** | `<div class="box doc-table" ...>` with `<table>` + Add/Remove Row buttons |
| **Code block** | `<div class="box doc-code" ...>` with `<pre>` — use `.kw`, `.str`, `.cmt`, `.fn`, `.var`, `.num` spans for highlighting |
| **Callout** | `<div class="box doc-callout callout-info/warn/success/error" ...>` |
| **Collapsible** | `<div class="box doc-collapse" ...>` with `<details><summary>` |
| **Flow (inline)** | `<div class="box doc-flow" ...>` with `.flow-row > .flow-box + .flow-arrow` |
| **Flow (connector)** | Use separate `.box` elements with `data-connect-to`, `data-color`, `data-label` (same as diagram template) |
| **TOC** | `<div class="box doc-toc" id="toc" ...>` — auto-generated from h2/h3 elements |
| **Tags** | `<span class="section-tag tag-required">Required</span>`, `tag-optional`, `tag-deprecated` |
| **Add table row** | `<button onclick="addTableRow(this)">+ Add Row</button>` inside `.table-controls` |
| **Copy code** | `<button class="code-copy" onclick="copyCode(this)">Copy</button>` inside `.code-header` |

## Box Sizing Reference

When setting `top:` positions for boxes, calculate the cumulative height to avoid overlaps. Use these estimates:

### Base overhead (every box)
- Box padding + border: **34px** (16px top + 14px bottom padding + 4px border)

### Content heights
| Element | Height per unit | Notes |
|---|---|---|
| `h2` heading | **33px** | includes margin-bottom and border |
| `h3` heading | **28px** | includes margin |
| `p` paragraph | **30px** per line | font 13px, line-height 1.7, plus margin |
| `ul/ol` list item | **22px** per item | font 12px, line-height 1.8 |
| Table header row | **33px** | with padding |
| Table data row | **28px** per row | with padding |
| Table controls | **30px** | add/remove buttons |
| Code line (`<pre>`) | **20px** per line | font 12px, line-height 1.6 |
| Code `<pre>` padding | **26px** | 12px top + 12px bottom + 2px border |
| Code header | **25px** | language label + copy button |
| Callout title | **18px** | |
| Callout body line | **20px** per line | |
| Flow row | **50px** per row | flow-box height + margins |
| Resize handle | **0px** | overlaps box padding, no extra height |

### Minimum gap between boxes: **20px**

### Quick formulas
- **Heading-only box:** ~70px (h2/h3 + base)
- **Callout (1 line):** ~75px (title + body + base)
- **Table box:** 34 + 28 (h3) + 33 (thead) + 28*N (rows) + 30 (controls) = **125 + 28*N px**
- **Code block:** 34 + 25 (header) + 26 (pre padding) + 20*L (lines) = **85 + 20*L px**
- **Text section:** 34 + 33 (h2) + 30*P (paragraphs) + 22*I (list items) = **67 + 30*P + 22*I px**

### Example calculation
A code block with 40 lines of bash:
- Height = 85 + 20*40 = **885px**
- If this box starts at top:2000px, the next box should start at top:**2905px** (2000 + 885 + 20 gap)

### Common mistake
Do NOT estimate code blocks as ~200-300px. A 40-line code block is ~885px tall. A 68-line code block is ~1445px tall. Always count the actual lines in `<pre>` content.

## Environment Color Scheme (MANDATORY — for docs that reference environments)

When documentation includes flow diagrams, tables, or callouts that are environment-specific, use the environment's color — not a generic type color. For example, a flow step about "Dev Shared Cutover" should be green (Dev), not just any color.

| Environment | Color | Hex | Use For |
|---|---|---|---|
| **Dev** | Green | `#3fb950` | Any Dev-specific content, flow steps, highlights |
| **Test** | Blue | `#58a6ff` | Any Test-specific content |
| **Prod** | Red | `#f85149` | Any Prod-specific content |
| **Collab/DBW** | Purple | `#d2a8ff` | Collab/Databricks-specific content |
| **Hub** | Orange | `#f78166` | Hub/gateway-specific content |
| **Firewall** | Yellow | `#d29922` | Firewall-specific content |

**Rule**: If a flow step or callout is about a specific environment, use that environment's color. Generic workflow steps (pre-flight, validate, etc.) can use any appropriate color. But "Deploy Dev Route Table" = green, "Deploy Prod Route Table" = red.

## Design Guidelines

1. **Spread boxes out** — use the Box Sizing Reference above to calculate correct positions. Minimum 20px gap between all boxes. Code blocks and large tables need hundreds of pixels — always count lines.
2. **Use TOC** for documents with 3+ sections — it auto-generates from h2/h3 headings
3. **Place flow diagrams inline** (using `.flow-row`) for simple linear flows
4. **Use connector-style flows** (separate boxes with `data-connect-to`) for complex architectures
5. **Callouts** should be used sparingly — one per key point, not for every paragraph
6. **Collapsible sections** are ideal for troubleshooting, verbose logs, or optional detail
7. **Tables** should have Add/Remove Row buttons for editability
8. **Code blocks** should specify language in `.code-lang` and include Copy button
9. **Canvas width 1400px** is good for doc-style reading; increase for side-by-side layouts
10. **localStorage key** is auto-derived from `<title>` so multiple docs don't conflict
11. **Color by environment** — when content is environment-specific, use the Environment Color Scheme above

## Differences from Diagram Template

| Aspect | Diagram Template | Docs Template |
|---|---|---|
| Primary use | Network/architecture diagrams | Technical documentation |
| Layout | Free-form positioned boxes | Column-based stacked sections |
| Content types | VNet boxes, route tables, legends | Headings, paragraphs, tables, code, callouts |
| Connectors | Primary feature (VNet peering lines) | Optional (for embedded flow diagrams) |
| Canvas width | 3200px (wide for spreading) | 1400px (reading width) |
| Table editing | View-only | Add/Remove rows, edit cells |
| Code blocks | Not included | Syntax highlighting + Copy button |
| TOC | Not included | Auto-generated from headings |
| Collapsible | Not included | `<details>/<summary>` sections |

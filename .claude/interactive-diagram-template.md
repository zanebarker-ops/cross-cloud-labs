# Interactive HTML Diagram Template

When the user asks for a diagram (network, architecture, flow, etc.) that they can edit in a browser, use this template pattern. It produces a single self-contained HTML file with:

- **Drag-and-drop** positioning of all boxes
- **Inline text editing** (double-click any text, toggle Edit Mode)
- **Resize handles** on every box (bottom-right corner)
- **Auto-drawing SVG connectors** between linked boxes
- **Save/Load layout** to localStorage (persists positions + text edits)
- **Reset Layout** to snap back to defaults
- **Export PNG** via html2canvas CDN
- **Dark theme** (GitHub dark palette)

## How to Use

1. Copy the skeleton below
2. Replace the placeholder boxes with actual content
3. Set `data-connect-to="targetId"` and `data-color="#hex"` on boxes that need connector lines
4. Adjust initial `left`, `top`, `width` values to spread boxes out (avoid overlap)
5. Set canvas width/height large enough for all content

## Skeleton HTML

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>DIAGRAM_TITLE</title>
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
  .canvas { position: relative; width: 3200px; height: 2400px; margin-top: 50px; }

  /* ---- Draggable boxes ---- */
  .box { position: absolute; border: 2px solid; border-radius: 10px; padding: 12px 10px 10px; cursor: grab; user-select: none; transition: box-shadow 0.15s; }
  .box:hover { box-shadow: 0 0 16px rgba(88,166,255,0.25); }
  .box.dragging { cursor: grabbing; box-shadow: 0 0 24px rgba(88,166,255,0.4); z-index: 500; opacity: 0.92; }
  .box.editing { cursor: text; }

  /* ---- Inline editing ---- */
  .editable-active { outline: 1px dashed #58a6ff; outline-offset: 2px; cursor: text; min-width: 20px; min-height: 1em; border-radius: 2px; background: rgba(88,166,255,0.06); }

  /* ---- Common element styles ---- */
  .box-label { font-weight: bold; font-size: 13px; margin-bottom: 2px; }
  .detail { font-size: 11px; color: #8b949e; margin-bottom: 6px; }

  /* ---- Resize handle ---- */
  .resize-handle { position: absolute; bottom: 0; right: 0; width: 16px; height: 16px; cursor: nwse-resize; opacity: 0.3; }
  .resize-handle:hover { opacity: 0.7; }
  .resize-handle::after { content: ''; position: absolute; bottom: 3px; right: 3px; width: 8px; height: 8px; border-right: 2px solid #8b949e; border-bottom: 2px solid #8b949e; }

  /* ---- SVG connectors ---- */
  svg.connectors { position: absolute; top: 0; left: 0; width: 100%; height: 100%; pointer-events: none; z-index: 0; }

  /* ---- Tags ---- */
  .tag { display: inline-block; padding: 1px 4px; border-radius: 3px; font-size: 10px; font-weight: 600; }
  .tag-new { background: #f0883e22; color: #f0883e; border: 1px solid #f0883e; }
  .tag-existing { background: #3fb95022; color: #3fb950; border: 1px solid #3fb950; }

  /*
   * COLOR THEMES — add as many as needed. Apply via class on .box elements.
   * Pattern:  .mytheme { border-color: #HEX; background: rgba(r,g,b,0.04); }
   *           .mytheme .box-label { color: #HEX; }
   */
  .theme-blue    { border-color: #58a6ff; background: rgba(88,166,255,0.04); }
  .theme-blue    .box-label { color: #58a6ff; }
  .theme-green   { border-color: #3fb950; background: rgba(63,185,80,0.04); }
  .theme-green   .box-label { color: #3fb950; }
  .theme-red     { border-color: #f85149; background: rgba(248,81,73,0.04); }
  .theme-red     .box-label { color: #f85149; }
  .theme-orange  { border-color: #f78166; background: rgba(247,129,102,0.06); }
  .theme-orange  .box-label { color: #f78166; }
  .theme-purple  { border-color: #d2a8ff; background: rgba(210,168,255,0.04); }
  .theme-purple  .box-label { color: #d2a8ff; }
  .theme-yellow  { border-color: #d29922; background: rgba(210,153,34,0.04); }
  .theme-yellow  .box-label { color: #d29922; }
  .theme-gray    { border-color: #8b949e; background: rgba(139,148,158,0.05); }
  .theme-gray    .box-label { color: #8b949e; }
  .theme-info    { border-color: #30363d; background: #161b22; }
  .theme-info h4 { font-size: 12px; color: #58a6ff; margin-bottom: 4px; }
</style>
</head>
<body>

<div class="toolbar">
  <h1>DIAGRAM_TITLE</h1>
  <span class="info" id="mode-hint">Drag boxes to reposition &bull; Double-click text to edit</span>
  <button class="secondary" id="editToggle" onclick="toggleEditMode()">Edit Mode: OFF</button>
  <button class="secondary" onclick="resetPositions()">Reset Layout</button>
  <button class="secondary" onclick="saveLayout()">Save Layout</button>
  <button onclick="exportPNG()">Export PNG</button>
</div>

<div class="canvas" id="canvas">

  <!-- SVG connector layer (auto-drawn by JS) -->
  <svg class="connectors" id="connectorSvg">
    <defs>
      <!-- Add marker arrows for each color you use -->
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
    BOX TEMPLATE — Copy this block for each element in the diagram.

    REQUIRED attributes:
      id="unique-id"              — unique ID for this box
      style="left:Xpx; top:Ypx; width:Wpx;"  — initial position

    OPTIONAL attributes (for auto-drawn connectors):
      data-connect-to="target-id" — draw a line to another box
      data-color="#hex"           — connector line color
      data-label="text"          — label shown on the connector midpoint

    Apply a theme class: theme-blue, theme-green, theme-red, etc.
    ============================================================
  -->

  <!-- EXAMPLE BOX -->
  <div class="box theme-blue" id="example-box" style="left:100px; top:100px; width:300px;"
       data-connect-to="another-box" data-color="#58a6ff" data-label="connects to">
    <div class="box-label">Box Title</div>
    <div class="detail">Subtitle or description text</div>
    <!-- Add any HTML content inside -->
    <div class="resize-handle"></div>
  </div>

  <!-- ANOTHER BOX (target of connector) -->
  <div class="box theme-green" id="another-box" style="left:500px; top:100px; width:300px;">
    <div class="box-label">Another Box</div>
    <div class="detail">More details here</div>
    <div class="resize-handle"></div>
  </div>

</div><!-- end canvas -->

<script>
// ====================================================================
// CORE ENGINE — Drag, Resize, Edit, Connectors, Save/Load, Export
// Do NOT modify this section. Just update the HTML boxes above.
// ====================================================================
const canvas = document.getElementById('canvas');
const boxes = document.querySelectorAll('.box');
const svg = document.getElementById('connectorSvg');
const STORAGE_KEY = 'diagram-layout-' + document.title.replace(/\W+/g, '-').substring(0, 40);

let dragState = null;
let resizeState = null;
let editMode = false;

// --- Default positions (for reset) ---
const defaultPositions = {};
boxes.forEach(box => {
  defaultPositions[box.id] = { left: box.style.left, top: box.style.top, width: box.style.width };
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
  });
  localStorage.removeItem(STORAGE_KEY);
  drawConnectors();
  showToast('Layout reset to default');
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
    hint.innerHTML = 'Drag boxes to reposition &bull; Double-click text to edit';
    boxes.forEach(b => b.style.cursor = 'grab');
    document.querySelectorAll('[contenteditable="true"]').forEach(el => {
      el.removeAttribute('contenteditable'); el.classList.remove('editable-active');
    });
  }
}

canvas.addEventListener('dblclick', (e) => {
  const target = e.target;
  if (target.classList.contains('resize-handle') || target.classList.contains('box') ||
      target.closest('svg') || target.tagName === 'BUTTON' || target.closest('.legend-swatch')) return;
  if (!editMode) toggleEditMode();
  const el = target.closest('.box-label, .detail, h3, h4, div, span, strong, td, th');
  if (!el || el.classList.contains('box')) return;
  if (el.getAttribute('contenteditable') === 'true') return;
  el.setAttribute('contenteditable', 'true');
  el.classList.add('editable-active');
  el.focus();
  const sel = window.getSelection(), range = document.createRange();
  range.selectNodeContents(el); sel.removeAllRanges(); sel.addRange(range);
  e.stopPropagation(); e.preventDefault();
  const finish = () => { el.removeAttribute('contenteditable'); el.classList.remove('editable-active'); el.removeEventListener('blur',finish); el.removeEventListener('keydown',onKey); };
  const onKey = (ke) => { if (ke.key==='Enter'&&!ke.shiftKey){ke.preventDefault();el.blur();} if (ke.key==='Escape') el.blur(); };
  el.addEventListener('blur', finish); el.addEventListener('keydown', onKey);
});

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

// --- Init ---
loadLayout();
loadContent();
drawConnectors();
window.addEventListener('resize', drawConnectors);
</script>
</body>
</html>
```

## PNG Rendering Script (optional — for server-side export)

If the user wants a PNG file generated locally (not via browser), create this helper:

```python
# render-png.py — uses Playwright to screenshot the HTML
from playwright.sync_api import sync_playwright
import os, sys

html_path = sys.argv[1] if len(sys.argv) > 1 else "diagram.html"
png_path = html_path.rsplit(".", 1)[0] + ".png"

with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page(viewport={"width": 1750, "height": 2000})
    page.goto("file:///" + os.path.abspath(html_path).replace("\\", "/"))
    page.wait_for_timeout(1000)
    height = page.evaluate("document.body.scrollHeight")
    page.set_viewport_size({"width": 1750, "height": height + 50})
    page.screenshot(path=png_path, full_page=True)
    browser.close()
    print(f"PNG saved: {png_path} ({os.path.getsize(png_path)} bytes)")
```

Run with: `python render-png.py path/to/diagram.html`

## Highlight Spans (IMPORTANT)

When showing before/after changes in diagrams (e.g., IP address replacements, renamed resources):

| Class | Style | Use When |
|---|---|---|
| `highlight-old` | Red + **strikethrough** | Value is being REPLACED — paired with `highlight-new` |
| `highlight-new` | Green + bold | The replacement value |
| `highlight-warn` | Red + bold (NO strikethrough) | Warnings, standalone references, emphasis — NOT a replacement |

**Rule**: Only use `highlight-old` (strikethrough) when the value is directly being replaced by a `highlight-new` value. For all other red emphasis, use `highlight-warn`.

## Quick Reference

| Feature | How |
|---|---|
| Add a box | Copy a `<div class="box ...">` block, give it a unique `id`, set position |
| Connect boxes | Add `data-connect-to="target-id"` and `data-color="#hex"` to source box |
| Label a connector | Add `data-label="text"` to the source box |
| Add arrow color | Add a `<marker>` in SVG defs + map it in `drawConnectors()` color check |
| Theme a box | Add class: `theme-blue`, `theme-green`, `theme-red`, `theme-orange`, `theme-purple`, `theme-yellow`, `theme-gray`, `theme-info` |
| Tag (badge) | `<span class="tag tag-new">NEW</span>` or `<span class="tag tag-existing">Existing</span>` |
| Subnet block | `<div class="subnet"><span class="subnet-name">Name</span><br/><span class="subnet-cidr">CIDR</span></div>` — add `.subnet` CSS as needed |
| Custom CSS | Add theme-specific styles in `<style>` block following the pattern |

## Environment Color Scheme (MANDATORY)

Every item belonging to an environment MUST use that environment's color — VNets, route tables, subnets, badges, peering lines, detail boxes, etc. Do NOT use a generic "route table" color or "detail" color. The item's color is determined by which environment it belongs to, not what type of item it is.

| Environment | Border Color | Background (rgba) | Label Color | Use For |
|---|---|---|---|---|
| **Dev** | `#3fb950` | `rgba(63,185,80,0.04)` | `#3fb950` | Dev VNets, Dev route tables, Dev subnets, Dev DBW |
| **Test** | `#58a6ff` | `rgba(88,166,255,0.04)` | `#58a6ff` | Test VNets, Test route tables, Test subnets, Test DBW |
| **Prod** | `#f85149` | `rgba(248,81,73,0.04)` | `#f85149` | Prod VNets, Prod route tables, Prod subnets, Prod DBW |
| **Collab/DBW** | `#d2a8ff` | `rgba(210,168,255,0.04)` | `#d2a8ff` | Collab VNets, Collab route tables, Collab subnets |
| **Hub** | `#f78166` | `rgba(247,129,102,0.04)` | `#f78166` | Hub VNet, Hub gateway, Hub route tables (e.g., rt-hub-gw) |
| **Firewall** | `#d29922` | `rgba(210,153,34,0.04)` | `#d29922` | Azure Firewall, firewall policy, firewall rules |
| **EDW/Shared** | `#8b949e` | `rgba(139,148,158,0.04)` | `#8b949e` | EDW, on-prem, general/shared resources |

**Rule**: If `rt-shared-dev-westus2-001` is a Dev route table, it gets `dev-theme`, NOT a generic `rt-theme`. If `rt-hub-gw-westus2-001` is the Hub gateway route table, it gets `hub-theme`. The environment determines the color, not the resource type.

## Design Guidelines

1. **Spread boxes out** — leave 40-80px gaps minimum to avoid overlap
2. **Group related boxes** in columns or rows (e.g., Dev column, Test column, Prod column)
3. **Put detail/reference panels** (legends, route tables, flow summaries) below the main topology
4. **Canvas size** should be ~1.5x the total content area to allow drag room
5. **Color by environment, not by resource type** — see Environment Color Scheme above. Never create a generic `.rt-theme` or `.detail-theme`; always use the environment theme class (`.dev-theme`, `.test-theme`, `.prod-theme`, etc.)
6. **localStorage key** is auto-derived from `<title>` so multiple diagrams don't conflict

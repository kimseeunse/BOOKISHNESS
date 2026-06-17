# Chrome conversion spec — old right-nav → main-page footer chrome

Goal: re-skin each reading/experiment piece so its **chrome** matches `main/index.html`,
while keeping every piece's **own content + interaction 100% intact**.

The canonical result is `experiment/_template.html` (new) and the gold examples
`readings/drill/index.html` (SVG + audio) and any already-converted piece. **Match them exactly.**

## What "chrome" means (REPLACE these)
The OLD chrome to remove from each file:
1. The big shared CSS block: `:root{…}` reset, `#hint`, the elaborate `.dev-grid`
   (`.frame`, `.gline` PINK, `.g-circ`, `.node`), `.ui`, `.nav-panel`, `.nav-head`,
   `.nav-links`, `.info-panel`, `.shop-merch`, the `@media (max-width:560px)` nav rules,
   and (drill/flashlight only) `#back`, `.wave` rules, `body.muted`.
2. The OLD body HTML: the `<div class="dev-grid">…</div>` (with frame/circ/node),
   the `<div class="ui"><div class="nav-panel">…</div></div>`, and any `#back` link.
3. The OLD nav-handler JS at the end: the `document.querySelectorAll(".nav-links [data-nav]")…`
   block and (drill/flashlight) the `audio-btn` click handler + `body.muted` toggle.

## What to KEEP (do NOT touch)
- `<!DOCTYPE>`, `<html lang>`, `<head>` meta, `<title>` (leave as-is — usually `BOOKISHNESS`).
- The Google Fonts `<link>` for Gothic A1 (canvas Korean uses it). Keep any `@font-face`
  (drill's JoseonGulim) and the piece's own body `font-family`.
- The `#stage` element and its `<canvas id="cv">` OR `<svg>` content — verbatim.
- The `#hint` element + its text.
- ALL canvas-setup JS (`cv/ctx/stage/hint`, `resize()`) and ALL PIECE LOGIC
  (onResize/frame/pointer/etc.) — verbatim, including `setTimeout(...hint...gone..., 6000)`.
- The `const NAV_CONTENT = {…}` object and its exact strings (this is the piece's writing).
  Keep whatever keys the piece uses (about/how/note, or drill's about/kindle/bezos, etc.).
- Any piece-specific CSS the file added beyond the chrome (e.g. cursor overrides, extra
  elements) — keep it.

## The NEW chrome to insert

### NEW `<head>` CSS — replace the old chrome CSS block with this
(Keep the piece's `@font-face` / piece-specific rules; only swap the chrome rules.)
Use the exact CSS from `experiment/_template.html` lines inside `<style>`:
`:root` vars (ink/bg/dim/pink/pad/mono), `* reset`, `html,body`, `body` (keep the piece's
own font-family if it differs — e.g. drill), `#stage`, `#hint` (bottom:64px; z-index:9;
font-family:var(--mono)), `.dev-grid`/`.grid-inner`/`.gline #dcdcdc`/`.gv/.gh/.gv1…`,
the `.site-footer …` footer block, `#loader`, and `@media (max-width:560px){.site-footer.open{height:42vh}}`.

### NEW body markup — gray grid + footer + loader
```html
<!-- 회색 3×3 dev-grid (장식, 캔버스 뒤) -->
<div class="dev-grid" aria-hidden="true">
  <div class="grid-inner">
    <div class="gline gv gv1"></div><div class="gline gv gv2"></div>
    <div class="gline gh gh1"></div><div class="gline gh gh2"></div>
  </div>
</div>

<div id="hint">…KEEP THE PIECE'S HINT TEXT…</div>

<div id="stage">…KEEP THE PIECE'S CANVAS OR SVG…</div>

<!-- 미니 푸터 (main 양식) -->
<footer class="site-footer" id="site-footer">
  <div class="foot-bar">BOOKISHNESS /// 100 EXPERIMENTS IN READING ON SCREEN</div>
  <nav class="foot-links">
    <!-- one <button class="foot-link" data-sec="KEY">LABEL</button> per NAV_CONTENT key -->
    <button class="foot-link" data-sec="about">ABOUT</button>
    <button class="foot-link" data-sec="how">HOW</button>
    <button class="foot-link" data-sec="note">NOTE</button>
    <a class="foot-link" href="../../main/index.html">← BACK TO BOX</a>
  </nav>
  <div class="foot-panel"><div class="foot-content" id="foot-content"></div></div>
  <div class="foot-copy">Bookishness © 2026 Seeun Kim. All rights reserved.</div>
</footer>

<div id="loader">LOADING BOOKISHNESS …</div>
```
- The `data-sec` keys + button LABELS must mirror the piece's NAV_CONTENT keys.
  Standard pieces: about/how/note → ABOUT / HOW / NOTE.
  If a piece has different keys (e.g. drill: about/kindle/bezos → ABOUT / KINDLE / JEFF BEZOS),
  use those.
- `../../main/index.html` is correct for `experiment/<piece>/`, `experiment2/<piece>/`,
  and `readings/<piece>/` (all two levels deep). Keep it.

### NEW footer JS — replace the old nav-handler block with this
(Place AFTER the `const NAV_CONTENT = {…}` object, which you keep.)
```js
const footer = document.getElementById("site-footer");
const footContent = document.getElementById("foot-content");
let openSec = null;
function openSection(btn){
  const sec = btn.dataset.sec;
  if (openSec===sec){ closeFooter(); return; }
  openSec = sec;
  footContent.innerHTML = "";
  const h = document.createElement("h3"); h.textContent = btn.textContent.trim();
  const p = document.createElement("p"); p.textContent = NAV_CONTENT[sec] || "";
  footContent.append(h, p);
  footer.classList.add("open");
  footer.querySelectorAll(".foot-link[data-sec]").forEach(b=>b.classList.toggle("active", b===btn));
}
function closeFooter(){
  openSec=null; footer.classList.remove("open");
  footer.querySelectorAll(".foot-link[data-sec]").forEach(b=>b.classList.remove("active"));
}
footer.querySelectorAll(".foot-link[data-sec]").forEach(b=>b.addEventListener("click", ()=>openSection(b)));
addEventListener("keydown", e=>{ if(e.key==="Escape") closeFooter(); });

/* 로더 숨김 */
(function(){
  const hide=()=>{ const l=document.getElementById("loader"); if(l) l.classList.add("gone"); };
  addEventListener("load", hide); setTimeout(hide, 1200);
})();
```

## AUDIO pieces (drill, flashlight) — special
These have an `audio-btn` (wave) inside the old nav. Do NOT drop the mute feature.
Add a SOUND toggle as an extra footer link and wire it to the existing mute var:
```html
<button class="foot-link" id="sound-btn">SOUND: ON</button>
```
(place it right before the `← BACK TO BOX` link), and replace the old audio-btn handler with:
```js
const soundBtn = document.getElementById("sound-btn");
soundBtn.addEventListener("click", () => {
  unlockAudio();                 // or whatever the piece's audio-init fn is called
  muted = !muted;                // reuse the piece's existing mute variable
  soundBtn.textContent = muted ? "SOUND: OFF" : "SOUND: ON";
});
```
Keep all other audio code (initAudio/startX/frame volume logic) verbatim. Remove `body.muted` usage.
See `readings/drill/index.html` for the exact pattern.

## Checklist per file
- [ ] No `.nav-panel`, `.ui`, `.frame`, `.g-circ`, `.node`, `#back`, `.shop-merch`, `.wave`,
      `body.muted`, `#info-panel`, `data-nav` left anywhere.
- [ ] Footer present with one data-sec per NAV_CONTENT key + `← BACK TO BOX`.
- [ ] `#loader` present and hidden on load.
- [ ] Grid is the gray 3×3 (`#dcdcdc`), no pink/frame/markers.
- [ ] PIECE LOGIC + NAV_CONTENT strings unchanged.
- [ ] File still opens by double-click (no new external deps).

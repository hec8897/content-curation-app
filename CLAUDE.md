# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A single-file **design prototype** of a Korean content-curation mobile app ("큐레이터"). There is no build system, no `package.json`, no tests, no backend. The entire deliverable is `design-prototype.html` (~4 MB).

## Running it

Open `design-prototype.html` in a browser. Nothing to install. It self-extracts on `DOMContentLoaded`.

## Structure of design-prototype.html

It is a **bundler output**, not hand-written HTML. Four parts:

1. Lines 1–368: the bundler runtime (unpack loop, blob minting, a parent-chain `postMessage` relay for nested page bundles, an error sink that paints failures into the page). Generic infrastructure — do not edit.
2. `<script type="__bundler/manifest">` (line 370): JSON map of `uuid → {mime, compressed, data}`, base64+gzip. 95 entries: 3 × `text/javascript` (the `dc-runtime`, React production, ReactDOM production) and 92 Pretendard Variable woff2 subsets.
3. `<script type="__bundler/page_order">` (line 378).
4. `<script type="__bundler/template">` (line 382): **the entire app, as a single JSON-encoded string.** Resource references inside it are bare uuids that the runtime substitutes with blob URLs.

### Editing the app

The app source lives inside a JSON string on one 100 KB line. Do not try to hand-edit it in place. Extract → edit → re-encode:

```python
import json
p = 'design-prototype.html'
lines = open(p).read().split('\n')
tpl = json.loads(lines[381])          # 0-indexed; the template line
# ... modify tpl ...
lines[381] = json.dumps(tpl)
open(p, 'w').write('\n'.join(lines))
```

The 92 font subsets are why the file is 4 MB — leave the manifest alone unless fonts change.

## App architecture (inside the template)

Rendered by an in-house runtime (`dc-runtime`, generated from `dc-runtime/src/*.ts` which is **not in this repo**) on top of React. Two halves:

- **Markup**: a `<x-dc>` tree using a template DSL, not JSX. `{{ expr }}` interpolation, `<sc-if value="{{ flag }}">`, `<sc-for list="{{ arr }}" as="item">`, events as `sc-camel-on-click="{{ handler }}"` / `sc-camel-on-change` / `sc-camel-on-key-down`. `hint-placeholder-*` attributes only affect the design-tool placeholder render. All styling is inline `style=""`; a `<helmet>` block holds the `@font-face` CSS and keyframes.
- **Logic**: one `<script type="text/x-dc">` with `class Component extends DCLogic`. Every value the markup binds to is returned from a single `renderVals()`, including per-item handlers and computed style objects. That method is the map of the whole app — read it first.

### Conventions that matter

- **Screens are `state.screen` + a `state.stack` array**, navigated with `push(screen, patch)` / `back()`. Screens: `onboarding`, `main`, `topic`, `article`, `sources`, `settings`, `history`. Each is one top-level `<sc-if value="{{ isX }}">` block, and `renderVals()` derives every `isX` from `state.screen`.
- **All data is hardcoded** at the top of the script: `TOPICS`, `SOURCES`, `CATALOG`, `ARTICLES`, `DIGEST_IDS`. Async states are faked with `setTimeout` (a 900 ms initial `loading`, an 800 ms summary fetch that fails deliberately for article `a3`).
- **Style helpers on the class** (`track`, `knob`, `check`) return style objects for repeated controls; `renderVals()` hands them to the markup as `*Style` values. Reuse these instead of writing new inline style strings for toggles/checkboxes.
- Copy is Korean. Design tokens in use: brand `#0066FF`, ink `#171719`, muted `rgba(55,56,60,.61)`, border `#E1E2E4`, danger `#FF4242`, canvas `#faf9f5`.

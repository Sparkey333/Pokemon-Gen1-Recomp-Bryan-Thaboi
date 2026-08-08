---
name: recomp
description: The working method for the Gen1Recomp fork — one MIT engine, two products (a public Pokemon fork that reads a player's ROM, and a sellable original-IP game). Use when growing either product, syncing from upstream, adding a content pack, hardening the engine, or picking the next increment. Triggers on "next increment", "snowflake", "content pack", "original IP", "total conversion", "feature parity", "sync upstream", "recomp", or any work inside this repository.
---

# /recomp

The method for turning one MIT-licensed engine into two shippable products
without ever breaking the ability to merge from upstream.

Git work goes through **`/gitkit`** — remotes, sync, the pre-push gate,
commits, PRs, recovery. This skill decides *what* to change; gitkit decides
*how it lands*. Invoke it at every git step rather than improvising.

## The two products

| | **A — public fork** | **B — original IP** |
| --- | --- | --- |
| Content | player's own ROM, decoded at runtime | authored by us |
| Ships | free, open source | commercially |
| Nintendo IP | referenced, never shipped | none |

A is this repo. B is the same engine plus one complete authored content pack.
**Read `docs/IP-FIREWALL.md` before touching content in either.** It lists,
with file and line, the four categories of Nintendo material actually present
in this tree and which must never reach B.

Product A must not be sold. The MIT licence permits it; Nintendo's copyright
on the content the game loads does not.

## Ground truth about this codebase

Do not re-derive these; they are verified and load-bearing.

- **Engine:** LÖVE 11.x / LuaJIT (Lua 5.1 semantics), ~267k LOC of Lua.
- **Licence:** MIT, © 2026 BOIS CLUB GAMES, LLC. Sale is permitted. The notice
  must be retained — never edit `LICENSE.MD`.
- **Upstream default branch is `dev`**, not `main`.
- **No ROM or extracted data is committed**; `data/generated/` and
  `assets/generated/` are gitignored. Keep it that way.
- **The content-pack seam already works.** `POKEPORT_DATA_DIR=<dir> love .`
  boots the engine on any dataset root. Proven against `tests/fixture_data`
  (3 species, 2 maps, zero Nintendo content); pinned by
  `tests/engine/data_dir_boot_test.lua`.
- **A content pack is 16 files** — `constants maps tilesets text text_pointers
  trainer_headers font sprites pokemon moves items type_chart trainers
  encounters field battle_anims` — plus art referenced by paths stored inside
  the data. Optional: `audio palettes icons`.
- **Upstream built total-conversion seams on purpose.** `field.boot` is
  documented as "the total-conversion override point" (`src/core/Data.lua:57`);
  `dexSize` derives from the roster instead of being pinned to 151. Use these
  rather than adding new ones.

## Snowflake fractal expansion

Grow outward from the upstream crystal one small self-similar arm at a time.
Every increment obeys the same five rules, at every scale:

1. **Small enough to revert alone.** One branch, one PR, one ledger entry.
2. **Additive where possible.** A new file never conflicts on merge. Edit an
   upstream file only when there is no additive way, and record why.
3. **Verified by something that runs.** A test, or a command whose output you
   paste. Not "should work".
4. **Pack-general, not Kanto-specific.** Anything added to `src/` must work for
   any content pack. If it needs Kanto knowledge, it belongs in the pack.
5. **Recorded in `docs/DIVERGENCE.md`** before the PR opens.

The fractal part: the same five rules govern a one-line guard and a whole
subsystem. When an increment turns out too big, split it and apply the rules to
each half.

## The loop

**1 — Sync and confirm green.** `/gitkit` → sync from upstream. Then:

```sh
./scripts/test.sh && ./scripts/lint.sh
```

Baseline on a ROM-less checkout: **all tiers pass**, luacheck **0 errors**
(12 warnings is the inherited baseline). T3 and `run_link_tests` skip
themselves without `data/generated/` — correct, not a failure. Never start an
increment on a red tree; you will not know what you broke.

**2 — Pick one increment.** From `docs/ROADMAP.md`, or the next thing blocking
a pack from being playable. One. If two things are obviously coupled, they are
one increment; if they merely look related, they are two.

**3 — Classify it before writing code.**

| Kind | Where it goes | Ledger |
| --- | --- | --- |
| Upstream defect | fix in place, keep it generic | `Upstreamable` section |
| Fork-only behaviour | additive file + minimal hook | a `D-` entry |
| Pack content | a pack directory, never `src/` | no entry needed |
| Branding / identity | additive config, one definition | a `D-` entry |

If it is an upstream defect, write it so it could be offered back as a PR:
no fork branding, no Nintendo content, no dependence on our layout.

**4 — Build it, smallest first.** Prefer a guard over a rewrite. Match the
surrounding comment density — this codebase explains *why* at every non-obvious
line, and a bare change reads as unfinished here.

**5 — Prove it.** Add the test in `tests/engine/` (auto-discovered by
`tests/run_engine.lua`, so no registration needed). Then the full gate. For
anything touching boot, rendering or content loading, also run it for real:

```sh
POKEPORT_DATA_DIR=tests/fixture_data \
POKEPORT_DRIVER=<driver.lua> POKEPORT_IDENTITY=probe-$$ \
  xvfb-run -a love .
```

A unit test that passes while the game will not boot is the failure mode this
step exists to catch. It has already caught it once.

**6 — Record it.** Add the `docs/DIVERGENCE.md` entry. State the conflict rule
(ours-wins / upstream-wins / additive) so the next sync does not have to guess.

**7 — Land it.** `/gitkit` → commit, push, draft PR, subscribe.

## Feature parity before divergence

Do not start reskinning while upstream capabilities are unverified. Parity
means: every upstream capability either verified working here, or explicitly
recorded as unverifiable in this environment and why.

Verifiable headless, no ROM, no display:

```sh
./scripts/test.sh                      # every ROM-free tier
./scripts/lint.sh                      # luacheck
luajit tests/run_engine.lua            # T1/T2 alone
luajit tests/run_modkit.lua            # mod SDK
python3 tools/modkit.py lint mods/<m>  # a mod ships no ROM-derived bytes
bash scripts/switch/selftest_build_switch.sh
bash scripts/xbox-uwp/selftest_build_xbox_uwp.sh
bash scripts/linux-arm64/selftest_build_linux_arm64.sh
```

Needs LÖVE + a virtual display (both installable: `apt-get install love xvfb`):
boot, render, screenshot capture, driver suites.

Cannot be verified in this container, and should be recorded as such rather
than claimed: iOS/macOS signing (needs a Mac and certificates), the Switch
fused build (self-hosted runner), Xbox UWP packaging (Windows), and the T3
content tier and `run_link_tests` (need a real ROM import).

## The IP sweep — a release gate for Product B

Before B ships, each of these must return nothing:

```sh
grep -rn 'show_text", "[^_]' data/scripts/     # inline Nintendo dialogue
grep -rn 'Fallback = "' data/scripts/          # fallback prose
ls assets/logo/pokemon_logo.png                # trademarked logo
grep -rniE 'pokemon|pikachu|kanto|pokedex' src/ data/ assets/
```

Non-empty output is not a cleanup task to do later. It is the gate.

## What never happens

- Never commit `data/generated/`, `assets/generated/`, or ROM bytes anywhere.
- Never edit or remove `LICENSE.MD`, or strip upstream attribution.
- Never push to `upstream`.
- Never squash or rewrite history containing upstream commits — it destroys the
  merge base and every future sync becomes a manual cherry-pick.
- Never sell Product A.
- Never add Kanto knowledge to `src/`. It goes in a pack.
- Never report a tier as passing when it was skipped. `scripts/test.sh` prints
  the difference; so should you.

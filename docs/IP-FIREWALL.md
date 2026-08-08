# IP firewall

What may be sold, what may not, and where the line runs in this tree.

This is an engineering document. It records what is actually in the repository
and which files a commercial product must not contain. It is not legal advice;
get a lawyer's sign-off before selling anything.

## The two products

| | **Product A — public fork** | **Product B — original IP** |
| --- | --- | --- |
| Repo | `Sparkey333/Pokemon-Gen1-Recomp-Bryan-Thaboi` | separate repo, private until launch |
| Content | player-supplied ROM, decoded at runtime | 100% authored by us |
| Distribution | free, open source | commercial |
| Nintendo IP | referenced, never shipped | none, anywhere |
| Shares with upstream | engine + content pipeline | engine only |

**Product A can never be sold.** Not because of upstream's licence — MIT
permits selling — but because the playable experience requires Nintendo's
copyrighted work. Free distribution of an engine that reads a ROM the player
already owns is the model upstream established; charging for it is a different
question with a different answer.

**Product B is sellable** because the engine is MIT and the content is ours.
That is only true if the content really is 100% ours — hence the rest of this
document.

## What the licence actually allows

`LICENSE.MD` is MIT, © 2026 BOIS CLUB GAMES, LLC. It grants use, modification,
distribution **and sale**, on one condition: the copyright notice and licence
text must be retained in all copies or substantial portions.

So Product B ships `LICENSE.MD` unchanged and adds its own notice alongside.
Removing or rewriting upstream's notice is the one thing that would turn a
legitimate commercial fork into infringement.

## What is NOT in this repository

Verified, not assumed:

- **No ROM.** No cartridge bytes anywhere, in the tree or in history.
- **No extracted game data.** `data/generated/` and `assets/generated/` are
  gitignored (`.gitignore:3-4`). Species stats, moves, maps, tilesets, text,
  trainers, encounters and audio are all produced at import time on the
  player's machine from their own ROM, and live outside the repo.
- **No sprites, tilesets or music.** Same mechanism.

This is upstream's legal shield and it is inherited intact. Do not weaken it.
Committing a single generated file would undo it.

## What IS in this repository — and must not reach Product B

Each of these is fine for Product A and disqualifying for Product B.

### 1. Nintendo dialogue, committed inline

`data/scripts/` is 85 hand-written Lua files that reimplement Kanto's scripts,
each headed `Source: pokered/scripts/<Name>.asm`. Most dialogue is a *label*
resolved against ROM-extracted text at runtime (306 of 322 `show_text` calls),
which ships nothing. But **16 calls carry the prose inline** as fallbacks, and
there are more in `*Fallback` fields. Real examples in the tree:

```
"So you've come to\nshut down my\noperation?\f"
"Gah! Even the\nCHIEF is no match\nfor you!\f"
"Is that right?\nI'm the game\ndesigner!\fFilling up your\nPOKéDEX is tough..."
```

That is Nintendo's copyrighted text sitting in our source. Find every one:

```sh
grep -rn 'show_text", "[^_]' data/scripts/          # inline, not a label ref
grep -rn 'Fallback = "' data/scripts/               # fallback prose
```

### 2. A trademarked logo

`assets/logo/pokemon_logo.png` (128×56) is committed and used as the title
fallback at `src/ui/TitleState.lua:171`. The real logo normally comes from the
ROM (`assets/generated/title/pokemon_logo.png`); this is the stand-in when the
import has not produced one. Either way it is a trademark in the tree.

### 3. Kanto structure welded into engine code

Not copyrightable as *mechanics*, but it names Nintendo's world and story:

| Location | What |
| --- | --- |
| `src/core/Data.lua:34-38` | the eight Kanto badge ids |
| `src/core/Data.lua:31` | `hmMoves = {CUT, FLY, SURF, STRENGTH, FLASH}` |
| `src/core/Data.lua:30` | `fallbackMove = "TACKLE"` |
| `src/core/Data.lua:44-55` | Yellow's in-game trade table, by species name |
| `src/core/Data.lua:64-65` | `startMap = "REDS_HOUSE_2F"`, `playerName = "RED"`, `rivalName = "BLUE"` |
| `src/core/Data.lua:186-203` | Cinnabar Gym trainer headers |
| `src/core/Data.lua:173-184` | Fighting Dojo Karate Master |
| `src/world/FieldDefaults.lua` | Kanto palettes, bookshelves, fishing, Safari, player sprites |
| `src/world/SsAnneLayout.lua` | S.S. Anne cabin layout |
| `src/ui/OakSpeech.lua`, `src/ui/YellowIntro.lua` | the opening sequences |
| `src/world/PikachuFollower.lua` | Yellow's follower |

Upstream built most of these as *fill-if-absent* defaults precisely so a total
conversion can replace them — `src/core/Data.lua:57` calls `field.boot` "the
total-conversion override point", and `dexSize` is derived from the roster
rather than pinned to 151 (`Data.lua:106-113`). That is the seam to use.

### 4. Trademarks in identifiers and docs

`Pokemon`, `POKéDEX`, `Pikachu`, `Kanto`, `Team Rocket`, gym leader and species
names appear across `src/`, `data/scripts/`, `docs/`, `mods/` and the README.
Product B needs a clean sweep, not a rename pass over the obvious ones.

## The seam Product B is built on

The engine already loads its entire dataset from a directory of its choosing:

```sh
POKEPORT_DATA_DIR=<pack> love .
```

`src/core/Data.lua` reads all 16 required modules from that root, and as of
commit `6767f31` `RomImporter.isReady()` honours it too, so the game boots and
renders instead of demanding a ROM. Proven end to end against
`tests/fixture_data` — a 3-species, 2-map dataset with no Nintendo content —
and pinned by `tests/engine/data_dir_boot_test.lua`.

**A content pack is a directory with these 16 files:**

```
constants  maps  tilesets  text  text_pointers  trainer_headers  font
sprites    pokemon  moves  items  type_chart  trainers  encounters
field      battle_anims
```

plus its own art, referenced by paths stored *inside* the data (see
`tests/fixture_data/sprites.lua`, which points at
`tests/fixture_data/assets/*.png`). Optional: `audio`, `palettes`, `icons`.

Product B is therefore: **the engine, plus one complete authored pack, minus
the four categories above.** No engine rewrite required.

### What still blocks a playable pack

`tests/fixture_data` boots and draws the title screen, then runs out of
content. The chain past that point is dataset completeness, not engine
defects — the first three engine-side blockers are already fixed in `6767f31`.
The next one is a missing player sprite. Growing the pack is the work.

## Rules

1. Never commit anything under `data/generated/` or `assets/generated/`.
2. Never commit ROM bytes, in any form, including tests and fixtures.
3. Never edit or remove `LICENSE.MD`.
4. New content for Product B goes in a pack directory, never inline in `src/`.
5. Anything added to `src/` must work for *any* pack, not just a Kanto one.
   If it needs Kanto knowledge, it belongs in the pack.
6. Before Product B ships, the four categories above must return zero hits.
   That sweep is a release gate, not a cleanup task.

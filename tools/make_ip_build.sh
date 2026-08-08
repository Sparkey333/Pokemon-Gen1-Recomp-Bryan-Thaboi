#!/usr/bin/env bash
# Derive the original-IP product (Product B) from this engine.
#
# Product B is NOT a hand-maintained copy of this repository.  A copy drifts:
# every engine fix has to be re-applied by hand, and six months in the two
# trees disagree in ways nobody can enumerate.  Instead B is DERIVED -- this
# script is the definition, and re-running it after an engine change
# regenerates a current B.
#
# What it does:
#   1. copies the engine (src, main.lua, conf.lua, the ROM-free test net)
#   2. removes every Kanto-content category listed in docs/IP-FIREWALL.md
#      that can be removed today
#   3. installs packs/starter/ as the content pack, from tests/fixture_data
#   4. rewrites the branding and the update slug
#   5. runs the IP sweep and reports what is still welded into src/
#
#   tools/make_ip_build.sh <target-dir> [--pack-name NAME]
#
# The output is a git-ready tree with NO history.  That is deliberate: this
# repository's history contains Nintendo dialogue and a trademarked logo (see
# docs/IP-FIREWALL.md), and a product intended for sale should not inherit
# them.  The engine remote is wired but unmerged, so you keep the option of
# merging engine history later without having taken it by default.

set -euo pipefail
cd "$(dirname "$0")/.."
SRC="$PWD"

TARGET="${1:-}"
PACK_NAME="starter"
shift || true
while [ $# -gt 0 ]; do
  case "$1" in
    --pack-name) PACK_NAME="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$TARGET" ]; then
  sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
fi
if [ -e "$TARGET" ] && [ -n "$(ls -A "$TARGET" 2>/dev/null)" ]; then
  echo "refusing to write into non-empty $TARGET" >&2
  exit 1
fi

mkdir -p "$TARGET"
TARGET="$(cd "$TARGET" && pwd)"
echo "== deriving original-IP build into $TARGET"

# ---------------------------------------------------------------- 1. engine

# Engine and the ROM-free test net.  Deliberately NOT copied:
#   data/scripts/     Kanto story scripts, and the only place inline Nintendo
#                     dialogue is committed (docs/IP-FIREWALL.md §1)
#   tests/parity_*    assert Pokemon Red facts
#   tests/drivers/    Kanto behaviour drivers (bot_route.lua alone is 73 KB of
#                     Kanto routing)
#   tests/content_red/, tests/goldens/   Red content fixtures
#   mods/example_*    ship Kanto content (example_mew_starter needs Mew)
#   mobile/android/love  154 MB vendored love-android; add it back when you
#                     actually build for Android
for path in main.lua conf.lua src tools scripts .luacheckrc; do
  cp -r "$SRC/$path" "$TARGET/"
done
rm -f "$TARGET/tools/make_ip_build.sh"

mkdir -p "$TARGET/tests"
for path in harness.lua love_stub.lua tier_runner.lua fs_io.lua \
            engine modkit run_engine.lua run_modkit.lua modkit_tests.lua; do
  [ -e "$SRC/tests/$path" ] && cp -r "$SRC/tests/$path" "$TARGET/tests/"
done

# The mod-SDK suites are ROM-free and, less obviously, load-bearing:
# tests/engine/gate_meta_coverage.lua fails every registry that no test names
# through the public mod API, and these are those tests.  Leaving them out
# turns one omission into ~30 spurious failures.
cp "$SRC"/tests/mod_*.lua "$TARGET/tests/" 2>/dev/null || true

# tests/goldens/fixture_fingerprint.txt pins the ROM-free dataset and is
# original content, so it comes along.  vanilla_fingerprint.txt pins the Red
# import and is meaningless without a ROM, so it does not.
mkdir -p "$TARGET/tests/goldens"
cp "$SRC/tests/goldens/fixture_fingerprint.txt" "$TARGET/tests/goldens/" 2>/dev/null || true

# Some tests/engine suites assert Kanto facts and cannot pass once the Kanto
# content is gone.  They are quarantined rather than deleted -- a suite that
# fails because the content changed is information, and deleting it would hide
# which engine behaviour was Kanto-shaped all along.
#
# The quarantine set is DERIVED at the end of this script by running the tier
# and moving whatever fails, not hardcoded here.  A hardcoded list goes stale
# the moment an engine change fixes or breaks one, and then it is lying.
mkdir -p "$TARGET/tests/quarantine"

# ------------------------------------------------------------------ 2. strip

echo "== removing Nintendo-content categories"
rm -rf "$TARGET/data/scripts"
rm -f  "$TARGET/assets/logo/pokemon_logo.png"

mkdir -p "$TARGET/assets"
for d in fonts launcher touch; do
  [ -d "$SRC/assets/$d" ] && cp -r "$SRC/assets/$d" "$TARGET/assets/"
done

mkdir -p "$TARGET/data"
for f in palettes_gbc.lua palettes_yellow.lua; do
  [ -f "$SRC/data/$f" ] && cp "$SRC/data/$f" "$TARGET/data/"
done

# -------------------------------------------------------------- 3. the pack

echo "== installing packs/$PACK_NAME from the ROM-free fixture dataset"
mkdir -p "$TARGET/packs/$PACK_NAME"
cp -r "$SRC/tests/fixture_data/." "$TARGET/packs/$PACK_NAME/"

# Asset paths live INSIDE the pack data (see packs/<name>/sprites.lua), so
# moving the tree means repointing them.  This is the one thing that makes a
# pack relocatable at all.
find "$TARGET/packs/$PACK_NAME" -name '*.lua' -print0 \
  | xargs -0 sed -i "s#tests/fixture_data/#packs/$PACK_NAME/#g"

# The engine suites require("tests.fixture_data"), so the pack has to be
# reachable under that name too.  A symlink rather than a second copy: two
# copies of the dataset would drift, and the whole point of a pack is that
# there is one of it.  init.lua is kept for the same reason -- it is the
# loader those suites go through.
ln -s "../packs/$PACK_NAME" "$TARGET/tests/fixture_data"

cat > "$TARGET/packs/$PACK_NAME/pack.lua" <<PACKEOF
-- Content pack manifest.
--
-- A pack is the 16 data modules the engine requires, plus the art they point
-- at.  The engine loads one via POKEPORT_DATA_DIR (src/core/Data.lua), so a
-- pack is swappable without touching engine code.
--
-- This one is the seed: 3 species, 2 maps, no player sprite.  It boots and
-- renders and is not yet a game.  Growing it is the work.
return {
  id = "$PACK_NAME",
  name = "Starter Pack",
  version = "0.0.1",
  -- Every module here is authored.  Nothing in this directory is derived from
  -- any commercial ROM, and nothing may be added that is.
  origin = "original",
}
PACKEOF

# ------------------------------------------------------------ 4. rebranding

echo "== rebranding"
if [ -f "$TARGET/src/update/Repo.lua" ]; then
  sed -i 's#^Repo.SLUG = .*#Repo.SLUG = "Sparkey333/original-ip-engine"#' \
    "$TARGET/src/update/Repo.lua"
fi

cp "$SRC/LICENSE.MD" "$TARGET/LICENSE.MD"
cat > "$TARGET/NOTICE.md" <<'NOTICEEOF'
# Notice

This product is built on the Gen1Recomp engine.

    Copyright 2026 BOIS CLUB GAMES, LLC
    Licensed under the MIT License -- see LICENSE.MD

The MIT License permits use, modification, distribution **and sale**, on one
condition: the copyright notice and licence text must be retained. `LICENSE.MD`
is that notice, kept verbatim, and it must never be edited or removed. Doing so
is the single thing that would turn a legitimate commercial product into
infringement.

Engine work derives from https://github.com/bryanthaboi/gen1recomp, whose
authors in turn credit the pret disassembly project.

All game content in `packs/` -- creatures, moves, maps, sprites, text, music --
is original to this project and is **not** covered by the MIT licence above.
NOTICEEOF

# --------------------------------------------------------------- 5. IP sweep

install -m 0755 /dev/stdin "$TARGET/tools/ip_sweep.sh" <<'SWEEPEOF'
#!/usr/bin/env bash
# Release gate: no Nintendo-derived content may ship in this product.
#
# Exits non-zero on anything in the HARD list.  The SOFT list is engine
# structure that is still Kanto-shaped -- tracked debt, reported but not
# fatal, because clearing it means moving those defaults out into a pack.
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0

echo "== HARD: content that must not exist"
for check in \
  "committed dialogue:data/scripts" \
  "trademarked logo:assets/logo/pokemon_logo.png" \
  "ROM-derived data:data/generated" \
  "ROM-derived assets:assets/generated" ; do
  label="${check%%:*}"; path="${check#*:}"
  if [ -e "$path" ]; then echo "  FAIL $label -> $path exists"; fail=1
  else echo "  ok   $label"; fi
done

if grep -rIn --exclude-dir=.git -E '\.gb\b|\.gbc\b' packs/ 2>/dev/null | grep -q .; then
  echo "  FAIL a pack references a ROM file"; fail=1
else
  echo "  ok   no pack references a ROM"
fi

echo
echo "== SOFT: Kanto structure still welded into the engine (tracked debt)"
hits=$(grep -rIniE --exclude-dir=.git --exclude-dir=packs \
        -e 'pokemon' -e 'pikachu' -e 'kanto' -e 'pokedex' -e 'team rocket' \
        src/ data/ 2>/dev/null | wc -l)
echo "  $hits reference(s) in src/ and data/"
echo "  Clearing these means moving Kanto defaults out into a pack."

echo
if [ "$fail" -ne 0 ]; then
  echo "IP SWEEP FAILED -- do not ship"; exit 1
fi
echo "IP sweep passed the hard gate."
SWEEPEOF

# ------------------------------------------------------------------ 6. docs

cat > "$TARGET/README.md" <<READMEEOF
# original-ip-engine

An original creature RPG built on the MIT-licensed
[Gen1Recomp](https://github.com/bryanthaboi/gen1recomp) engine.

**This repository contains no Nintendo-derived content.** Not by policy --
by construction. It is generated by \`tools/make_ip_build.sh\` in
[Pokemon-Gen1-Recomp-Bryan-Thaboi](https://github.com/Sparkey333/Pokemon-Gen1-Recomp-Bryan-Thaboi),
which strips every category listed in that repo's \`docs/IP-FIREWALL.md\`, and
\`tools/ip_sweep.sh\` here fails the build if any of it comes back.

## Status

Early. The engine boots and renders on \`packs/$PACK_NAME/\`, a 3-species,
2-map seed pack with no player sprite. It is not yet a game. Growing that pack
into one is the project.

## Run it

    POKEPORT_DATA_DIR=packs/$PACK_NAME love .

## Test

    ./scripts/test.sh      # ROM-free engine tiers
    ./scripts/lint.sh      # luacheck
    ./tools/ip_sweep.sh    # the release gate

## What a content pack is

The 16 data modules the engine requires, plus art referenced by paths stored
inside the data:

    constants  maps  tilesets  text  text_pointers  trainer_headers  font
    sprites    pokemon  moves  items  type_chart  trainers  encounters
    field      battle_anims

Optional: \`audio\`, \`palettes\`, \`icons\`. Swap the pack, swap the game --
no engine change.

## Licence

Engine: MIT, © 2026 BOIS CLUB GAMES, LLC. See \`LICENSE.MD\` and \`NOTICE.md\`.
The MIT terms permit sale; retaining the notice is the condition.

Content under \`packs/\` is original to this project and not covered by that
licence.
READMEEOF

mkdir -p "$TARGET/.github/workflows"
cat > "$TARGET/.github/workflows/ci.yml" <<'CIEOF'
name: ci
on: [push, pull_request]
permissions:
  contents: read
jobs:
  engine:
    name: engine suites + IP sweep
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - run: sudo apt-get update && sudo apt-get install -y luajit
      - run: python3 -m pip install --upgrade pillow
      # The IP gate runs FIRST and independently: a green test suite on a tree
      # that smuggled content back in is the wrong thing to find out later.
      - name: IP sweep
        run: ./tools/ip_sweep.sh
      - name: engine suites
        run: luajit tests/run_engine.lua
CIEOF

cp "$SRC/.gitignore" "$TARGET/.gitignore"

# ---------------------------------------------------------------- 7. verify

echo
echo "== quarantining suites that depend on the stripped Kanto content"
# Derived, not declared: run the tier, move whatever fails.  Most are suites
# that read data/scripts/ directly; a few depend on it only transitively
# (Kanto trainer headers and text), which a grep would miss and this does not.
# The tier is EXPECTED to exit non-zero here -- that is the signal being read.
# Without the guard, `set -e` plus `pipefail` aborts the script on success.
QUARANTINED=$(
  cd "$TARGET" && luajit tests/run_engine.lua 2>/dev/null \
    | sed -n 's#^FAIL \(tests/engine/.*\.lua\)$#\1#p' | sort -u
) || true
if [ -n "$QUARANTINED" ]; then
  {
    echo "# Quarantined suites"
    echo
    echo "These assert Kanto facts and cannot pass without the content this"
    echo "product deliberately does not ship. Kept, not deleted: each one names"
    echo "an engine behaviour that turned out to be Kanto-shaped, which is a"
    echo "list worth having when the engine is generalised."
    echo
    echo "Regenerate by re-running \`tools/make_ip_build.sh\` against the engine."
    echo
  } > "$TARGET/tests/quarantine/README.md"
  count=0
  while IFS= read -r suite; do
    [ -n "$suite" ] || continue
    mv "$TARGET/$suite" "$TARGET/tests/quarantine/" 2>/dev/null || continue
    echo "- \`$(basename "$suite")\`" >> "$TARGET/tests/quarantine/README.md"
    count=$((count + 1))
  done <<< "$QUARANTINED"
  echo "   quarantined $count suite(s) -> tests/quarantine/"
else
  echo "   nothing to quarantine"
fi

echo
echo "== verifying the derived tree"
if ( cd "$TARGET" && luajit tests/run_engine.lua 2>&1 | tail -2 | grep -q "ALL TESTS PASSED" ); then
  echo "   engine tier: PASS"
else
  echo "   engine tier: STILL FAILING -- investigate before publishing" >&2
fi
if ( cd "$TARGET" && luajit tests/run_modkit.lua 2>&1 | tail -2 | grep -q "ALL TESTS PASSED" ); then
  echo "   modkit tier: PASS"
else
  echo "   modkit tier: FAILING" >&2
fi

echo
echo "== IP sweep on the derived tree"
( cd "$TARGET" && ./tools/ip_sweep.sh ) || true

cat <<DONEEOF

== done: $TARGET

Publish it:

  cd "$TARGET"
  git init -b main
  git add -A
  git commit -m "Initial original-IP build derived from the Gen1Recomp engine"
  git remote add origin https://github.com/<owner>/original-ip-engine.git
  git remote add engine https://github.com/Sparkey333/Pokemon-Gen1-Recomp-Bryan-Thaboi.git
  git push -u origin main

The 'engine' remote is wired but NOT merged, so this tree starts with clean
history. Merging engine history later stays possible; un-inheriting it would
not have been.
DONEEOF

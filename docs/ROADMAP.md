# Roadmap

Ordered increments, snowflake rules applied (see `.claude/skills/recomp`).
Each is small enough to revert alone and carries the command that proves it.

Status: `[x]` done · `[ ]` open · `[~]` partly done, remainder stated.

## Phase 0 — Foundation

- [x] **0.1 Fork with full upstream history.** Merged `upstream/dev` @ `cab62ff`
  (v0.1.75) as an unrelated history so `git merge upstream/dev` keeps working.
  *Verify:* `git log --oneline | wc -l` → 672; `git merge-base HEAD upstream/dev`
  resolves.
- [x] **0.2 Green baseline.** `luajit`, `lua5.4`, `luacheck`, `pillow`, `love`,
  `xvfb` installed; all ROM-free tiers pass, luacheck 0 errors / 12 warnings.
  *Verify:* `./scripts/test.sh && ./scripts/lint.sh`
- [x] **0.3 Retarget the self-updater.** One definition in `src/update/Repo.lua`;
  a fork build no longer offers upstream's releases and self-installs them.
  *Verify:* `luajit tests/engine/update_repo_slug_test.lua`
- [x] **0.4 Prove the content-pack seam.** `POKEPORT_DATA_DIR` now reaches a
  booted, rendering game instead of the ROM picker.
  *Verify:* `luajit tests/engine/data_dir_boot_test.lua`
- [x] **0.5 Working method written down.** `/recomp`, `/gitkit`,
  `docs/DIVERGENCE.md`, `docs/IP-FIREWALL.md`.

## Phase 1 — Feature parity

Confirm every upstream capability before diverging. Nothing here changes
behaviour; it establishes what "still works" means.

- [x] **1.1 Platform selftests.** All three offline gates pass on the fork, and
  the full builds behind them pass too — verified on PR #1
  ([run 31232061581](https://github.com/Sparkey333/Pokemon-Gen1-Recomp-Bryan-Thaboi/actions/runs/31232061581)),
  not locally: CI has the runners this container does not.
  | Job | Runner | Result |
  | --- | --- | --- |
  | Switch offline selftest | ubuntu-latest | success |
  | Xbox UWP offline selftest | ubuntu-latest | success |
  | Linux arm64 offline selftest | ubuntu-latest | success |
  | Linux arm64 AppImage build | ubuntu-24.04-arm | success |
  | Xbox UWP build | windows-2022 | success |
  | iOS build | macos-latest | success (unsigned — the signing step is gated on the upstream repo) |
  | Switch fused build | self-hosted macOS | skipped, correctly — gated on `github.repository` |
- [x] **1.2 Mod lint across every shipped mod.** The `mod lint (no ROM-derived
  content)` job passes on the fork, which is this check across every `mods/*/`
  with a manifest.
- [x] **1.3 Desktop `.love` packaging.** Exercised by the Xbox UWP selftest,
  which builds the shared payload with `scripts/pack_love.sh` and uploads it.
- [ ] **1.4 Fix `mods/examples` load warning.** Boot logs
  `mod mods/examples ignored: Could not open file mods/examples/manifest.json`.
  Either a real packaging bug or a directory that should not be scanned.
  *Verify:* boot log clean.
- [~] **1.5 Parity ledger.** Largely answered by 1.1 above plus the local gate.
  What is still genuinely unverified anywhere: the **T3 content tier** and
  `tests/run_link_tests.lua`, both of which need a real ROM import, and
  **code-signed** iOS/macOS artifacts, which need certificates on a Mac. Fold
  those two rows into a single table when convenient.
- [x] **1.6 CI green on the fork.** All 15 checks on PR #1 completed: 14
  success, 1 skipped. The `github.repository` gates behave exactly as intended
  on a fork — signing and the self-hosted Switch build switch themselves off,
  and everything that does not need a secret still runs. `headless suites
  (no ROM)` passes, so `scripts/test.sh` is green on a clean checkout as well
  as locally.

## Phase 2 — Engine hardening

The user-facing ask: "slight tune ups and error checks". Each is an
independently revertable guard, all pack-general, all upstreamable.

- [x] **2.1 `tilesPerRow` optional-but-unguarded crash.** (in `6767f31`)
- [x] **2.2 `field.flyWarps` unguarded reads.** (in `6767f31`)
- [x] **2.3 `SpriteRenderer.new` nil-index diagnostic.** (in `6767f31`)
- [ ] **2.4 Sweep the same class.** Every other place `src/` reads a key that
  `src/mods/Schemas.lua` marks `f.opt(...)` without a guard. The three above
  were found by running, not reading — this one should be a static sweep.
  *Verify:* a new `tests/engine/` guard that greps `src/` against the schema.
- [ ] **2.5 Untrusted-input boundaries.** Mod ZIPs and third-party Lua chunks
  (`src/mods/Loader.lua`), save load (`src/core/SaveSerializer.lua`), link
  packets (`src/link/`, `src/net/`), update fetch. Look for unchecked
  `io.open`, `pcall`-less calls into third-party code, and nil arithmetic on
  decoded data. *Verify:* a fuzz/malformed-input case per boundary.
- [ ] **2.6 Driver errors lose their traceback.** `main.lua:417` prints
  `tostring(err)` with no `debug.traceback`, so a driver failure gives one line
  and no stack. *Verify:* a deliberately throwing driver prints a stack.
- [ ] **2.7 Clear the 12 luacheck warnings** where the cleanup is provably safe.
  Two look like real dead logic (`src/core/Strings.lua:49` "loop is executed at
  most once"; `src/render/SecondScreen.lua:8` `ffi` overwritten before use) —
  read those two before deciding. *Verify:* `./scripts/lint.sh`

## Phase 3 — The content pack abstraction

Turn `POKEPORT_DATA_DIR` from a test hook into a first-class product feature.

- [ ] **3.1 Name packs instead of passing paths.** A `packs/<name>/` convention
  and a launch option (`--pack=<name>`), so `kanto-rom` and our own pack are
  two names behind one interface. Additive; no upstream file need change
  beyond the option parse. *Verify:* `love . --pack=fixture` boots.
- [ ] **3.2 Pack manifest + validator.** Version, display name, required engine
  version, the 16 modules present and well-formed. Fail with a message naming
  the missing module, not a nil index. *Verify:* validator rejects a pack with
  a module removed.
- [ ] **3.3 Grow the fixture pack to a playable slice.** The current blocker is
  a missing player sprite; after that, whatever the next crash names. Target:
  walk an overworld, enter one battle, win it. This is the single most valuable
  increment in the document — it converts "boots" into "is a game".
  *Verify:* a driver walks, battles and screenshots without a crash.
- [ ] **3.4 Wire the golden-screenshot tier.** Blocked only on 3.3. Write
  `tests/drivers/shots_fixture.lua` for the four shots in
  `tests/modkit/shots.lua`, bless goldens, drop the hard-fail in
  `scripts/test.sh`. *Verify:* `WITH_SHOTS=1 ./scripts/test.sh`
- [ ] **3.5 Move Kanto defaults out of `src/` into the kanto pack.** The badge
  list, `hmMoves`, `fallbackMove`, the Yellow trade table, the Cinnabar and
  Dojo seeds, `SsAnneLayout`, `FieldDefaults` — all listed with line numbers in
  `docs/IP-FIREWALL.md`. Each moves behind a pack value with the current
  Kanto value as the kanto pack's content. Do these **one at a time**; this is
  the highest-conflict area for upstream merges.
  *Verify:* Kanto behaviour unchanged, and the fixture pack stops inheriting
  Kanto defaults it never asked for.

## Phase 4 — Product A: the evolved public fork

Only start once Phase 1 is complete. Ideas, not commitments — the point is
that each is an independent arm on the crystal.

- [ ] **4.1 A third ruleset** alongside `gen1_faithful` and `modern_clean`
  (`src/battle/rulesets/`). The registry already supports it.
- [ ] **4.2 Quality-of-life options** behind the existing options system so
  every one is switchable and none changes default behaviour.
- [ ] **4.3 Contribute the upstreamable fixes back.** `U-001` in
  `docs/DIVERGENCE.md` is ready: it unblocks a tier upstream documents as
  impossible and fixes a real mod-author crash.

## Phase 5 — Product B: original IP

- [x] **5.0 Derivation script.** `tools/make_ip_build.sh` generates Product B
  from this engine: strips every hard IP category, installs `packs/<name>/`
  from the ROM-free dataset, rebrands, auto-quarantines the suites that depend
  on stripped Kanto content, and runs the IP gate. Derived rather than copied,
  so it cannot drift from the engine. Output verified: boots on
  `packs/starter` with roster `FIXMON_A/B/C` and no Gen 1 species, engine and
  modkit tiers both green, hard gate clean, 975 soft references tracked.
  *Verify:* `tools/make_ip_build.sh /tmp/ipbuild`
- [ ] **5.0b Publish it.** Blocked: the GitHub App is scoped to this repository
  only and returned 403 on repo creation. Create `original-ip-engine` by hand,
  then run the publish commands the script prints.
- [ ] **5.1 Decide the game.** Name, setting, creature system, art direction.
  This is a design decision, not an engineering one, and it blocks everything
  else in this phase.
- [ ] **5.2 Author the pack.** Creatures, moves, types, maps, tilesets,
  sprites, text, trainers, encounters, music. The engine is ready; this is
  content work and it is the bulk of the project.
- [ ] **5.3 Strip and verify.** Run the IP sweep in `/recomp` until it returns
  nothing. Release gate, not cleanup.
- [ ] **5.4 Rebrand.** Title, logo, launcher, window title, bundle ids, package
  names, updater slug (already one definition — `src/update/Repo.lua`).
- [ ] **5.5 Retain the MIT notice.** `LICENSE.MD` ships unchanged, our notice
  alongside. This is the condition that makes selling legitimate.

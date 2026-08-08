# Divergence ledger

Every intentional deviation from upstream `bryanthaboi/gen1recomp`, why it
exists, and what a merge conflict in that file means.

**Read this before resolving any conflict from `git merge upstream/dev`.**
A conflict in a file listed here is expected and the resolution rule is
written down. A conflict anywhere else means we diverged somewhere we did not
mean to — prefer upstream's side and move our change into an overlay.

## Sync log

| Date       | Upstream base            | Notes                                  |
| ---------- | ------------------------ | -------------------------------------- |
| 2026-08-08 | `dev` @ `cab62ff` (v0.1.75) | Initial import, full history preserved |

## Conflict policy

| Rule            | Meaning                                                                |
| --------------- | ---------------------------------------------------------------------- |
| **ours-wins**   | Keep our side. Re-apply any genuinely new upstream logic by hand.       |
| **upstream-wins** | Take upstream's side, then re-apply our delta on top. It is small.    |
| **additive**    | A file upstream does not have. Conflicts are impossible by construction. |

---

## Ledger

### D-001 — `.gitignore`: allow `.claude/`
- **Rule:** ours-wins (one added allowlist line)
- **Why:** upstream ignores all dotdirs (`.*`) with a small allowlist. The
  `/recomp` and `/gitkit` skills are part of this fork's deliverable and must
  travel with the branch.
- **Files:** `.gitignore`
- **Revert cost:** nil — delete the `!.claude/` line.

### D-002 — `.claude/skills/`: the `/recomp` and `/gitkit` skills
- **Rule:** additive
- **Why:** the working method for this fork, encoded so it survives a new
  session. Upstream has no equivalent and will never conflict.
- **Files:** `.claude/skills/recomp/SKILL.md`, `.claude/skills/gitkit/SKILL.md`

### D-003 — `src/update/Repo.lua`: single-definition update slug
- **Rule:** additive (the new file) + upstream-wins (the three call sites)
- **Why:** upstream hardcodes `bryanthaboi/gen1recomp` in three places. A fork
  that ships a build with any copy unchanged offers its users upstream's
  releases and self-installs them over the fork. See commit `024c684`.
- **Files:** `src/update/Repo.lua` (new), `src/update/Check.lua`,
  `src/update/check_worker.lua`, `src/update/SwitchOta.lua`
- **Conflict resolution:** if upstream refactors any of the three call sites,
  take their version and re-apply the one-line `Repo` lookup. The delta is a
  single expression per file.
- **Guarded by:** `tests/engine/update_repo_slug_test.lua`

### D-004 — updater tests assert the configured slug, not a literal
- **Rule:** upstream-wins
- **Why:** upstream pins the literal upstream URL, so any fork retarget reads
  as a test regression while proving nothing the derivation does not.
- **Files:** `tests/engine/update_check_tests.lua`,
  `tests/engine/update_tests.lua`
- **Conflict resolution:** take upstream's test body, then swap the literal for
  `"https://github.com/" .. Check.REPO .. "/releases/latest"`.

---

## Upstreamable

These are fixes to genuine upstream defects, not fork preferences. They carry
no Nintendo-derived content and nothing fork-specific, so they can be offered
back as PRs. Keeping them listed separately means a future contribution does
not have to re-derive which of our changes are generic.

### U-001 — a ROM-free dataset can boot and render
- **Commit:** `6767f31`
- **Files:** `src/import/RomImporter.lua`, `src/render/TileRenderer.lua`,
  `src/render/SpriteRenderer.lua`, `src/world/OverworldController.lua`,
  `tests/engine/data_dir_boot_test.lua`, `tests/modkit/shots.lua`,
  `scripts/test.sh`
- **What:** four defects that only fire on an authored dataset:
  1. `RomImporter.isReady()` ignored `POKEPORT_DATA_DIR`, so `love.load` opened
     the ROM picker and the override — which `src/core/Data.lua` already
     honoured — was unreachable from a real LOVE process.
  2. `TileRenderer` read `tilesPerRow` unguarded although
     `src/mods/Schemas.lua` declares it **optional** for mod tilesets, so a
     schema-valid tileset crashed the quad loop.
  3. `OverworldController` indexed `field.flyWarps` unguarded in two places
     while a third read in the same file already wrote `or {}`.
  4. `SpriteRenderer.new()` nil-indexed a missing sprite def, reporting the
     failure where neither the sprite id nor the caller is visible.
- **Value to upstream:** unblocks the golden-screenshot tier they document as
  impossible, and fixes a real crash for mod authors (2).

---

## Deliberately NOT diverged

Recording these stops the same argument being had twice.

| Thing | Why we left it |
| --- | --- |
| `LICENSE.MD` | MIT, and the notice must be retained. Never edit. Our own additions are covered by the same license unless we say otherwise. |
| CI `github.repository == 'bryanthaboi/gen1recomp'` gates | They already fail safe on a fork: signing, self-hosted runners and release publishing all switch off. That is what we want. |
| `mobile/android/love` (154 MB vendored) | Upstream's vendored love-android. Touching it would make every sync painful for no gain. |
| The ROM-import model itself | It is upstream's legal shield and ours: no Nintendo content is ever committed. See `docs/IP-FIREWALL.md`. |
| Upstream attribution in `README.md`, `docs/` | MIT requires the notice; the credit to pret and to BOIS CLUB GAMES stays regardless. |

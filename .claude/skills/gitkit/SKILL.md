---
name: gitkit
description: Git discipline for a long-lived fork that must stay mergeable with its upstream. Use when syncing from upstream, starting or landing an increment, resolving a fork merge conflict, pushing, opening a draft PR, or recovering from a merged/stale branch. Also use whenever /recomp reaches a git step. Triggers on "sync upstream", "merge upstream", "land this", "push and PR", "fork conflict", "rebase onto upstream", "start an increment".
---

# gitkit

Git workflow for a fork whose whole value depends on still being able to pull from
upstream two years from now. Every rule here exists to protect that.

## The topology

Three remotes, two of them read-only in practice:

| Remote     | URL                                                   | Push? |
| ---------- | ----------------------------------------------------- | ----- |
| `origin`   | `Sparkey333/Pokemon-Gen1-Recomp-Bryan-Thaboi`          | yes   |
| `upstream` | `bryanthaboi/gen1recomp`                               | never |

`upstream`'s push URL is deliberately set to a bogus string so a stray
`git push upstream` fails loudly instead of attempting to write to someone
else's repository:

```sh
git remote set-url --push upstream DISABLED_read_only_upstream
```

Verify the topology before anything else:

```sh
git remote -v
```

If `upstream` is missing, restore it:

```sh
git remote add upstream https://github.com/bryanthaboi/gen1recomp.git
git remote set-url --push upstream DISABLED_read_only_upstream
git fetch upstream dev
```

Upstream's default branch is **`dev`**, not `main`. `main` is their release
branch and trails `dev`. Sync from `dev` unless you specifically want a release
boundary.

## Why the history is merged, not squashed

This fork imported upstream with `--allow-unrelated-histories` so that upstream's
real commits are ancestors of ours. That is the single decision that keeps
`git merge upstream/dev` cheap forever. **Never** flatten it:

- Never `squash` an upstream sync.
- Never rewrite history that contains upstream commits.
- Never force-push a branch that upstream history has been merged into.

If someone hands you a "clean snapshot" fork with no upstream ancestry, the
repair is to re-import upstream as an unrelated history and merge — not to
cherry-pick forever.

## Syncing from upstream

Run this on a clean tree, on the integration branch, never mid-increment:

```sh
git fetch upstream dev --tags
git merge upstream/dev
```

Conflicts are expected in exactly the files we chose to diverge in. Before
resolving anything, read the divergence ledger (`docs/DIVERGENCE.md`) — it
records *why* each divergent file differs, which tells you which side to keep:

- Conflict in a file the ledger lists as **ours-wins** → keep our side, re-apply
  any genuinely new upstream logic by hand, note it in the ledger entry.
- Conflict in a file the ledger does **not** mention → we were not supposed to be
  diverging here. Prefer upstream's side and move our change into an additive
  overlay file instead.

After every sync, before committing the merge:

```sh
./scripts/test.sh && ./scripts/lint.sh
```

A sync that breaks the suite is not done. Commit the merge only once it is green,
and record the upstream commit you landed on:

```sh
git log --oneline -1 upstream/dev   # put this SHA in the ledger's sync log
```

## Increments

One increment = one branch = one PR = one ledger entry. Increments are small
enough that reverting one never unravels another.

```sh
git fetch origin
git checkout -b claude/<short-slug> origin/claude/gen1-recomp-setup-s535iv
```

Branch naming: `claude/<verb>-<noun>`, lowercase, hyphens. `claude/add-content-pack-loader`,
not `claude/ContentPacks2_FINAL`.

**The designated branch for this project is `claude/gen1-recomp-setup-s535iv`.**
Work lands there. Do not push to `main` or to any branch not named by the user.

## The pre-push gate

Never push red. Run both, always, even for a docs-only change (a docs change can
break `tests/switch_transfer_docs_test.lua`, which gates doc content):

```sh
./scripts/test.sh          # every tier this checkout can run
./scripts/lint.sh          # luacheck over src/
```

Known-good baseline on a ROM-less checkout: **all tiers pass**, luacheck reports
**0 errors**. The T3 content tier and `run_link_tests` skip themselves without
`data/generated/` — that is correct, not a failure. If your change raises the
luacheck warning count, either fix it or justify it in the commit message.

## Committing

Conventional-ish subject, imperative, under 72 chars. Body explains *why*, not
what — the diff already says what. Every commit ends with:

```
Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
```

Use a heredoc so multi-line bodies survive shell quoting:

```sh
git commit -F - <<'EOF'
feat(content): load species tables through the pack interface

...why...

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
```

## Pushing

Always `-u`, always with backoff on network failure only (never retry through a
rejected non-fast-forward — that means someone else moved the branch, so fetch
and merge instead):

```sh
for i in 1 2 3 4; do
  git push -u origin "$(git branch --show-current)" && break
  sleep $((2 ** i))
done
```

The first push of this fork moves ~200 MB (`mobile/android/love` is a 154 MB
vendored tree). Expect it to be slow once; later pushes are incremental.

## Pull requests

After pushing, open a **draft** PR if no open PR exists for the branch. Use the
GitHub MCP tools (`mcp__github__*`) — there is no `gh` CLI in this environment.

There is no PR template in this repository, so write the body plainly:
what changed, why, how it was verified (paste the tier summary line), and what
is deliberately left out.

End every PR body and every GitHub comment with:

```
---
_Generated by [Claude Code](https://claude.ai/code)_
```

Then subscribe to the PR so CI failures come back to the session:

```
mcp__github__subscribe_pr_activity(owner, repo, pullNumber)
```

## Recovery

**The PR for the designated branch already merged.** A merged PR is finished; it
cannot carry new work. Restart the branch from the default branch, keeping the
name:

```sh
git fetch origin main
git checkout -B claude/gen1-recomp-setup-s535iv origin/main
```

Force-with-lease is acceptable *only* when the branch holds nothing but
already-merged history. If it carries unmerged commits, rebase them onto the new
base instead of discarding them.

**Merge conflict notice on an open PR.** Drive it to resolution rather than
asking: merge the base branch in, resolve, re-run the gate, push. Comment only if
both sides genuinely changed the same logic and picking one loses behavior.

**Accidentally diverged from upstream in a file that should not have.** Move the
change out of the upstream file into an additive overlay, restore the upstream
file with `git checkout upstream/dev -- <path>`, and re-run the gate.

**A big push died halfway.** Git pushes are atomic per-ref; a dead push left
nothing behind. Just retry.

## What never happens

- No `git push --force` to a shared branch.
- No `git rebase -i` (not supported in this environment) and no interactive flags.
- No committing `data/generated/`, `assets/generated/`, or any ROM bytes — see
  `.gitignore` and the IP firewall section of `/recomp`.
- No pushing to `upstream`.
- No commit or PR text naming the model identifier.

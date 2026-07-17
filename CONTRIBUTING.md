# CONTRIBUTING.md — for coding agents

This is a workflow guide for agents (Claude Code or similar) making changes in this repo. For what
the project *is* and how it's structured, read `AGENT.md` first.

## Use the `superpowers` skill system if it's available

Both Claude Code (`~/.claude/plugins/.../superpowers-marketplace`) and Antigravity/Gemini CLI
(`~/.gemini/extensions/superpowers`) on this machine have the `superpowers` skill/extension
installed. If your environment exposes it (a `Skill`/`skill`/`activate_skill` tool, or a
`using-superpowers` entry in your available-skills listing), use it - don't skip straight to
default behavior when a relevant skill exists. Skills particularly relevant to this repo:

- **`test-driven-development`** - use before writing implementation code for any feature or
  bugfix, and required reading before touching this repo's test suite (see `tests/` once it
  exists).
- **`using-git-worktrees`** / **`dispatching-parallel-agents`** / **`subagent-driven-development`**
  - directly applicable to the "Multi-agent / parallel workflows" section below; prefer these over
  ad hoc worktree/subagent handling if the skill is available.
- **`systematic-debugging`** - use before proposing a fix for any bug or unexpected behavior; pairs
  with this file's "Verify against the live shell" section below.
- **`verification-before-completion`** - run before claiming anything is fixed/complete/passing;
  the same evidence-before-assertions spirit as this file's live-verification loop.

If a skill's instructions and this file disagree, the more specific/current one wins - skills get
updated independently of this file, so don't assume this file has the last word if a skill exists
that covers the exact situation.

## Verify against the live shell, not just "no syntax errors"

There's no test suite and no compiler to catch mistakes — QML errors only surface at runtime, in
the log, when the affected component is actually reached. "The file saved without an Edit-tool
error" is not evidence a change works.

The reliable loop used throughout this project's history:

1. Make the edit.
2. Wait ~2-3s for the hot-reload, then check the log for new errors:
   ```bash
   LOG=/run/user/$(id -u)/quickshell/by-id/$(ls /run/user/$(id -u)/quickshell/by-id/ | head -1)/log.log
   tail -30 "$LOG" | grep -iE 'error|WARN scene'
   ```
   (`WARN scene: <file>[<line>]: ...` is a QML runtime error/warning with a precise location — treat
   these as real bugs to fix, not noise, unless you recognize them as pre-existing/unrelated.)
3. If the change is behavioral (not just visual), **drive the actual state change and read back a
   real value**, rather than reasoning about it in the abstract. This project's Hyprland/PipeWire
   integrations are full of "should be reactive" assumptions that turned out subtly wrong in
   practice (see the two examples below). A temporary `console.log` in an `onXChanged` handler,
   checked against `grep` on the log file, then removed once confirmed, is the standard technique:
   ```qml
   onSomePropertyChanged: console.log("[TempDebug] someProperty ->", someProperty)
   ```
   Always remove these before considering the change done — check with `git diff` that no stray
   `console.log`/`[TempDebug]`/similar markers are left in the final diff.
4. Don't stop at "the property changed" if the ask was about visible/clickable behavior — a property
   can be logically correct while the compositor still doesn't render or route input to it correctly
   (see the layer-shell gotchas in `AGENT.md`). When in doubt, ask the user to confirm the actual
   visual/interactive result before declaring it fixed.

Two real examples from this project's history that justify the paranoia:
- A gate (`if (!Audio.ready) return`) copied from a nearby, superficially similar handler silently
  ate every audio-device-switch toast, because the *new* device's `ready` flag lags the pointer
  swap by a tick. Nothing about this was visible from reading the code; only driving a real device
  switch and reading the log exposed it.
- A "fix" that made a bar clickable under fullscreen+special-workspace, verified via debug logging
  as "layer and mask both correct," still failed for an unrelated reason (a same-layer stacking
  conflict with a different widget) that only showed up once the user tried it for real.
- A new toast's background used `Appearance.colors.colLayer1` - a legitimate, correctly
  transparency-aware design token, chosen by reasonable-looking analogy to other cards in the
  codebase. It still rendered as flat unblurred transparency in practice, for two compounding
  reasons invisible from reading the QML alone: `contentTransparency` (which `colLayer1` derives
  from) wasn't gated on the `transparency.enable` toggle the way `backgroundTransparency` was, and
  even after fixing that, `colLayer1`'s alpha never cleared the Hyprland companion config's
  per-namespace `ignore_alpha` blur threshold the way `colLayer0` does. "Uses a real design token"
  is not the same as "uses the *right* design token for this position in the surface hierarchy" -
  see AGENT.md's `colLayer0` vs `colLayer1` note.

## Don't guess at `hyprctl` CLI syntax on this machine

This machine's Hyprland config uses a Lua binding layer, which changes what `hyprctl dispatch ...`
needs to look like when invoked manually from a shell (see `AGENT.md`). If a `hyprctl dispatch`
command errors with something mentioning Lua, don't retry variations blindly - work out the
`hl.dsp....(...)` form from the relevant `~/.config/hypr/hyprland/*.lua` file instead of guessing.
This only affects manual/CLI invocations for testing, not the QML code itself.

## Reuse before building new

Check `modules/common/widgets/` before writing a new UI primitive - tooltips, combo boxes, sliders,
form rows for the settings page, card/tile layouts, etc. almost all already exist there and are used
throughout `modules/ii/`. A fix or feature that touches a shared widget (e.g. `StyledComboBox`)
benefits every place that widget is used - that's usually preferable to a one-off local
implementation, but also means changes there have wider blast radius, so verify a couple of call
sites, not just the one you were asked about.

Pull visual values (colors, spacing, font sizes, animation curves) from `Appearance.qml` rather than
hardcoding. This is a Material 3 / Material 3 Expressive shell — match that language for new UI
(rounded containers, tonal color roles, expressive motion) rather than introducing a different look.

## Settings additions are two-sided

A new persisted option needs both halves, or it silently does nothing:
1. The schema property in `Config.qml` (inside the correct nested `JsonObject`).
2. A corresponding row in the relevant `modules/ii/settings/pages/*.qml` file, wired with
   `checked`/`value`/`currentValue` reading from `Config.options....` and an `on*Changed` handler
   writing back to it.

If a feature is gated by config (e.g. "always show X"), search for where the sibling options are
consumed (usually a `Resource`/similar component's `shown`/`visible` binding) and wire the new one
into every layout variant that repeats the pattern (this codebase often has near-duplicate blocks
for e.g. horizontal-bar vs vertical-bar vs "material style" variants of the same widget - grep for
the sibling property name to find all of them before considering the wiring complete).

## Multi-agent / parallel workflows (git worktrees)

This repo lives at `~/.config/quickshell/end4-pC` and is loaded by exactly one running process,
`qs -c end4-pC`, pointed at that exact directory. That has real consequences once more than one
agent (main session + subagents, or several parallel Claude Code sessions) is touching the repo at
once:

- **Only the primary checkout hot-reloads against the live shell.** A `git worktree add
  ../end4-pC-<feature> <branch>` checkout elsewhere is a completely separate directory - editing
  files there does *not* trigger the running instance's hot-reload, and the log-grepping /
  `console.log` verification loop above will show nothing for it. If an agent needs live verification
  from inside a worktree, either point a second, disposable `qs -c <path-to-worktree>` instance at it
  (fine for checking "does this even load without errors," but a second instance means a second OSD/
  bar/etc. on screen - don't leave it running), or accept that real verification happens after
  merging back into the primary checkout, not before.
- **Partition work by file/module, not just by feature name, before going parallel.** Two agents
  editing the same file concurrently (even in separate worktrees) just means a merge conflict later
  instead of a collision now - worktrees don't prevent that, they only defer it. Before starting
  parallel agent work, check whether the planned changes touch the same files; if they do, either
  serialize that part of the work or explicitly split who owns which section.
- **Treat `Config.qml`, `Appearance.qml`, and `GlobalStates.qml` as hot spots.** Nearly every feature
  ends up adding a property to one of these three files. If two parallel agents both add settings in
  the same nested `JsonObject`, or both touch the same color-token block, that's a near-guaranteed
  merge conflict even with unrelated features - flag this to the user up front rather than
  discovering it at merge time.
- **Small, single-purpose commits (see below) are what make parallel branches mergeable at all.** A
  worktree whose entire session is one giant commit is much more likely to conflict messily on merge
  than one with granular commits a reviewer (human or agent) can cherry-pick or rebase around.
- **Re-run the live-verification loop against the primary checkout after merging**, even if each
  worktree "passed" its own review - the merge itself, and the fact that the changes were never
  actually hot-reloaded together until now, are both new sources of breakage.
- **Clean up (`git worktree remove <path>`) once a branch is merged.** Stale worktrees pointing at
  already-merged or abandoned branches are easy to lose track of and easy to mistake for
  still-in-progress work later.

If the planned changes are small or touch a single, self-contained module, plain sequential work in
the primary checkout is usually faster than the overhead of standing up a worktree - reach for
worktrees when tasks are genuinely independent (different modules/files) and worth running
concurrently, not as a default for every subagent dispatch.

## Git conventions

- Commit **one logical change per commit** unless told otherwise - a bug fix, a new feature, a typo
  fix, and a UI enhancement discovered along the way are separate commits, even if they landed in
  the same conversation back to back.
- Write real commit messages (not caveman-terse, regardless of any session-level tone setting) -
  explain *why*, especially for anything non-obvious (a gotcha worked around, a race condition
  fixed, a naming/priority decision). Future-you (or the next agent) won't have this conversation's
  context.
- Never push without explicit confirmation for that specific push. An earlier approval to push
  doesn't carry forward to later, unrelated changes.
- `git remote -v` before assuming which remote is "upstream" vs "the fork you push to" - this repo
  has both, and they matter for where a `git pull`/`git push` actually lands.
- **Hard rule: agents do not add themselves as co-authors** (no `Co-Authored-By: <agent/model>` or
  similar trailer). Commits in this repo are attributed to the human maintainer only, regardless of
  which agent or model did the work.

## Style

- No comments explaining *what* code does - names should do that. A comment is only worth adding for
  a non-obvious *why*: a compositor quirk being worked around, a unit conversion that isn't visually
  obvious (e.g. MiB→KB to match `/proc/meminfo`'s units), a gate that looks redundant but isn't.
- Don't add config options, abstractions, or generalized "for future use" plumbing beyond what was
  asked. This is a personal shell config, not a library - concrete and specific beats flexible and
  speculative.

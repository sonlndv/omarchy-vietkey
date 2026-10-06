## What this does

<!-- One or two sentences: what changed and why. -->

## Why

<!-- The problem this solves, or the request it answers. Link an issue if there is one. -->

## What changes

<!-- Bullet the concrete behavior changes. Call out defaults: unchanged vs changed. -->

## Tested

<!-- Required. A PR without real test output here will not be reviewed. -->

- `npm test` — paste the pass/fail summary line.
- `npm run lint` — qmllint + shellcheck, paste the result.
- `test/bindings-migration.sh` — if you touched `bin/keymarchy-setup` or the bindings block.
- `test/e2e-typing.sh` — if you touched typing/engine behavior (runs a private fcitx5, never touches your live session).
- Live check on an actual Omarchy session, if the change affects anything the harness can't cover (D-Bus timing, Hyprland reload, real fcitx5 restart). Say what you ran and what you saw.

## Risk / rollback

<!-- Does this touch bindings.lua, fcitx5 group/profile, or anything else backed up with .bak.<stamp>? Confirm --dry-run output is unaffected in scope, or paste the diff. -->

## Checklist

- [ ] Existing fcitx5 group entries are never reordered or removed by a change here
- [ ] No `sudo` added anywhere in `bin/keymarchy-setup` or QML (package installs stay in `omarchy-pkg-add`)
- [ ] `manifest.json` still validates (`omarchy plugin validate .` if you touched it)
- [ ] README updated if user-facing behavior changed
- [ ] Tests above actually ran, not assumed

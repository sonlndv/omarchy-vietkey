# Omakey — input languages for Omarchy

**English and Vietnamese out of the box, any other language when you want it.**
Omakey puts the current language on the Omarchy bar (`EN`, `VI`, `JA`, `KO`,
`ZH`, `TH`), switches with **Ctrl+Shift**, and adds or removes languages from
its menu. It is a front end for [fcitx5](https://fcitx-im.org/), which Omarchy
already runs.

![Omakey menu and language settings](preview.png)

Omakey is the successor to VietKey. The plugin id is still `sonlndv.vietkey`,
so existing installs upgrade in place (see [Upgrading from VietKey](#upgrading-from-vietkey)).

## Install

```sh
omarchy plugin add https://github.com/sonlndv/omarchy-vietkey.git --enable
~/.config/omarchy/plugins/sonlndv.vietkey/bin/omakey-setup
```

Run `omakey-setup` once. By default it sets up English + Vietnamese:

1. installs missing packages (only those) with `omarchy-pkg-add`, which asks
   for your password; Omakey itself never runs sudo,
2. appends the engines to your fcitx5 input method group over D-Bus, without
   reordering or removing anything already there,
3. on a first install only: one input state for every window, and turns off
   fcitx5's lone-Shift switching,
4. writes default Unikey options (Telex, Unicode) if you have none yet,
5. adds the **Ctrl+Shift** binding to `~/.config/hypr/bindings.lua`, between
   `-- omakey:start` and `-- omakey:end`.

If a new engine needs fcitx5 to restart, Omakey says so and asks first. Save
your work: open apps may need to be refocused or reopened afterwards. If you
say no, the packages stay installed and the group is unchanged; run it again
to finish.

Every file it changes is backed up as `<file>.bak.<date-time>`. To see what
it would do without changing anything:

```sh
omakey-setup --dry-run
```

`bin/vietkey-setup` still works: it just runs `omakey-setup`.

## Choosing languages

Click the badge and pick **Add language…**. While you only have English, the
menu offers **Set up languages…** instead, which opens the same picker with
Vietnamese already ticked:

- English is always on and can't be removed.
- Vietnamese is ticked by default; untick it if you don't want it.
- Tick anything else you want from the list below.

**Install and add** opens Omarchy's floating terminal and runs
`omakey-setup --add <languages>`, so you can see the package install and
answer the restart question. You can also do it by hand:

```sh
omakey-setup --add ja,ko        # ids from the table below
```

**Remove language…** drops a language's engines from the fcitx5 group. The
packages stay installed (`omakey-setup --remove mozc` does the same).

### Languages in v1

| Language                    | Badge | Package                 | fcitx5 engine |
| --------------------------- | ----- | ----------------------- | ------------- |
| English                     | `EN`  | (built in)              | `keyboard-us` |
| Vietnamese (Telex / VNI)    | `VI`  | `fcitx5-unikey`         | `unikey`      |
| Japanese                    | `JA`  | `fcitx5-mozc`           | `mozc`        |
| Korean                      | `KO`  | `fcitx5-hangul`         | `hangul`      |
| Chinese Simplified (Pinyin) | `ZH`  | `fcitx5-chinese-addons` | `pinyin`      |
| Chinese Traditional (Zhuyin)| `ZH`  | `fcitx5-chewing`        | `chewing`     |
| Thai                        | `TH`  | `fcitx5-libthai`        | `libthai`     |
| Anything else               | code  | `fcitx5-m17n`           | from fcitx5's m17n list |

For "anything else" (`--add other`), Omakey installs `fcitx5-m17n`; pick the
engine for your language in `fcitx5-configtool`. Omakey then shows it with a
badge made from its language code. Engines you added yourself (Anthy,
Shuangpin, …) appear under their language too.

## Switching

| Action                    | Effect                                              |
| ------------------------- | --------------------------------------------------- |
| **Ctrl+Shift**            | The next language, in order, back to English after the last |
| Right click the badge     | Same as Ctrl+Shift                                  |
| Click the badge           | Menu: pick any language or mode                     |

Ctrl+Shift cycles through every language you have enabled, in the order
shown in the menu and in **Omakey Settings…** (your fcitx5 group order,
English first):

- **English only:** Ctrl+Shift does nothing; add a language first.
- **Two languages:** it flips between them, e.g. English ↔ Vietnamese.
- **Three or more:** it steps to the next one and wraps around, e.g.
  English → Vietnamese → Japanese → English.

A language is entered on its first engine (Vietnamese on Unikey, Japanese on
Mozc). Change the order with the ↑/↓ buttons in Omakey Settings.

Ctrl+Shift fires when you let go, and only if you pressed nothing else, so
shortcuts like Ctrl+Shift+T keep working.

## The badge and menu

The badge shows the language code, in your theme's accent colour when it
isn't English, with the mode next to it where it matters: `Telex` / `VNI` for
Vietnamese, `Pinyin` / `Zhuyin` for Chinese.

```
 ✓ [EN] English
   [VI] Tiếng Việt · Vietnamese
          Telex
          VNI
   [JA] 日本語 · Japanese
 ──────────────────────────────
   󰐕 Add language…
   󰍴 Remove language…
   󰒓 Omakey Settings…
 ──────────────────────────────
   Ctrl+Shift cycles: EN → VI → JA → EN
```

Arrow keys (or `j`/`k`), Enter and Esc work. In Add/Remove, Esc goes back to
the main menu.

The badge updates straight away when you switch with Omakey or Ctrl+Shift,
and again whenever window focus changes. VietKey polled every 700 ms; Omakey
only keeps a slow fallback check (`fallbackRefreshMs`, 5 s by default) for
switches made with fcitx5's own hotkeys, which send no event. The old
`pollIntervalMs` setting is no longer used.

## Omakey Settings

**Omakey Settings…** in the menu (or `omarchy-shell sonlndv.vietkey settings`)
opens one dashboard for everything. Changes apply straight away.

- **Languages** (left): your languages in Ctrl+Shift order, with a check on
  the active one. **↑/↓** move a language in the fcitx5 group, which changes
  the cycle order (English always stays first). **󰍴** removes it from the
  group; packages stay installed. English can't be moved or removed.
  **Add language…** opens the picker in the menu; installing may ask to
  restart fcitx5, and always asks first.
- **Options** (right), for the language selected on the left:
  - Vietnamese: the Unikey page, below.
  - A language with several engines in your group (e.g. Mozc and Anthy for
    Japanese, Pinyin and Shuangpin for Chinese): pick the engine.
  - Other engines: a link to `fcitx5-configtool`.
  - Keyboard layouts (Arabic, Russian, …): just the layout; nothing to set.
- **General** (bottom): the Ctrl+Shift order, and whether the mode (Telex,
  Pinyin, …) shows next to the badge (the same as `omarchy bar set
  sonlndv.vietkey showModeName …`).

Keys: ↑/↓ select, Ctrl+↑/↓ move, Enter switches to the language, Delete
removes it, Tab (or →) goes to the options where the arrows move and
Enter/Space picks, Esc closes.

**Vietnamese** keeps VietKey's Unikey page. Changes apply and save
immediately.

- **Kiểu gõ · Input method:** Telex or VNI
- **Bảng mã · Charset:** Unicode (default), TCVN3, VNI Win, VIQR, BK HCM 2,
  CString, NCR Decimal, NCR Hex
- **Tuỳ chọn · Options**
  - Kiểm tra chính tả · spell check
  - Tự khôi phục từ không phải tiếng Việt · leave English words like `class`
    and `windows` as typed
  - Đặt dấu kiểu mới · modern tone placement (oà, uý)
  - Cho phép gõ dấu tự do · type tone marks anywhere in the word
  - Xử lý W ở đầu từ · W at the start of a word becomes Ư

**Other engines** don't have an Omakey page yet; the dashboard links to
`fcitx5-configtool` (install it if you don't have it).

### Telex

| Keys | Result | Keys | Result |
| ---- | ------ | ---- | ------ |
| `aa` `ee` `oo` | â ê ô | `s` | sắc (á) |
| `aw` | ă | `f` | huyền (à) |
| `ow` `uw` / `w` | ơ ư | `r` | hỏi (ả) |
| `dd` | đ | `x` | ngã (ã) |
| | | `j` | nặng (ạ) |
| | | `z` | remove the mark |

### VNI

| Keys | Result | Keys | Result |
| ---- | ------ | ---- | ------ |
| `a6` `e6` `o6` | â ê ô | `1` | sắc |
| `a8` | ă | `2` | huyền |
| `o7` `u7` | ơ ư | `3` | hỏi |
| `d9` | đ | `4` | ngã |
| | | `5` | nặng |
| | | `0` | remove the mark |

## Upgrading from VietKey

Same plugin id, so it's an update, not a remove and re-add:

```sh
omarchy plugin update sonlndv.vietkey
~/.config/omarchy/plugins/sonlndv.vietkey/bin/omakey-setup
```

`omakey-setup` finds the old `-- vietkey:start` … `-- vietkey:end` block in
`~/.config/hypr/bindings.lua` and replaces it with the `-- omakey:start` …
`-- omakey:end` block (backing the file up first). Your Unikey settings and
your fcitx5 group are kept as they are. Run it with `--dry-run` first to see
the exact change.

Until you run it, the old binding keeps working (it calls `fcitx5-remote -t`
directly); the new one goes through Omakey so it cycles through all your
languages in order.

## Bar options

```sh
omarchy bar move sonlndv.vietkey --section right
omarchy bar set sonlndv.vietkey showModeName false --json       # badge only
omarchy bar set sonlndv.vietkey fallbackRefreshMs 15000 --json  # slower fallback check
```

## Commands

The plugin is still addressed by its id, `sonlndv.vietkey`:

```sh
omarchy-shell sonlndv.vietkey toggle          # next language in order (what Ctrl+Shift runs)
omarchy-shell sonlndv.vietkey english         # English
omarchy-shell sonlndv.vietkey setLanguage ja  # a language by id: vi ja ko zh-Hans zh-Hant th
omarchy-shell sonlndv.vietkey setMode VNI     # Vietnamese, VNI (or Telex)
omarchy-shell sonlndv.vietkey addLanguage     # open the language picker
omarchy-shell sonlndv.vietkey togglePanel     # open / close the menu
omarchy-shell sonlndv.vietkey settings        # open / close Omakey Settings
```

## Troubleshooting

- **Nothing changes when I type:** make sure fcitx5 is running
  (`systemctl --user status omarchy-fcitx5`); the badge dims when it isn't.
  Then run `omakey-setup` again.
- **Ctrl+Shift does nothing:** check the `-- omakey:start` block is in
  `~/.config/hypr/bindings.lua`, then `hyprctl reload`.
- **A language I added doesn't show up:** fcitx5 probably needs the restart
  you declined. Run `omakey-setup --add <id>` again and answer yes.
- **The badge is a few seconds behind after using fcitx5's own hotkey:** that
  is the fallback check; use Ctrl+Shift or the menu, or lower
  `fallbackRefreshMs`.
- **An Electron app (VS Code, Discord, Slack) types badly:** start it with
  `--enable-wayland-ime`.

## Uninstall

```sh
~/.config/omarchy/plugins/sonlndv.vietkey/bin/omakey-setup --uninstall
omarchy plugin remove sonlndv.vietkey
```

`--uninstall` removes the Ctrl+Shift block from `bindings.lua` (with a
backup). Installed packages and your fcitx5 group are left alone; remove
engines in `fcitx5-configtool` and packages with `pacman` if you no longer
want them.

## Requirements

Omarchy 4 (Hyprland + Omarchy shell) with fcitx5 started by the
`omarchy-fcitx5` user service. `busctl` (systemd) and `hyprctl` for live
state; `omarchy-pkg-add` and Omarchy's floating terminal for installing.
Packages come from the Arch `extra` repo. `fcitx5-configtool` is optional.

For development: `npm test` (or `node --test test/*.test.mjs`) checks the
language catalogue. `node --test test/` fails because it also tries to load
`test/dbus_e2e.py` and `test/e2e-typing.sh` as test files.

## Credits

Multi-language design (badge with mode, menu with engine modes, append-only
group changes, ask-before-restart, no polling) is inspired by
[ray0907/input-menu](https://github.com/Ray0907/omarchy-input-menu) (MIT).
Menu design follows
[jesusarchive/omarchy-keyboard-layout-switcher](https://github.com/jesusarchive/omarchy-keyboard-layout-switcher) (MIT).
Vietnamese input by [fcitx5-unikey](https://github.com/fcitx/fcitx5-unikey).

## License

MIT

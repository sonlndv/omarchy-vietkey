# VietKey — Vietnamese keyboard for Omarchy

**Bộ gõ tiếng Việt cho Omarchy.** Type Vietnamese with **Telex** or **VNI**,
switch with **Ctrl+Shift**, the way Unikey works on Windows, right from the
Omarchy bar.

Your keyboard layout stays US. Only the way you type changes:

| Mode                 | You type          | You get     |
| -------------------- | ----------------- | ----------- |
| English              | `tieng viet`      | tieng viet  |
| Tiếng Việt · Telex   | `tieengs vieejt`  | tiếng việt  |
| Tiếng Việt · VNI     | `tie6ng1 vie65t`  | tiếng việt  |

VietKey is a front end for the [fcitx5](https://fcitx-im.org/) input method and
its [Unikey](https://github.com/fcitx/fcitx5-unikey) engine, which Omarchy
already runs.

## Install

```sh
omarchy plugin add https://github.com/sonlndv/omarchy-vietkey.git --enable
~/.config/omarchy/plugins/sonlndv.vietkey/bin/vietkey-setup
```

Run `vietkey-setup` once. It:

1. installs `fcitx5-unikey` if it is missing (asks for your password),
2. sets fcitx5 to two inputs: US keyboard (English) and Unikey (Vietnamese),
   with the same state in every window,
3. adds the **Ctrl+Shift** shortcut to `~/.config/hypr/bindings.lua`,
   between `-- vietkey:start` and `-- vietkey:end`,
4. restarts fcitx5.

It backs up your existing fcitx5 `profile` and `config` and `bindings.lua`
first.

## Use

The bar shows **EN**, or **VI** in your theme's accent colour with
`Telex` / `VNI` next to it.

| Action                    | Effect                                |
| ------------------------- | ------------------------------------- |
| **Ctrl+Shift**            | English ↔ Tiếng Việt (either order)   |
| Right click the badge     | English ↔ Tiếng Việt                  |
| Click the badge           | Open the menu                         |

```
   [EN] English
 ✓ [VI] Tiếng Việt — Telex
 ─────────────────────────
   󰌌 Open Keyboard Settings…
 ─────────────────────────
   Ctrl+Shift switches language
```

Ctrl+Shift fires when you let go, and only if you pressed nothing else, so
shortcuts like Ctrl+Shift+T keep working.

## Keyboard Settings

A Unikey-style window. Changes apply and save immediately.

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

## Bar options

```sh
omarchy bar move sonlndv.vietkey --section right
omarchy bar set sonlndv.vietkey showModeName false --json   # badge only
```

## Commands

```sh
omarchy-shell sonlndv.vietkey toggle        # English <-> Tiếng Việt
omarchy-shell sonlndv.vietkey english       # English
omarchy-shell sonlndv.vietkey setMode VNI   # Tiếng Việt, VNI (or Telex)
omarchy-shell sonlndv.vietkey togglePanel   # open / close the menu
omarchy-shell sonlndv.vietkey settings      # open / close Keyboard Settings
```

## Troubleshooting

- **Nothing changes when I type:** make sure fcitx5 is running
  (`systemctl --user status omarchy-fcitx5`) and run `vietkey-setup` again.
- **Ctrl+Shift does nothing:** check the `vietkey:start` block is in
  `~/.config/hypr/bindings.lua`, then run `hyprctl reload`.
- **An Electron app (VS Code, Discord, Slack) types badly:** start it with
  `--enable-wayland-ime`.

## Uninstall

```sh
omarchy plugin remove sonlndv.vietkey
```

Then delete the `-- vietkey:start` … `-- vietkey:end` block from
`~/.config/hypr/bindings.lua`. Uninstall `fcitx5-unikey` too if you no longer need it.

## Requirements

Omarchy Quattro (Hyprland + Omarchy shell). fcitx5 ships with Omarchy;
`vietkey-setup` adds `fcitx5-unikey` from the Arch `extra` repo.

## Credits

Menu design follows
[jesusarchive/omarchy-keyboard-layout-switcher](https://github.com/jesusarchive/omarchy-keyboard-layout-switcher) (MIT).
Vietnamese input by [fcitx5-unikey](https://github.com/fcitx/fcitx5-unikey).

## License

MIT

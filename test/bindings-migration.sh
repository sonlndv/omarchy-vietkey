#!/bin/bash
# Bindings-migration dry-run test for keymarchy-setup. Verifies --dry-run
# against a temp bindings file (via KEYMARCHY_BINDINGS) correctly migrates
# both an old -- vietkey:start/end block and an old -- omakey:start/end
# block to -- keymarchy:start/end, without ever touching ~/.config/hypr.
#
# Usage: test/bindings-migration.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP="$SCRIPT_DIR/../bin/keymarchy-setup"
WORK="$(mktemp -d /tmp/keymarchy-bindings-test.XXXXXXXX)"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0

check() {
  local name=$1 haystack=$2 needle=$3
  if grep -qF -- "$needle" <<<"$haystack"; then
    echo "PASS  $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL  $name (expected to find: $needle)"
    FAIL=$((FAIL + 1))
  fi
}

not_check() {
  local name=$1 haystack=$2 needle=$3
  if grep -qF -- "$needle" <<<"$haystack"; then
    echo "FAIL  $name (did not expect to find: $needle)"
    FAIL=$((FAIL + 1))
  else
    echo "PASS  $name"
    PASS=$((PASS + 1))
  fi
}

echo "== keymarchy-setup bindings migration (--dry-run, temp file) =="
echo

# --------------------------------------------------- old Omakey block
OMAKEY_FILE="$WORK/omakey-bindings.lua"
cat > "$OMAKEY_FILE" <<'EOF'
-- some unrelated binding
o.bind("SUPER + Q", "Close window", "hyprctl dispatch killactive")

-- omakey:start
-- Omakey (plugin sonlndv.vietkey): Ctrl+Shift, either order or side, cycles
-- through every enabled language in fcitx5 group order (EN -> VI -> JA -> EN).
for _, key in ipairs({ "Shift_L", "Shift_R", "Control_L", "Control_R" }) do
  o.bind("CTRL + SHIFT + " .. key, "Omakey: next language", "omarchy-shell sonlndv.vietkey toggle || fcitx5-remote -t", { release = true, non_consuming = true })
end
-- omakey:end
EOF

OUT_OMAKEY=$(KEYMARCHY_BINDINGS="$OMAKEY_FILE" bash "$SETUP" --dry-run 2>&1)
check "omakey block: detects the Omakey block" "$OUT_OMAKEY" "found the Omakey block (-- omakey:start/end); replacing it with -- keymarchy:start/end"
check "omakey block: diff shows the new keymarchy marker" "$OUT_OMAKEY" "-- keymarchy:start"
check "omakey block: diff removes the old omakey marker" "$OUT_OMAKEY" "-- omakey:start"
# --dry-run must never touch the real file.
AFTER_OMAKEY="$(cat "$OMAKEY_FILE")"
check "omakey block: --dry-run wrote nothing to the temp file" "$AFTER_OMAKEY" "-- omakey:start"

# --------------------------------------------------- old VietKey block
VIETKEY_FILE="$WORK/vietkey-bindings.lua"
cat > "$VIETKEY_FILE" <<'EOF'
-- vietkey:start
o.bind("CTRL + SHIFT", "VietKey toggle", "fcitx5-remote -t", { release = true })
-- vietkey:end
EOF

OUT_VIETKEY=$(KEYMARCHY_BINDINGS="$VIETKEY_FILE" bash "$SETUP" --dry-run 2>&1)
check "vietkey block: detects the VietKey block" "$OUT_VIETKEY" "found the VietKey block (-- vietkey:start/end); replacing it with -- keymarchy:start/end"
check "vietkey block: diff shows the new keymarchy marker" "$OUT_VIETKEY" "-- keymarchy:start"

# --------------------------------------------------- no existing block
FRESH_FILE="$WORK/fresh-bindings.lua"
cat > "$FRESH_FILE" <<'EOF'
-- just some other binding
o.bind("SUPER + RETURN", "Terminal", "kitty")
EOF

OUT_FRESH=$(KEYMARCHY_BINDINGS="$FRESH_FILE" bash "$SETUP" --dry-run 2>&1)
check "fresh file: adds the Keymarchy block at the end" "$OUT_FRESH" "adding the Keymarchy block at the end"

# --------------------------------------------------- already-migrated
DONE_FILE="$WORK/done-bindings.lua"
cat > "$DONE_FILE" <<'EOF'
-- keymarchy:start
-- Keymarchy (plugin sonlndv.vietkey)
for _, key in ipairs({ "Shift_L", "Shift_R", "Control_L", "Control_R" }) do
  o.bind("CTRL + SHIFT + " .. key, "Keymarchy: next language", "omarchy-shell sonlndv.vietkey toggle || fcitx5-remote -t", { release = true, non_consuming = true })
end
-- keymarchy:end
EOF

OUT_DONE=$(KEYMARCHY_BINDINGS="$DONE_FILE" bash "$SETUP" --dry-run 2>&1)
check "already migrated: reports Keymarchy block present" "$OUT_DONE" "Keymarchy block present"
not_check "already migrated: no migration-note step shown" "$OUT_DONE" "Upgrading from"

# --------------------------------------------------- --key / --capslock
KEY_FILE="$WORK/key-bindings.lua"
cp "$FRESH_FILE" "$KEY_FILE"
OUT_KEY=$(KEYMARCHY_BINDINGS="$KEY_FILE" bash "$SETUP" --dry-run --key alt+z --capslock normal 2>&1)
check "--key alt+z: records the key" "$OUT_KEY" "-- keymarchy:key=ALT + Z"
check "--key alt+z: binds ALT + Z" "$OUT_KEY" 'o.bind("ALT + Z", "Keymarchy: next language"'
not_check "--key alt+z: no Ctrl+Shift loop" "$OUT_KEY" '"CTRL + SHIFT + " .. key'
check "--capslock normal: records the choice" "$OUT_KEY" "-- keymarchy:capslock=normal"
check "--capslock normal: sets kb_options" "$OUT_KEY" "hl.config({ input = { kb_options ="

# A later plain run (e.g. --add from the menu) keeps the recorded choices.
KEPT_FILE="$WORK/kept-bindings.lua"
cat > "$KEPT_FILE" <<'BINDINGS'
-- keymarchy:start
-- keymarchy:key=ALT + Z
o.bind("ALT + Z", "Keymarchy: next language", "omarchy-shell sonlndv.vietkey toggle || fcitx5-remote -t")
-- keymarchy:capslock=normal
hl.config({ input = { kb_options = "" } })
-- keymarchy:end
BINDINGS
OUT_KEPT=$(KEYMARCHY_BINDINGS="$KEPT_FILE" bash "$SETUP" --dry-run 2>&1)
not_check "plain rerun: does not bring Ctrl+Shift back" "$OUT_KEPT" '"CTRL + SHIFT + " .. key'
not_check "plain rerun: keeps the CapsLock choice" "$OUT_KEPT" "| --- keymarchy:capslock=normal"
check "plain rerun: Done names the recorded key" "$OUT_KEPT" "ALT + Z cycles through your languages"

OUT_BACK=$(KEYMARCHY_BINDINGS="$KEPT_FILE" bash "$SETUP" --dry-run --key ctrl+shift --capslock compose 2>&1)
check "--key ctrl+shift: back to the Ctrl+Shift loop" "$OUT_BACK" '"CTRL + SHIFT + " .. key'
check "--capslock compose: drops the kb_options line" "$OUT_BACK" '-hl.config({ input = { kb_options'

echo
echo "== Summary =="
echo "pass=$PASS fail=$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  echo "SOME FAILED"
  exit 1
else
  echo "ALL PASS"
fi

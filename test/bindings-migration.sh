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

echo
echo "== Summary =="
echo "pass=$PASS fail=$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  echo "SOME FAILED"
  exit 1
else
  echo "ALL PASS"
fi

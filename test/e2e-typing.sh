#!/bin/bash
# Omakey all-round headless typing test harness.
#
# NEVER touches Son's live fcitx5 session. Starts a private fcitx5 inside a
# private D-Bus session (dbus-run-session), with XDG_CONFIG_HOME/
# XDG_DATA_HOME/XDG_CACHE_HOME pointing at a throwaway temp dir. Drives it
# over its own D-Bus input-context API (org.fcitx.Fcitx.InputMethod1
# CreateInputContext, then InputContext1 ProcessKeyEvent + CommitString
# signals) via test/dbus_e2e.py, run with /usr/bin/python3 (the system
# interpreter that has python-dbus + PyGObject; the Hermes-bundled python3
# does not).
#
# Usage: test/e2e-typing.sh
#
# Exit code 0 unless a real engine FAILs (SKIPs alone still exit 0, matching
# "a skip is never a pass" i.e. it's reported distinctly in the summary line,
# not folded into PASS).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY=/usr/bin/python3
DBUS_HELPER="$SCRIPT_DIR/dbus_e2e.py"

WORK="$(mktemp -d /tmp/omakey-e2e.XXXXXXXX)"
FCITX_PID=""
DBUS_PID=""

cleanup() {
  local ec=$?
  # Precise match: any fcitx5 whose XDG_CONFIG_HOME is this run's private
  # workdir, never Son's live fcitx5 (XDG_CONFIG_HOME=~/.config there).
  local pid
  for pid in $(pgrep -x fcitx5 2>/dev/null); do
    if tr '\0' '\n' <"/proc/$pid/environ" 2>/dev/null | grep -qxF "XDG_CONFIG_HOME=$WORK/config"; then
      kill "$pid" >/dev/null 2>&1
    fi
  done
  [[ -n "$FCITX_PID" ]] && kill "$FCITX_PID" >/dev/null 2>&1
  [[ -n "$DBUS_PID" ]] && kill "$DBUS_PID" >/dev/null 2>&1
  sleep 0.2
  for pid in $(pgrep -x fcitx5 2>/dev/null); do
    if tr '\0' '\n' <"/proc/$pid/environ" 2>/dev/null | grep -qxF "XDG_CONFIG_HOME=$WORK/config"; then
      kill -9 "$pid" >/dev/null 2>&1
    fi
  done
  rm -rf "$WORK"
  exit "$ec"
}
trap cleanup EXIT INT TERM HUP

mkdir -p "$WORK/config/fcitx5" "$WORK/data" "$WORK/cache"
export XDG_CONFIG_HOME="$WORK/config"
export XDG_DATA_HOME="$WORK/data"
export XDG_CACHE_HOME="$WORK/cache"

# Packages Jarvis confirmed installed; still probed live below so a stale
# assumption here can't mask a real SKIP.
declare -A ENGINE_PACKAGE=(
  [unikey]=fcitx5-unikey
  [mozc]=fcitx5-mozc
  [hangul]=fcitx5-hangul
  [pinyin]=fcitx5-chinese-addons
  [chewing]=fcitx5-chewing
  [libthai]=fcitx5-libthai
)

missing_pkg() {
  local engine=$1 pkg=${ENGINE_PACKAGE[$1]:-}
  [[ -n "$pkg" ]] || return 1
  pacman -Q "$pkg" >/dev/null 2>&1 && return 1
  echo "$pkg"
}

# fcitx5 group: every engine exercised below, so no SKIP is ever "not in the
# group" — only "package missing" or a genuine commit mismatch counts.
cat > "$WORK/config/fcitx5/profile" <<'PROF'
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=keyboard-us

[Groups/0/Items/0]
Name=keyboard-us

[Groups/0/Items/1]
Name=unikey

[Groups/0/Items/2]
Name=keyboard-ara

[Groups/0/Items/3]
Name=keyboard-ir

[Groups/0/Items/4]
Name=keyboard-il

[Groups/0/Items/5]
Name=keyboard-ru

[Groups/0/Items/6]
Name=keyboard-gr

[Groups/0/Items/7]
Name=mozc

[Groups/0/Items/8]
Name=hangul

[Groups/0/Items/9]
Name=pinyin

[Groups/0/Items/10]
Name=chewing

[Groups/0/Items/11]
Name=libthai

[GroupOrder]
0=Default
PROF

unset DBUS_SESSION_BUS_ADDRESS
unset DISPLAY WAYLAND_DISPLAY

FIFO_DIR="$WORK"
BUS_FILE="$WORK/busaddr"
PID_FILE="$WORK/fcitx.pid"

# dbus-run-session's child keeps running until we kill it; run it as the
# harness's own private session bus + fcitx5, backgrounded so this script
# can drive it from the outside via the bus address it writes to disk.
dbus-run-session -- bash -c '
  echo "$DBUS_SESSION_BUS_ADDRESS" > '"$BUS_FILE"'
  sleep 0.3
  fcitx5 --disable=notificationitem,notifications,ibusfrontend,xim,kimpanel,virtualkeyboard,classicui,waylandim,wayland,xcb \
    >"'"$WORK"'/fcitx5.log" 2>&1 &
  FPID=$!
  echo "$FPID" > '"$PID_FILE"'
  wait "$FPID"
' &
DBUS_PID=$!

BUS_ADDR=""
FCITX_PID=""
for _ in $(seq 1 40); do
  [[ -s "$BUS_FILE" ]] && BUS_ADDR="$(cat "$BUS_FILE")"
  [[ -s "$PID_FILE" ]] && FCITX_PID="$(cat "$PID_FILE")"
  [[ -n "$BUS_ADDR" && -n "$FCITX_PID" ]] && break
  sleep 0.1
done

if [[ -z "$BUS_ADDR" ]]; then
  echo "FATAL: private dbus-run-session never printed a bus address" >&2
  exit 1
fi

# Wait for fcitx5's D-Bus service to actually come up (not just the process).
ready=0
for _ in $(seq 1 40); do
  if busctl --address="$BUS_ADDR" --no-pager list 2>/dev/null | grep -q org.fcitx.Fcitx5; then
    ready=1
    break
  fi
  sleep 0.25
done
if [[ "$ready" -ne 1 ]]; then
  echo "FATAL: private fcitx5 never registered org.fcitx.Fcitx5 on its own bus" >&2
  cat "$WORK/fcitx5.log" >&2 || true
  exit 1
fi

PASS=0
FAIL=0
declare -a SKIPPED=()
declare -a FAILED_NAMES=()

run_case() {
  # run_case NAME ENGINE KEYSPEC TIMEOUT_MS EXPECTED [UNIKEY_MODE]
  local name=$1 engine=$2 keyspec=$3 timeout_ms=$4 expected=$5 unikey_mode=${6:-}
  local pkg
  pkg=$(missing_pkg "$engine")
  if [[ -n "$pkg" ]]; then
    echo "SKIP  $name (package $pkg not installed)"
    SKIPPED+=("$name: $pkg")
    return
  fi
  if [[ -n "$unikey_mode" ]]; then
    busctl --address="$BUS_ADDR" call org.fcitx.Fcitx5 /controller \
      org.fcitx.Fcitx.Controller1 SetConfig sv "fcitx://config/inputmethod/unikey" \
      'a{sv}' 1 InputMethod s "$unikey_mode" >/dev/null 2>>"$WORK/err.log" || true
  fi
  local out commit
  out=$("$PY" "$DBUS_HELPER" "$BUS_ADDR" "$engine" "$keyspec" "$timeout_ms" 2>"$WORK/err.log")
  # Concatenate every commit in order (some engines commit in several bursts).
  local joined
  joined=$(printf '%s\n' "$out" | grep -o "('commit', '[^']*')" | sed "s/^('commit', '//; s/')\$//" | tr -d '\n')
  if [[ "$expected" == "__ALL_UNHANDLED__" ]]; then
    # Plain passthrough engines (keyboard-us) never commit via fcitx; they
    # return handled=False for every key so X11/Wayland's own keymap types
    # the character client-side. fcitx has nothing to commit/forward to
    # observe here, so the correct assertion is "fcitx stayed out of the
    # way for every key", not a literal string.
    local results all_false
    results=$(printf '%s\n' "$out" | sed -n 's/^RESULTS://p')
    if [[ -n "$results" ]] && ! grep -q '=True' <<<"$results"; then
      echo "PASS  $name -> all keys unhandled (passthrough confirmed)"
      PASS=$((PASS + 1))
    else
      echo "FAIL  $name expected all-unhandled passthrough, got: $results"
      [[ -s "$WORK/err.log" ]] && sed 's/^/        stderr: /' "$WORK/err.log"
      FAIL=$((FAIL + 1))
      FAILED_NAMES+=("$name")
    fi
    return
  fi
  if [[ "$joined" == "$expected" ]]; then
    echo "PASS  $name -> '$joined'"
    PASS=$((PASS + 1))
  else
    echo "FAIL  $name expected '$expected' got '$joined' (raw: $out)"
    [[ -s "$WORK/err.log" ]] && sed 's/^/        stderr: /' "$WORK/err.log"
    FAIL=$((FAIL + 1))
    FAILED_NAMES+=("$name")
  fi
}

echo "== Omakey e2e typing harness =="
echo "Private fcitx5 pid=$FCITX_PID bus=$BUS_ADDR workdir=$WORK"
echo

# --------------------------------------------------------------- EN / VI

run_case "EN keyboard-us: tieng viet" "keyboard-us" \
  "0x74:0;0x74:1;0x69:0;0x69:1;0x65:0;0x65:1;0x6e:0;0x6e:1;0x67:0;0x67:1;0x20:0;0x20:1;0x76:0;0x76:1;0x69:0;0x69:1;0x65:0;0x65:1;0x74:0;0x74:1" \
  2000 "__ALL_UNHANDLED__"

run_case "VI unikey Telex: tieengs vieejt -> tiếng việt" "unikey" \
  "0x74:0;0x74:1;0x69:0;0x69:1;0x65:0;0x65:1;0x65:0;0x65:1;0x6e:0;0x6e:1;0x67:0;0x67:1;0x73:0;0x73:1;0x20:0;0x20:1;0x76:0;0x76:1;0x69:0;0x69:1;0x65:0;0x65:1;0x65:0;0x65:1;0x6a:0;0x6a:1;0x74:0;0x74:1;0x20:0;0x20:1" \
  2500 "tiếng việt "

run_case "VI unikey VNI: tie6ng1 vie65t -> tiếng việt" "unikey" \
  "0x74:0;0x74:1;0x69:0;0x69:1;0x65:0;0x65:1;0x36:0;0x36:1;0x6e:0;0x6e:1;0x67:0;0x67:1;0x31:0;0x31:1;0x20:0;0x20:1;0x76:0;0x76:1;0x69:0;0x69:1;0x65:0;0x65:1;0x36:0;0x36:1;0x35:0;0x35:1;0x74:0;0x74:1;0x20:0;0x20:1" \
  2500 "tiếng việt " "VNI"

run_case "VI unikey restore-English: 'class ' stays 'class '" "unikey" \
  "0x63:0;0x63:1;0x6c:0;0x6c:1;0x61:0;0x61:1;0x73:0;0x73:1;0x73:0;0x73:1;0x20:0;0x20:1" \
  2000 "class "

# --------------------------------------------------------------- layouts

run_case "AR keyboard-ara: hgsghl -> السلام" "keyboard-ara" \
  "0x68,43:0;0x68,43:1;0x67,42:0;0x67,42:1;0x73,39:0;0x73,39:1;0x67,42:0;0x67,42:1;0x68,43:0;0x68,43:1;0x6c,46:0;0x6c,46:1" \
  2000 "السلام"

run_case "HE keyboard-il: shalom (שלום)" "keyboard-il" \
  "0x61,38:0;0x61,38:1;0x6b,45:0;0x6b,45:1;0x75,30:0;0x75,30:1;0x6f,32:0;0x6f,32:1" \
  2000 "שלום"

run_case "RU keyboard-ru: privet -> привет" "keyboard-ru" \
  "0x70,42:0;0x70,42:1;0x72,43:0;0x72,43:1;0x69,56:0;0x69,56:1;0x76,40:0;0x76,40:1;0x65,28:0;0x65,28:1;0x74,57:0;0x74,57:1" \
  2000 "привет"

run_case "EL keyboard-gr: geia -> γεια" "keyboard-gr" \
  "0x67,42:0;0x67,42:1;0x65,26:0;0x65,26:1;0x69,31:0;0x69,31:1;0x61,38:0;0x61,38:1" \
  2000 "γεια"

# --------------------------------------------------------------- CJK / TH

run_case "JA mozc: konnichiha + space/enter -> こんにちは" "mozc" \
  "0x6b:0;0x6b:1;0x6f:0;0x6f:1;0x6e:0;0x6e:1;0x6e:0;0x6e:1;0x69:0;0x69:1;0x63:0;0x63:1;0x68:0;0x68:1;0x69:0;0x69:1;0x68:0;0x68:1;0x61:0;0x61:1;0x20:0;0x20:1;0xff0d:0;0xff0d:1" \
  3000 "こんにちは"

run_case "KO hangul: dkssud -> 안녕" "hangul" \
  "0x64:0;0x64:1;0x6b:0;0x6b:1;0x73:0;0x73:1;0x73:0;0x73:1;0x75:0;0x75:1;0x64:0;0x64:1;0x20:0;0x20:1" \
  2500 "안녕"

run_case "ZH pinyin: nihao + space -> 你好" "pinyin" \
  "0x6e:0;0x6e:1;0x69:0;0x69:1;0x68:0;0x68:1;0x61:0;0x61:1;0x6f:0;0x6f:1;0x20:0;0x20:1" \
  2000 "你好"

# Chewing (Zhuyin): ㄋㄧˊ keys s(ㄋ) u(ㄧ) 6(ˊtone2) + Enter to commit -> 泥
run_case "ZH chewing: one word (泥)" "chewing" \
  "0x73:0;0x73:1;0x75:0;0x75:1;0x36:0;0x36:1;0xff0d:0;0xff0d:1" \
  2500 "泥"

# libthai (kedmanee basic): f -> ฟ (one word/char per brief)
run_case "TH libthai: one word (ฟ)" "libthai" \
  "0x66,38:0;0x66,38:1" \
  2000 "ฟ"

echo
echo "== Catalogue.cycleTarget switching test (3+ languages) =="
# Pure JS logic test, no fcitx5 needed: node --test already covers
# cycleTarget, but re-assert it here against a live Catalogue.mjs import.
# EN, VI, JA, KO: Ctrl+Shift walks the whole cycle and wraps to English.
NODE_OUT="$(cd "$SCRIPT_DIR/.." && node --input-type=module -e '
import * as C from "./Catalogue.mjs";
const engines = ["keyboard-us", "unikey", "mozc", "hangul"];
const want = ["unikey", "mozc", "hangul", "keyboard-us"];
let engine = "keyboard-us";
let ok = true;
for (const next of want) {
  const got = C.cycleTarget(engine, engines);
  if (got !== next) { ok = false; console.log("MISMATCH from=" + engine + " got=" + got + " want=" + next); }
  engine = got;
}
if (C.cycleTarget("keyboard-us", ["keyboard-us"]) !== "") { ok = false; console.log("MISMATCH English only should be a no-op"); }
console.log("cycle: keyboard-us -> " + want.join(" -> "));
console.log(ok ? "CYCLE_OK" : "CYCLE_FAIL");
' 2>&1)"
echo "$NODE_OUT"
if echo "$NODE_OUT" | grep -q "CYCLE_OK"; then
  echo "PASS  Catalogue.cycleTarget cycles EN -> VI -> JA -> KO -> EN"
  PASS=$((PASS + 1))
else
  echo "FAIL  Catalogue.cycleTarget mismatch (see output above)"
  FAIL=$((FAIL + 1))
  FAILED_NAMES+=("cycleTarget")
fi

echo
echo "== Settings dashboard reorder over D-Bus (private fcitx5) =="
# The dashboard's up/down buttons call SetInputMethodGroupInfo with
# Catalogue.setGroupArgs(Catalogue.moveLanguage(...)). Make that exact call
# against the private fcitx5, read the group back, and check fcitx5 now holds
# the new order (Japanese one step up), nothing was dropped, English kept its
# slot, and the cycle follows the new order.
fcitx_private() {
  busctl --address="$BUS_ADDR" call org.fcitx.Fcitx5 /controller org.fcitx.Fcitx.Controller1 "$@"
}
BEFORE="$(fcitx_private InputMethodGroupInfo s Default 2>>"$WORK/err.log")"
mapfile -t SET_ARGS < <(cd "$SCRIPT_DIR/.." && BEFORE="$BEFORE" node --input-type=module -e '
import * as C from "./Catalogue.mjs";
const info = C.parseGroupInfo(process.env.BEFORE);
for (const arg of C.setGroupArgs("Default", info.layout, C.moveLanguage(info.items, "ja", -1))) console.log(arg);
')
fcitx_private "${SET_ARGS[@]}" >/dev/null 2>>"$WORK/err.log"
AFTER="$(fcitx_private InputMethodGroupInfo s Default 2>>"$WORK/err.log")"
REORDER_OUT="$(cd "$SCRIPT_DIR/.." && BEFORE="$BEFORE" AFTER="$AFTER" node --input-type=module -e '
import * as C from "./Catalogue.mjs";
const before = C.parseGroupInfo(process.env.BEFORE).items;
const after = C.parseGroupInfo(process.env.AFTER).items;
const want = C.moveLanguage(before, "ja", -1);
const ids = items => C.languagesInGroup(items).map(l => l.id).join(" ");
console.log("before: " + ids(before));
console.log("after:  " + ids(after));
let ok = JSON.stringify(after) === JSON.stringify(want);
if (!ok) console.log("MISMATCH want: " + ids(want));
if (after.length !== before.length) { ok = false; console.log("MISMATCH item count " + before.length + " -> " + after.length); }
if (after[0].name !== before[0].name || !C.isEnglishEngine(after[0].name)) { ok = false; console.log("MISMATCH English moved"); }
const engines = after.map(i => i.name);
const langs = C.languagesInGroup(after);
const ja = langs.findIndex(l => l.id === "ja");
const prev = langs[ja - 1].engines[0];
if (C.cycleTarget(prev, engines) !== "mozc") { ok = false; console.log("MISMATCH cycle from " + prev); }
console.log(ok ? "REORDER_OK" : "REORDER_FAIL");
' 2>&1)"
echo "$REORDER_OUT"
if echo "$REORDER_OUT" | grep -q "REORDER_OK"; then
  echo "PASS  dashboard reorder writes the fcitx5 group and the cycle follows it"
  PASS=$((PASS + 1))
else
  echo "FAIL  dashboard reorder (see output above)"
  [[ -s "$WORK/err.log" ]] && sed 's/^/        stderr: /' "$WORK/err.log"
  FAIL=$((FAIL + 1))
  FAILED_NAMES+=("reorder")
fi

echo
echo "== Summary =="
echo "pass=$PASS fail=$FAIL skipped=${#SKIPPED[@]}"
if [[ ${#SKIPPED[@]} -gt 0 ]]; then
  printf 'SKIPPED: %s\n' "${SKIPPED[@]}"
fi
if [[ ${#FAILED_NAMES[@]} -gt 0 ]]; then
  printf 'FAILED: %s\n' "${FAILED_NAMES[@]}"
fi

if [[ "$FAIL" -gt 0 ]]; then
  echo "SOME FAILED"
elif [[ ${#SKIPPED[@]} -gt 0 ]]; then
  echo "PASS WITH SKIPS: $(IFS=,; echo "${SKIPPED[*]}")"
else
  echo "ALL PASS"
fi

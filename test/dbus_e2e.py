#!/usr/bin/env python3
"""
Omakey e2e typing harness helper: drives a private fcitx5 over its own D-Bus
session via org.fcitx.Fcitx.InputMethod1 / InputContext1, sends real key
events (ProcessKeyEvent) and collects CommitString signals.

Never touches the live session: operates purely on the bus address and
XDG dirs passed to it. Run with /usr/bin/python3 (python-dbus + PyGObject
are installed there; the Hermes-bundled interpreter lacks them).

Usage:
  dbus_e2e.py <bus_address> <engine> <keyspec> [timeout_ms]

keyspec is semicolon-separated entries of one of two forms:
  keyval:release              (keycode 0, e.g. "0x61:0")
  keyval,keycode:release      (explicit keycode, needed for layout engines
                               that look at hardware keycode, e.g. Arabic)

Prints two lines to stdout:
  RESULTS:<spec>=<handled>|...
  EVENTS:<('commit', text) | ('currentim', name)>|...
"""
import sys
import dbus
import dbus.mainloop.glib
from gi.repository import GLib


def main():
    bus_addr = sys.argv[1]
    engine = sys.argv[2]
    keyspec = sys.argv[3]
    timeout_ms = int(sys.argv[4]) if len(sys.argv) > 4 else 2000

    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    bus = dbus.bus.BusConnection(bus_addr, mainloop=dbus.mainloop.glib.DBusGMainLoop())

    ctrl = bus.get_object('org.fcitx.Fcitx5', '/controller')
    ctrl_iface = dbus.Interface(ctrl, 'org.fcitx.Fcitx.Controller1')

    im = bus.get_object('org.fcitx.Fcitx5', '/org/freedesktop/portal/inputmethod')
    im_iface = dbus.Interface(im, 'org.fcitx.Fcitx.InputMethod1')
    path, _uuid = im_iface.CreateInputContext([('program', 'omakey-e2e')])

    ic = bus.get_object('org.fcitx.Fcitx5', path)
    ic_iface = dbus.Interface(ic, 'org.fcitx.Fcitx.InputContext1')
    # Preedit | FormattedPreedit | ClientSideInputPanel: engines that build a
    # candidate (chewing, mozc, pinyin, hangul, unikey's diacritics) need this
    # to actually commit on Enter/space instead of silently dropping input.
    try:
        ic_iface.SetCapability(dbus.UInt64((1 << 1) | (1 << 4) | (1 << 39)))
    except Exception as e:
        print("SETCAP_ERR", e, file=sys.stderr)

    events = []

    def on_commit(text):
        events.append(('commit', str(text)))

    def on_forward(keyval, _state, isrelease):
        events.append(('forward', int(keyval), bool(isrelease)))

    def on_currentim(uname, _name, _lang):
        events.append(('currentim', str(uname)))

    bus.add_signal_receiver(on_commit, signal_name='CommitString',
                             dbus_interface='org.fcitx.Fcitx.InputContext1', path=path)
    bus.add_signal_receiver(on_forward, signal_name='ForwardKey',
                             dbus_interface='org.fcitx.Fcitx.InputContext1', path=path)
    bus.add_signal_receiver(on_currentim, signal_name='CurrentIM',
                             dbus_interface='org.fcitx.Fcitx.InputContext1', path=path)

    try:
        ic_iface.FocusIn()
    except Exception as e:
        print("FOCUSIN_ERR", e, file=sys.stderr)

    loop = GLib.MainLoop()
    results = []

    def send_keys():
        try:
            ctrl_iface.SetCurrentIM(engine)
        except Exception as e:
            print("SETIM_ERR", e, file=sys.stderr)
        for spec in keyspec.split(';'):
            if not spec:
                continue
            payload, release_s = spec.rsplit(':', 1)
            release = release_s == '1'
            if ',' in payload:
                keyval_s, keycode_s = payload.split(',')
            else:
                keyval_s, keycode_s = payload, '0'
            keyval = int(keyval_s, 0)
            keycode = int(keycode_s, 0)
            try:
                handled = ic_iface.ProcessKeyEvent(
                    dbus.UInt32(keyval), dbus.UInt32(keycode), dbus.UInt32(0),
                    release, dbus.UInt32(0))
                results.append((spec, bool(handled)))
            except Exception as e:
                print("KEY_ERR", spec, e, file=sys.stderr)
        return False

    GLib.idle_add(send_keys)
    GLib.timeout_add(timeout_ms, loop.quit)
    loop.run()

    print("RESULTS:" + "|".join(f"{s}={h}" for s, h in results))
    print("EVENTS:" + "|".join(str(e) for e in events))
    # Forwarded text: engines that don't handle a key (plain keyboard-us)
    # send it back via ForwardKey instead of CommitString. Reassemble the
    # printable ASCII presses in order so a pure passthrough case still has
    # an expected string to compare against.
    forwarded = []
    for e in events:
        if e[0] == 'forward' and not e[2]:  # press only
            kv = e[1]
            if 0x20 <= kv < 0x7f:
                forwarded.append(chr(kv))
    print("FORWARDED:" + "".join(forwarded))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Benchmark bin/keymarchy-state: 10 runs, report median wall time (ms).

Read-only — never starts, restarts or changes fcitx5. Run against a live
session where fcitx5 is already running for a representative number.

Usage:
  test/bench-keymarchy-state.py [path-to-keymarchy-state]
"""
import subprocess
import sys
import time
from pathlib import Path

DEFAULT = Path(__file__).resolve().parent.parent / "bin" / "keymarchy-state"


def median_ms(cmd, runs=10):
    times = []
    for _ in range(runs):
        t0 = time.perf_counter()
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        times.append((time.perf_counter() - t0) * 1000)
    times.sort()
    mid = len(times) // 2
    m = times[mid] if len(times) % 2 else (times[mid - 1] + times[mid]) / 2
    return m, times


def main():
    target = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT
    m, times = median_ms([str(target)])
    print(f"target={target}")
    print(f"runs_ms={[round(t, 2) for t in times]}")
    print(f"median_ms={m:.2f}")


if __name__ == "__main__":
    main()

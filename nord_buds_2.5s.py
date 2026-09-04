#!/usr/bin/env python3
# <swiftbar.hideSwiftBar>true</swiftbar.hideSwiftBar>
# <swiftbar.hideWhenEmpty>true</swiftbar.hideWhenEmpty>
#
# SwiftBar plugin: per-bud battery for OnePlus Nord Buds 2.
# Primary source: budsbatt binary (OPO query over RFCOMM ch15).
# Fallback: macOS system_profiler single battery value.
# Install: copy to SwiftBar plugin folder, put budsbatt at ~/.config/nordbuds/budsbatt.

import json
import os
import subprocess
import sys

TARGET_DEVICE_NAME = "OnePlus Nord Buds 2"
BUDSBATT = os.path.expanduser("~/.config/nordbuds/budsbatt")

try:
    raw_json = subprocess.check_output(["/usr/sbin/system_profiler", "SPBluetoothDataType", "-json"], stderr=subprocess.DEVNULL)
    data = json.loads(raw_json)
except Exception:
    sys.exit(0)

found_device = None
for controller in data.get("SPBluetoothDataType", []):
    for item in controller.get("device_connected", []):
        if TARGET_DEVICE_NAME in item:
            found_device = item[TARGET_DEVICE_NAME]
            break
    if found_device:
        break

if not found_device:
    sys.exit(0)

battery = found_device.get("device_batteryLevelMain") or found_device.get("device_batteryLevelCase") or found_device.get("device_batteryLevelLeft") or ""
address = found_device.get("device_address", "").replace(":", "-").lower()

left = right = case = None
try:
    out = subprocess.check_output(
        [BUDSBATT],
        stderr=subprocess.DEVNULL, timeout=10).decode()
    for line in out.splitlines():
        if line.startswith("RESULT"):
            parts = dict(p.split("=") for p in line.split()[1:])
            left, right = parts.get("L"), parts.get("R")
            case = parts.get("C")
except Exception:
    pass

if left is not None and right is not None:
    lo = min(int(left), int(right))
    params = "color=#ff453a size=13" if lo < 20 else "size=13"
    if left == right:
        print(f"🎧 {left}% | {params}")
    else:
        print(f"🎧 {left} · {right} | {params}")
elif battery:
    print(f"🎧 {battery} | size=13")
else:
    print("🎧")

print("---")
print(f"{TARGET_DEVICE_NAME} | size=13 font=bold")
if left is not None and right is not None:
    print(f"Left: {left}% | sfimage=earbuds")
    print(f"Right: {right}% | sfimage=earbuds")
if case is not None:
    print(f"Case: {case}% | sfimage=case")
if battery:
    print(f"Battery: {battery} | sfimage=battery.100")
print("---")
if address:
    print(f"Disconnect | sfimage=xmark.circle bash=/opt/homebrew/bin/blueutil param1=--disconnect param2={address} terminal=false refresh=true")
print("Bluetooth Settings... | sfimage=gear bash=/usr/bin/open param1='x-apple.systempreferences:com.apple.BluetoothSettings' terminal=false")

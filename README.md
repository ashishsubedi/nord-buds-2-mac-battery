# Nord Buds 2 — per-bud battery on macOS

SwiftBar menu bar plugin showing **left / right / case** battery for OnePlus Nord Buds 2.
macOS natively exposes only one number; per-bud levels come from a vendor
protocol query (see Protocol below).

## Setup

Requirements: macOS, Xcode Command Line Tools (`xcode-select --install`),
[SwiftBar](https://github.com/swiftbar/SwiftBar), buds paired + Classic-connected.

```bash
# 1. build
swiftc -framework IOBluetooth -o budsbatt budsbatt.swift

# 2. install binary (plugin expects it here)
mkdir -p ~/.config/nordbuds
cp budsbatt ~/.config/nordbuds/budsbatt

# 3. install plugin
cp nord_buds_2.5s.py "<your SwiftBar plugin folder>/"
```

Then:

1. `System Settings → Privacy & Security → Bluetooth` → allow **Terminal** (test) and **SwiftBar**.
2. `System Settings → Menu Bar → Allow in the Menu Bar` → **SwiftBar** ON.
3. SwiftBar → Refresh All. Restart SwiftBar after granting Bluetooth access.

Verify: `./budsbatt` should print `RESULT L=<n> R=<n> [C=<n>]`.
Cross-check against HeyMelody on Android.

## Display

- Title: `🎧 100%` when both equal, `🎧 90 · 75` (left first) when split. Red only if either bud < 20%.
- Dropdown: Left / Right / Case + Disconnect + Bluetooth Settings.
- Falls back to macOS single battery if the query fails (e.g. RFCOMM busy).

## Protocol

- Transport is **classic SPP/RFCOMM**, not BLE: service `oppointeraction`,
  UUID `00001107-D102-11E1-9B23-00025B00A5A5`, RFCOMM channel **15**.
  (The well-known `cracked-oneplus-buds` BLE `0000079A` approach targets the
  3 Pro and does not work here — LE connects but GATT discovery stalls.)
- Query `AA 07 00 00 06 01 <SEQ> 00 00`, reply echoes SEQ:
  `AA .. 00 00 06 81 <SEQ> .. 00 00 <N> <id> <pct> …`
  with `id` 01 = left, 02 = right, 03 = case.
- `N` = 2 out of case, 3 docked. Case is only reported while buds are in the case.
- No auth handshake on this model (unlike 3 Pro token flow).
- Reverse-engineered from Android HCI snoop (`btsnoop_hci.log`) of HeyMelody
  battery refreshes, parsed with Wireshark + a small btsnoop reader.

## Limits

- One RFCOMM client at a time; overlapping polls fall back to single value.
- Buds address (`84-0F-2A-6F-31-85`) and channel (15) are hard-coded in
  `budsbatt.swift` — adjust for your unit (find via `system_profiler` + SDP).
- Other OPOv1 models (Oppo/Realme family) likely similar but untested.

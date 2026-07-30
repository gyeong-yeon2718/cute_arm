# Calibration log — 2026-07-30

Record of identifying what was running on the board, verifying it, and calibrating it.

## 1. Identifying the firmware

The board was already programmed and it was not obvious with what. Source code cannot be
recovered from an AVR, but the flash can be dumped and compared against a candidate:

```
avrdude -c arduino -p atmega328p -P COM7 -b 115200 -U flash:r:uno_flash.hex:i
```

Printable strings in the dump (`Robotic arm initialized.`, `ALL CALIBRATION VALUES RESET
AND SAVED.`, …) matched no sketch in `Documents\Arduino\`, but did match this project.
Compiling it and comparing byte-for-byte settled it:

| | |
|---|---|
| Flash region used on board | 16,610 bytes |
| Freshly compiled sketch | 16,610 bytes |
| SHA-256 of both (16,610 B) | `7594822a93a935ccef34276e8fa4eb1167172a260eace93546bf149d37abfe79` |
| Result | **byte-for-byte identical** |

Confirmed live too — boot banner at 115200 baud matched the strings in the dump.

## 2. Functional test before touching anything

Speed set to the 30°/s minimum, position queried with `T` after every move.

| Command | Expected | Board reported |
|---|---|---|
| `O` | (12, 0, 12) | `(12.00, -0.00, 12.00)` |
| `U(2)` | (12, 0, 14) | `(12.00, -0.00, 14.00)` |
| `D(2)` | (12, 0, 12) | `(12.00, -0.00, 12.00)` |
| `F(2)` | (14, 0, 12) | `(14.00, -0.00, 12.00)` |
| `B(2)` | (12, 0, 12) | `(12.00, -0.00, 12.00)` |
| `L(3)` | (12, −3, 12) | `(12.00, -3.00, 12.00)` |
| `R(3)` | (12, 0, 12) | `(12.00, -0.00, 12.00)` |
| `A(10 0 8)` | (10, 0, 8) | `(10.00, -0.00, 8.00)` |
| `O` | (12, 0, 12) | `(12.00, -0.00, 12.00)` |

IK↔FK round-trip error: **0.00 cm**. Manual joint control checked against hand-computed
FK as well:

| Command | Hand calculation | Board |
|---|---|---|
| `M(90 100 95)` | x = cos100°·12 + cos15°·12 = 9.507, z = sin100°·12 + sin15°·12 = 14.924 | `(9.51, -0.00, 14.92)` |
| `M(95 90 90)` | x = sin95°·12 = 11.954, y = cos95°·12 = −1.046 | `(11.95, -1.05, 12.00)` |

Clamps and error handling also behaved: `S(500)` → 90, `S(1)` → 30, `Z` →
`INVALID COMMAND: Z`, `+W` before `+S` → rejected.

## 3. Reading the EEPROM (and a trap)

**`avrdude -U eeprom:r` does not work on an Uno.** It reports success and writes a
1024-byte file, but the contents were byte-for-byte identical to the *flash* — Optiboot
has no EEPROM support, so the read silently returns the wrong memory. The first set of
"calibration values" obtained this way was garbage and was discarded.

The working method is a temporary sketch ([`tools/read-eeprom`](../tools/read-eeprom)),
which also holds all four servos at the pose the real firmware would command, so the arm
does not go limp during the swap. Then restore the original firmware and verify the hash.

Before calibration:

```
calib_base = 0.0   calib_shoulder = 0.0   calib_elbow = 0.0
gripper_open = 100.0   gripper_close = 0.0
non-0xFF bytes / 1024 = 20
```

Those are exactly what `-R` writes (offsets zeroed, gripper set to the servo's physical
limits), so **the arm had never actually been calibrated** — `-R` had been run, `-C` never.

## 4. Joint calibration

Reference pose at `M(90 90 90)` with zero offsets: upper arm vertical, forearm
horizontal, base centred — the arm should look like the digit "7". It did not, so the
joints were jogged with [`tools/calibrate.ps1`](../tools/calibrate.ps1) until it did.

Which way is "+", derived from the code and confirmed on the board:

| Joint | Increasing the angle |
|---|---|
| base | rotates the same way as the `L` (left) command — `M(95 90 90)` → y = −1.05 |
| shoulder | upper arm leans **back** — `M(90 100 90)` → 1.9 cm up, 2.3 cm back |
| elbow | forearm lifts **up** — `M(90 90 95)` → 1.05 cm up |

The correct pose turned out to be `base 95, shoulder 90, elbow 95`, tip reading
`(11.91, -1.04, 13.05)` — which matches the hand calculation for those angles to two
decimals. `-C` then stored the offsets.

## 5. Gripper calibration

`gripper_open` was 100° (the servo's hard limit), so the gripper flung fully open on
every boot. Set to **45°**, the value the firmware's own header comment recommends.
`gripper_close` left at 0°.

Verified functionally — `+S`/`+W` print the recorded gripper state:

| Action | Response |
|---|---|
| `GC` then `+S` | `Gripper saved as close.` |
| `GO` then `+W` | `Gripper saved as open.` |
| `G(20)` then `+W` | `open` (sticky by design, see findings) |

## 6. Final state

```
raw[0..19]: 00 00 A0 40  00 00 00 00  00 00 A0 40  00 00 34 42  00 00 00 00
calib_base      = 5.000000      (0x40A00000)
calib_shoulder  = 0.000000
calib_elbow     = 5.000000      (0x40A00000)
gripper_open    = 45.000000     (0x42340000)
gripper_close   = 0.000000
```

| Value | Before | After |
|---|---|---|
| `calib_base` | 0.0 | **5.0** |
| `calib_shoulder` | 0.0 | 0.0 (no deviation) |
| `calib_elbow` | 0.0 | **5.0** |
| `gripper_open` | 100.0 | **45.0** |
| `gripper_close` | 0.0 | 0.0 |

## 7. Firmware integrity

The firmware was swapped out three times to read EEPROM. After each restore the flash
was dumped and compared:

| | SHA-256 (16,610 B) |
|---|---|
| Original | `7594822a93a935cc…37abfe79` |
| After every restore | `7594822a93a935cc…37abfe79` |

**All 32 KB identical, bootloader included.**

## 8. Accuracy check

The 12.0 / 12.0 cm link constants in `main.ino` were confirmed to match the physical arm
(it was built to the upstream design), and the tip position at `A(15 0 5)` measured as
correct. Combined with the 0.00 cm IK↔FK round-trip, coordinate commands are trusted.

## Open item

`gripper_close = 0.0` is identical to the `-R` default, so it cannot be told from EEPROM
alone whether 0 was chosen deliberately or the save did not land. The value itself is what
the firmware's header recommends. Worth confirming the servo does not buzz or stall against
a mechanical stop when closing — if it does, raise it to 2–5°.

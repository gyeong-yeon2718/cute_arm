# Tools

## `calibrate.ps1` — calibration jogger

Interactive jogger for finding the true rest pose and saving it to EEPROM.

```powershell
powershell -NoProfile -File .\calibrate.ps1
```

Arrow keys nudge the selected joint, `1`/`2`/`3` pick base/shoulder/elbow, `Enter`
saves the current pose as the new 90/90/90 via the firmware's `-C` command. Because
you jog and look rather than typing angles, you never need to know which direction
is "+". Press `t` for a demo move if a joint's direction is unclear.

The per-joint limits from `main.ino` are enforced (shoulder 0–110°, elbow 20–180°,
gripper 0–100°), so out-of-range nudges are refused rather than sent.

Gripper values: `g` to try an angle, then `o` / `c` to save it as open / close.

**After saving, the script re-syncs its counters back to 90/90/90.** This matters —
after `-C` the firmware's reference has moved, so a script still holding the old
numbers would jump the arm by the offset amount on the next nudge.

## `read-eeprom/` — EEPROM reader sketch

The only reliable way to read the calibration values off an Uno.

`avrdude -U eeprom:r` **does not work here**: Optiboot has no EEPROM support, so the
read appears to succeed but returns flash bytes instead. Compare the output against a
flash dump and you will find them identical.

This sketch prints the calibration struct as raw bytes and as decoded floats, and
counts non-`0xFF` bytes so you can see whether anything was ever written. It also
attaches all four servos and holds them at `90 + calib` (reading the offsets from
EEPROM itself), so the arm keeps its pose while the real firmware is not resident.

It never writes EEPROM.

### Procedure

Uploading this replaces the arm firmware, so restore it afterwards and verify:

```powershell
$cli = 'C:\Program Files\Arduino IDE\resources\app\lib\backend\resources\arduino-cli.exe'
$av  = "$env:LOCALAPPDATA\Arduino15\packages\arduino\tools\avrdude\8.0.0-arduino1\bin\avrdude.exe"
$cf  = "$env:LOCALAPPDATA\Arduino15\packages\arduino\tools\avrdude\8.0.0-arduino1\etc\avrdude.conf"

# 0. dump the current firmware first, so you can prove the restore worked
& $av -C $cf -c arduino -p atmega328p -P COM7 -b 115200 -U flash:r:before.hex:i

# 1. read the EEPROM
& $cli compile --fqbn arduino:avr:uno --output-dir build-ee .\read-eeprom
& $cli upload  --fqbn arduino:avr:uno -p COM7 --input-dir build-ee .\read-eeprom
#    then open a serial monitor at 115200 baud

# 2. restore the arm firmware
& $cli compile --fqbn arduino:avr:uno --output-dir build ..\firmware\main
& $cli upload  --fqbn arduino:avr:uno -p COM7 --input-dir build ..\firmware\main

# 3. verify byte-for-byte
& $av -C $cf -c arduino -p atmega328p -P COM7 -b 115200 -U flash:r:after.hex:i
```

Compare `before.hex` and `after.hex` — they should be identical, bootloader included.
This was done three times during the 2026-07-30 session and matched every time
(`7594822a93a935cc…37abfe79`).

## Notes on talking to the board

- **Opening the serial port resets the Uno.** The arm snaps to `90 + calib` and the
  gripper is driven to `gripper_open`. Close any script holding `COM7` before starting
  another, or you get `Access to the port 'COM7' is denied`.
- Commands are terminated by `\n` and upper-cased by the firmware.
- 115200 baud. At 9600 or 57600 you get mojibake.

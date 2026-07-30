# cute_arm

Build, calibration and verification record for a 3-DOF Arduino robotic arm.

The firmware is the **Seven** project by elevenMiles ([upstream](https://github.com/elevenMiles/Robotic_Arm_Seven), MIT).
This repository is the log of *my* build: what actually runs on my board, how I
calibrated it, what I measured, and the tooling I wrote to do it. See
[NOTICE.md](NOTICE.md) for what is mine and what is not.

## Hardware

| | |
|---|---|
| Controller | Arduino Uno (genuine, `VID_2341` / `PID_0043`) |
| Serial | **115200** baud, `COM7` on this machine |
| MCU | ATmega328P, 32 KB flash (Optiboot bootloader), 2 KB RAM, 1 KB EEPROM |
| Servos | 4× SG90 — base `D6`, shoulder `D9`, elbow `D10`, gripper `D11` |
| Link lengths | shoulder→elbow **12.0 cm**, elbow→gripper **12.0 cm** |
| Reach | 3 cm (min) to 23 cm (max) from the shoulder pivot |

Flash footprint: **16,610 / 32,256 bytes (51%)**, RAM 820 / 2048 bytes (40%).
Measured control loop rate: **~2,410 Hz**.

## Current calibration

Stored in EEPROM at address 0 as five little-endian floats. Survives power cycles.

| Value | Setting |
|---|---|
| `calib_base` | **5.0°** |
| `calib_shoulder` | 0.0° |
| `calib_elbow` | **5.0°** |
| `gripper_open` | **45.0°** |
| `gripper_close` | 0.0° |

Calibrated 2026-07-30 — full procedure and verification in
[docs/calibration-log.md](docs/calibration-log.md).

## Coordinate system

Origin `(0,0,0)` is the **shoulder servo's pivot**. Units are centimetres.

| Axis | Direction |
|---|---|
| X | forward |
| Y | left / right |
| Z | up / down |

The calibrated rest pose is `(12, 0, 12)` — upper arm vertical, forearm
horizontal, so the arm looks like the digit "7".

## Quick start

Open a serial monitor at 115200 baud and type commands. On boot the arm prints:

```
Robotic arm initialized.
If this is the first run, please use -R command to reset all calibration angles.
```

Common commands:

```
A(15 0 5)    move gripper to x=15cm, y=0, z=+5cm (inverse kinematics)
M(90 90 90)  set joint angles directly (base, shoulder, elbow)
U(3) D(3)    move 3 cm up / down   (also L R F B; bare letter = 5 cm)
O            return to rest
GO / GC      gripper open / close
G(30)        gripper to a specific angle
S(60)        angular speed, clamped to 30..90 deg/sec
T            print current end-effector position
```

Full command list is in the header comment of
[`firmware/main/main.ino`](firmware/main/main.ino). Note `T` is missing from that
list — see [docs/findings.md](docs/findings.md).

## Repository layout

```
firmware/          Seven firmware, unmodified, byte-identical to upstream (MIT, elevenMiles)
  main/            what actually runs on the board
  test/            per-servo assembly test sketch
tools/             my tooling
  calibrate.ps1    arrow-key calibration jogger
  read-eeprom/     temporary sketch that dumps the EEPROM calibration struct
docs/
  firmware-analysis.md   how the firmware works internally
  calibration-log.md     the calibration session, values, and verification
  findings.md            bugs and doc mismatches found in the firmware
```

## Working with the board

Two things bite immediately:

1. **Opening the serial port resets the Uno.** The arm snaps to `90 + calib` and
   the gripper is driven to `gripper_open`. Any pose you had dialled in is lost.
2. **Optiboot cannot read or write EEPROM.** `avrdude -U eeprom:r` appears to
   succeed but silently returns *flash* bytes instead. Reading the real EEPROM
   needs a temporary sketch — see [tools/README.md](tools/README.md).

Also: the servos have **no position feedback**. The `T` command reports where the
firmware *believes* the arm is, computed from commanded angles. A stalled or
obstructed servo still reports the ideal position.

## Roadmap

- [ ] Fix waypoint replay so it actually loops (see [docs/findings.md](docs/findings.md))
- [ ] Document the `T` command in the firmware header
- [ ] Check whether `gripper_close = 0°` stalls the servo against a mechanical stop
- [ ] Eventually: write my own firmware from scratch for this hardware, and drop `firmware/`

## License

My work (`docs/`, `tools/`, this README): MIT, see [LICENSE](LICENSE).
The firmware under `firmware/`: MIT, © 2026 elevenMiles, see
[`firmware/LICENSE`](firmware/LICENSE) and [NOTICE.md](NOTICE.md).

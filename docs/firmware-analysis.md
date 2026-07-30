# How the firmware works

Notes from reading the whole of `firmware/main/` (1,222 lines) and confirming the
behaviour against the running board. Line references point at
`firmware/main/roboticArm.cpp` unless stated otherwise.

## Module layout

| File | Role |
|---|---|
| `main.ino` | pin/geometry constants, serial read, elapsed-time measurement |
| `roboticArm.cpp` | the brain — command parsing, IK/FK, waypoints, EEPROM (622 lines) |
| `servoConfig.cpp` | servo wrapper: per-joint angle limits + direction reversal |
| `vector3.cpp` | 3-D vector maths, including `moveTowards` interpolation |
| `fixedVector.h` | fixed-capacity array (25 waypoints), no heap |

There is **no dynamic allocation anywhere**. On a 2 KB device that avoids heap
fragmentation, which is why `fixedVector.h` exists instead of a `std::vector`-alike.

## The control loop

Servos are never written directly from a command. Each joint keeps a `target_*_angle`
and a `current_*_angle`, and every loop iteration nudges current toward target
(`roboticArm.cpp:91`):

```
max_delta = angular_speed × delta_time
current   = moveTowards(current, target + calib, max_delta)
servo.write(current)
```

`delta_time` is measured from real `micros()` deltas (`main.ino:127`), so the
**angular velocity is constant in degrees/second** regardless of how fast the loop
happens to run. That is what makes the motion smooth rather than stepped.

`moveTowards` (`vector3.cpp:25`) treats the three joint angles as one vector, so all
three joints start and finish together — linear interpolation in *joint* space. The
tip therefore traces a curve, not a straight line, between two points.

Measured loop rate on the real board: **~2,410 Hz** (counted via the handshake `K`
output, 723 lines in 300 ms).

## Inverse kinematics — `A(X Y Z)`

Coordinates to joint angles, solved as a single triangle (`roboticArm.cpp:540`):

1. Base rotation from `atan2(-y, x)`.
2. Straight-line distance `C` from the shoulder pivot to the target.
3. Cosine rule on the 12 cm + 12 cm links and `C` gives shoulder and elbow angles.

Guards, all of which clamp rather than fail:

- reach clamped to `min_distance = |L1-L2| + 3 = 3 cm` … `max_distance = L1+L2 - 1 = 23 cm`
- `x ≥ 1 cm` (`MIN_X`), `z ≥ -6 cm` (`MIN_Z`) — stops the arm digging below the table
- `acos` input clamped to `-1..1`, so unreachable targets settle at full extension
  instead of producing NaN

### Verified against the board

`A(15 0 5)` — hand-computed C = √(15²+5²) = 15.811 cm, cosine rule gives
base 90.00°, shoulder 67.22°, elbow 82.42°. Feeding those back through FK gives
`(15.00, 0.00, 5.00)`, and the board reported exactly `(15.00, -0.00, 5.00)`.

## Forward kinematics — `T`

Joint angles back to coordinates (`roboticArm.cpp:573`). Relative move commands are
built on top of it (`roboticArm.cpp:452`):

```
IK( FK(current position) + direction × distance )
```

So `U(5)` means "work out where the tip is, add 5 cm of Z, convert back to angles".
Relative motion is routed through absolute coordinates.

Round-trip error measured over 9 moves: **0.00 cm** — no drift accumulates when
repeating relative moves.

FK subtracts the calibration offsets that the control loop adds, so **`T` output is
calibration-transparent**: at rest it reads `(12, 0, 12)` whether or not the arm is
calibrated. `T` can never be used to check whether calibration is stored.

## Calibration and EEPROM

Mounting error means a servo's "90°" is not the true rest position. So:

1. Dial in the real rest pose with `M(...)`.
2. `-C` stores `current − 90` per joint as an offset (`roboticArm.cpp:209`).
3. Everything afterwards is computed against `target + calib`.

`EEPROM.put` writes one 20-byte struct of five floats at address 0. A fresh chip
reads `0xFF` everywhere, which decodes to NaN, so `getEEPROM` guards each field with
`isnan()` and substitutes 0 (`roboticArm.cpp:618`). That is what the "please use -R"
boot message is about — the NaN guard works, but `gripper_open` becomes 0, so the
gripper boots closed.

Note `-C` writes the **whole struct**, gripper values included, so it never clobbers a
previous gripper calibration.

## Waypoints

`+S` / `+W` / `+E` capture the current pose via FK; `+M` replays. Each waypoint is
executed as a two-phase state machine (`roboticArm.cpp:98`):

- phase 0: move the arm — timer set to `distance ÷ angular_speed + 0.5 s`
- phase 1: actuate the gripper — timer set the same way

Non-blocking: no `delay()` anywhere, timers are decremented by `delta_time`. All
serial input is ignored while a list is running (`roboticArm.cpp:152`).

Gripper state is recorded as open/close only, never an intermediate angle. The
detector (`roboticArm.cpp:75`) is an `if / else if` with **no `else`**, so at a
mid-travel angle the previous label sticks. Confirmed on the board: `G(20)` after
`GO` still records "open".

## Handshake — `HA` / `HD`

For driving the arm from another program. When enabled, the firmware prints `K` after
every update cycle; the host sends the next command only after seeing `K`. Simple flow
control. While active, human-readable replies are suppressed and `-` / `+` commands are
rejected.

At ~2,410 Hz this is a firehose — roughly 2,400 lines of `K` per second.

# Findings

Issues found while reading and exercising the firmware. Line references point at
`firmware/main/`.

**All of these exist upstream, not locally.** Verified 2026-07-30: every file in
`firmware/` is byte-identical to https://github.com/elevenMiles/Robotic_Arm_Seven
(only line endings differ). Upstream's `code/` directory has a single commit,
"Add files via upload" (2026-03-22), and has not been touched since — later commits are
all README and sponsorship edits. So none of this has been fixed upstream.

---

## 1. Waypoint replay does not loop

**Severity:** behaviour contradicts the documentation.

`main.ino:43` says:

> Waypoints let you record a sequence of positions and replay them in a loop.

and the command list describes `+M` as "Begin **looping** through the waypoint list".

It does not loop. When the last waypoint is reached, `endMoveOnWaypoints()`
(`roboticArm.cpp:478`) sets `list_move = false`, which ends playback:

```cpp
void RoboticArm::endMoveOnWaypoints()
{
  waypoint_index = 0;
  list_move = false;
  Serial.println(F("Ended to move on waypoints."));
}
```

The sequence plays exactly once. Either the docs or the code needs to change; looping
would mean leaving `list_move` true and only resetting `waypoint_index`, plus some way
to stop (currently all serial input is blocked during playback, `roboticArm.cpp:152`, so
an infinite loop would be unstoppable short of a reset — that is probably why it was
written this way).

## 2. The `T` command is undocumented

**Severity:** minor.

`roboticArm.cpp:192` implements a genuinely useful command:

```cpp
case 'T': Serial.print(F("End effector position: ")); forwardKinematics().println(); return;
```

It appears nowhere in the command list at `main.ino:46`. It is the only way to ask the
arm where it thinks it is, and it was the main verification tool during calibration.

## 3. `T` cannot reveal calibration state

**Severity:** not a bug — a property worth knowing.

`forwardKinematics()` computes `current − calib` while the control loop drives
`current` to `target + calib`. The offsets cancel, so at rest `T` reports `(12, 0, 12)`
whether the arm is calibrated or not. Combined with servos having no position feedback,
this means **the firmware cannot report its own physical state**. The only ground truth
is the EEPROM contents plus your own eyes.

## 4. Gripper state is sticky at mid-travel

**Severity:** by design, but surprising.

`roboticArm.cpp:75`:

```cpp
if      (abs(current_gripper_angle - gripper_close_angle) < max_delta) gripperState = close;
else if (abs(current_gripper_angle - gripper_open_angle)  < max_delta) gripperState = open;
```

No `else`. At any angle that is not within one loop-tick of either endpoint, the previous
label persists. Confirmed on the board: `G(20)` after `GO` still records "open" into a
waypoint. Waypoints can therefore only store fully-open or fully-closed, never a partial
grip.

## 5. First-run gripper behaviour

**Severity:** cosmetic, but it is what the boot message is really about.

A blank EEPROM reads as `0xFF`, which decodes to NaN. `getEEPROM`
(`roboticArm.cpp:618`) guards with `isnan()` and substitutes 0 — correct for the joint
offsets, but it makes `gripper_open = 0`, so an uncalibrated arm boots with the gripper
**closed** while `begin()` believes it is open. Hence the "please use `-R`" prompt.

Note that `-R` then sets `gripper_open` to the servo's *physical maximum* (100°), which
makes the gripper fling fully open on every boot until a real value is saved.

## 6. Stray includes

**Severity:** trivial.

`roboticArm.cpp:1-2`:

```cpp
#include "HardwareSerial.h"
#include "WString.h"
```

Auto-inserted by the Arduino IDE; both come in via `Arduino.h` already.

---

## Latent, probably unreachable

`roboticArm.cpp:71` divides by `distance`:

```cpp
float direction {(target_gripper_angle - current_gripper_angle) / distance};
```

If `distance == 0` **and** `max_delta == 0` the first branch is not taken and this is
`0/0` → NaN, which would poison `current_gripper_angle` permanently. `max_delta` is
`angular_speed × delta_time`, and at the measured ~2,410 Hz loop rate `delta_time` is
~415 µs, never zero. Not worth changing, but worth knowing it is there.

# Attribution

This repository contains code from two sources. Keeping them clearly separated
is deliberate — it makes the licensing obvious and it makes it easy to strip the
third-party part later if this project moves to a from-scratch firmware.

## `firmware/` — third-party, MIT

The Arduino firmware is **not original work of this repository**. It comes from:

- **Project:** Seven — 3-DOF Arduino Robotic Arm
- **Upstream:** https://github.com/elevenMiles/Robotic_Arm_Seven
- **Copyright:** © 2026 elevenMiles
- **In-source author credit:** "ROBOTIC ARM (Seven) - Author: Selçuk Yüksel"
- **License:** MIT — full text in [`firmware/LICENSE`](firmware/LICENSE)

The files under `firmware/` are byte-identical to upstream (verified 2026-07-30;
the only difference is line endings — upstream is checked out as CRLF on Windows
via `core.autocrlf`, these are LF). No modifications have been made.

The MIT license permits redistribution and modification. Its single condition is
that the copyright notice and license text travel with the code, which is why
`firmware/LICENSE` and this file exist.

## `docs/`, `tools/` — original work, MIT

Everything else is original work for this project: the calibration jogger, the
EEPROM reader sketch, the verification scripts, and all documentation. Covered by
the top-level [`LICENSE`](LICENSE), © 2026 gyeong-yeon2718.

## Physical build

The mechanical design (STL files), wiring diagram, and bill of materials also come
from the upstream project and are not reproduced here — see the upstream repository
for those.

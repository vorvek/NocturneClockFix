# Nocturne cloth fix

Stops idle cloth motion and removes the frame rate effect on cloth (coats, capes, dresses, hair).
`NocturneClockFix.ps1` applies this patch together with the clock fix.
Both fixes on version 1.00.52 give MD5 `04878e5b3552b9d018398c952feef29a`.

## Cause

`CCloth::simulate` (0x436e80) and the particle solver (0x4366f0) keep per-step tuning values.
Dampen, spring, windArea and friction do not scale with `dt`. Every link and collision correction
also adds `correction / dt` to the velocity (6 solver passes per step). A particle in contact gets
a stronger kick at a higher frame rate, so the coat never settles.

Emulator results, real game code, Stranger coat, idle, mean speed:

| FPS | Original | Patched |
|---|---|---|
| 30 | 0.53 ft/s | 0.00 ft/s |
| 60 | 0.80 ft/s | 0.01 ft/s |
| 100 | 1.08 ft/s | 0.00 ft/s |

Swing with a 1.5 Hz, 0.3 ft sway: mean range 0.78 ft (original, 30 FPS), 0.81 ft (patched, 60 FPS).
The collision bones in the tests use an estimated pose, because the real idle pose is not in the data
that was read. Exact values in the game can differ.

## Patch

| File offset | VA | Change |
|---|---|---|
| `0x36583` | `0x437183` | Jump to the step gate, 4 NOPs |
| `0x36b4c` | `0x43774c` | Jump to the rest pass, 1 NOP |
| `0x174020` | `0x574c20` | 392 bytes of new code in free space ([cave.s](cave.s)) |

- Fixed step: the dynamics run at 30 Hz. A frame longer than 1/30 s keeps its own `dt`.
- Rest threshold: a free particle that moves slower than 0.75 ft/s in a step stays at its previous
  position, with zero velocity. The limit stays under gravity * step (1.07 ft/s), so a free particle
  can always start to fall.
- Interpolation: frames between two steps draw free particles between the last two results. This adds
  a delay of up to one step (33 ms). Locked particles update every frame.
- State: particle slot 799 of each `CCloth` (offsets `0x379fc`, `0x37a00`). The array has 800 slots.

Rejected after tests: a lower 1.05 contact margin (link errors above 300%), removal of the collision
velocity (more motion), an exact square root in the solver (not needed, and a zero length divides by zero).

## Tuning

Edit `rest_speed` in [cave.s](cave.s), then rebuild from the clock-patched exe:

```bash
python build.py <clock-patched nocturne.exe> <output exe>
```

The output lists the new `$ClothCave` data for `NocturneClockFix.ps1`.

## Files

- [build.py](build.py): assembles the code and writes the patched exe. Needs LLVM.
- [emutest.py](emutest.py): runs the real `CCloth::simulate` in Unicorn with the coat.
- [clothsim.c](clothsim.c): C port of the solver, used for variant tests.

The tests need `MODELS\STRCOAT.KFM` from your own `hero.pod`, saved as `strcoat.kfm`. This repository
does not contain it.

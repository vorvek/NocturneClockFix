# Nocturne Clock Fix

Fixes the long freezes in **Nocturne** (Terminal Reality, 1999) on modern PCs:

- the menus freeze or react only after many seconds,
- the step from the intro to the main menu takes a long time,
- the in-game menus freeze for up to 20 seconds while one CPU core runs at 100%.

The freezes are random: often, but not always.

The fix changes 2 bytes in your own `nocturne.exe`. This repository does not contain any game file.

## Requirements
- Nocturne for Windows, installed. The tested build is listed below.
- Windows 10 or 11 (Windows PowerShell 5.1 is part of Windows).

## Install
1. Close Nocturne.
2. Copy `NocturneClockFix.ps1`, `Apply Clock Fix.cmd` and `Remove Clock Fix.cmd` into the Nocturne folder,
   the folder that contains `nocturne.exe`.
3. Double-click `Apply Clock Fix.cmd`.
4. Look for `Done.` in the window. Then press a key to close it.

The script saves the original file as `nocturne.exe.clockfix-backup` before it writes.

From a PowerShell prompt you can also give the folder:

```powershell
powershell -ExecutionPolicy Bypass -File .\NocturneClockFix.ps1 -GameDir "C:\Games\Nocturne"
```

`-Check` only reports whether the fix is applied. It changes nothing.

## Uninstall
Double-click `Remove Clock Fix.cmd`, or run the script with `-Undo`. This writes the 2 original bytes
back. You can also copy `nocturne.exe.clockfix-backup` over `nocturne.exe`.

## Troubleshooting
- **"Windows refused to write nocturne.exe"**: the game is in a protected folder such as Program Files.
  Right-click `Apply Clock Fix.cmd` and select **Run as administrator**.
- **"Found 0 matching sites"**: your `nocturne.exe` is a build that the script does not know, or it is
  already modified by another tool. Nothing was changed. Please open an issue and include the MD5 that the
  script shows.
- **"Nocturne is running"**: close the game first.
- **Windows SmartScreen or "running scripts is disabled"**: the `.cmd` files start PowerShell with
  `-ExecutionPolicy Bypass` for this script only. They do not change any system setting.

## Tested builds

| MD5 of `nocturne.exe` | Size | Date | Status |
|---|---|---|---|
| `24acd9b17f6846225123a9d8354b09e1` | 1,948,160 bytes | 1999-11-02 | Tested in the game: fixed |

Other builds (for example, after the official 1.00.52 patch) are patched only if the script finds the
code pattern exactly once and the jump target is the expected code. These builds were not tested in
the game. Reports are welcome.

## Compatibility
- Works with or without DDrawCompat or dgVoodoo2. The fix is in the game's clock, not in the graphics.
- Saves are not affected.
- Single-player only. Nocturne has no online mode.

## How it works
Nocturne keeps time in steps of 1/18 second, like the old DOS timer. Many menu and loading screens wait
in a loop for the next step.

By default, the game reads the Windows high-resolution timer (`QueryPerformanceCounter`) on each pass of
that loop. It adds the time since the last read as a whole number of clock units and drops the fraction.
On a 1999 PC, one pass of the loop took long enough to add at least 1 unit. On a modern CPU, one pass
takes less than a microsecond, so each pass adds 0 and the clock stops. The loop then runs at 100% CPU
until Windows interrupts the game long enough for one pass to count. That can take many seconds.

The game also has a second clock mode based on `timeGetTime`. It reads the absolute time, so it loses no
time. The game uses it only if the high-resolution timer is missing. The fix changes the conditional
jump to that mode (`jne`, bytes `0F 85`) into an unconditional jump (`nop; jmp`, bytes `90 E9`). The game
then always uses the `timeGetTime` clock.

Details for the tested build: virtual address `0x558808`, file offset `0x157C08`.

Measured on a Ryzen 9 9950X3D with a sampling profiler. Before the fix, the main thread ran at 100% CPU
for 40 of 81 seconds in the menus. After the fix, it did so for 0 of 23 seconds through the same menus.

Known limit: the game's clock is a 32-bit value, so it wraps around about every 61 minutes. The unpatched
game has the same limit. Most of the game's timers subtract two clock values, and that stays correct
across the wrap. One group of timers first divides the clock value with signed math, so they see one bad
time step when the value crosses the signed limit. The game already limits that step to the range 0 to 2
seconds. So you get at most one frame in which game time does not advance, about once per hour. There
is no freeze. Very long sessions were not tested in the game.

With the fix, the clock value comes from `timeGetTime`, which counts from Windows start. So the first
wrap can come at any time in a session. In the unpatched game, the clock starts at 0 when the game
starts.

## Credits
- Analysis, the patch and this script: made with Claude Code (Claude Opus 5.5, an AI model by Anthropic),
  with testing by the repository owner in the real game. The agent used the
  [universal-modder](https://github.com/rehan-remade/universal-modder) toolkit.
- Nocturne is a game by Terminal Reality. This project is not affiliated with Terminal Reality or any
  rights holder. You need your own copy of the game.

## License
MIT. See [LICENSE](LICENSE).

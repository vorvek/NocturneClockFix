# Nocturne Clock Fix

*[Leer en español](README.es.md)*

A small patch for **Nocturne** (Terminal Reality, 1999). It removes the long menu freezes on modern PCs,
and it makes the cloth physics settle when a character stands still. One install applies both fixes.

## The problems

### Menu freezes
On a modern PC, Nocturne often freezes for 5 to 20 seconds (if you are unlucky, you can be waiting for
2 minutes):

- in the main menu and its screens,
- between the intro video and the main menu,
- in the in-game menus.

During a freeze, one CPU core runs at 100%. The freezes are random: they happen often, but not always.

**Why:** the game counts time in tiny steps, and in many menus it waits for the next step. Each time it
reads the clock, it drops the fraction of a step. On a 1999 PC, each read took long enough to count, but
a modern CPU is so fast that each read counts as 0 (less than a microsecond, rounded down), and the game
clock stops. The game then waits in a loop until, by chance, one read takes long enough and it can
continue.

### Restless cloth
Coats, capes, dresses and hair never stop moving, even when the character stands still. The motion gets
stronger above 30 FPS.

**Why:** the cloth settings work once per physics step, and the game runs one step per frame. Each time a
cloth particle touches the body or pulls on its neighbours, the game adds speed to it, and that speed gets
larger when a frame is shorter. So the cloth receives small kicks all the time and does not settle.

## What this patch does, and what it does not do
- Clock fix: it changes 2 bytes in your `nocturne.exe`. After that, the game uses its other built-in clock
  (`timeGetTime`), which does not lose time.
- Cloth fix: it adds a small routine to your `nocturne.exe`. Cloth physics runs at a fixed 30 steps per
  second at any frame rate above 30 FPS. A cloth particle that barely moves stops until a real force moves
  it. Frames between two steps are interpolated, so the motion stays smooth at 60 FPS.
- **It fixes only these two problems.** It does **not** make Nocturne run on modern versions of Windows
  by itself. You still need the usual fixes, such as DDrawCompat. See [Before you start](#before-you-start).
- It does not change the graphics, the sound, the saved games or any game file other than
  `nocturne.exe`.
- This repository does not contain any game files. You need your own copy of the game.

## Before you start
First, make the game start and run. The
[PCGamingWiki page for Nocturne](https://www.pcgamingwiki.com/wiki/Nocturne) explains all the steps. In
short:

- Install the latest official patch (Patch 2, version 1.00.52) if your copy needs it.
- Install [DDrawCompat](https://github.com/narzoul/DDrawCompat/releases). PCGamingWiki considers it
  essential. It fixes the graphics, the intro video and the startup errors, and it limits the frame rate.
- The SafeDisc copy protection of some European discs does not work on Windows Vista or later.

When the game runs, apply this patch.

## Install
1. Download `NocturneClockFix-1.1.0.zip` from the
   [Releases page](https://github.com/vorvek/NocturneClockFix/releases).
2. Extract the zip directly into the Nocturne folder (the folder that contains `nocturne.exe`).
   `Apply Clock Fix.cmd` must be next to `nocturne.exe`, not in a subfolder.
   - With 7-Zip or WinRAR, use **Extract here** inside the Nocturne folder.
   - Windows' **Extract All...** proposes a new subfolder named `NocturneClockFix-1.1.0`. Remove
     that last part from the path before you click **Extract**.
3. Double-click `Apply Clock Fix.cmd`.
4. Check that the window shows `Done.`. Then press a key to close it.
5. Start the game.

Before it writes, the patch saves the original file as `nocturne.exe.clockfix-backup`.

If you already use version 1.0.0, extract the new zip over the old files and double-click
`Apply Clock Fix.cmd` again. The patch adds the cloth fix.

## Uninstall
Double-click `Remove Clock Fix.cmd`. It removes both fixes. You can also copy `nocturne.exe.clockfix-backup` over
`nocturne.exe`.

## If something goes wrong

- **"Windows refused to write nocturne.exe"**: the game is in a protected folder, such as Program Files.
  Right-click `Apply Clock Fix.cmd` and select **Run as administrator**.
- **"Found 0 matching sites"**: the patch does not know your version of `nocturne.exe`, or another tool
  already changed the file. The patch changed nothing. Please
  [open an issue](https://github.com/vorvek/NocturneClockFix/issues) and include the MD5 that the window
  shows.
- **"Nocturne is running"**: close the game first.
- **Windows says that running scripts is disabled**: start the patch with the `.cmd` files. They allow
  only this script to run. They do not change any Windows setting.

## Versions

| MD5 of `nocturne.exe` | Version | Size | Result |
|---|---|---|---|
| `24acd9b17f6846225123a9d8354b09e1` | 1.00.52 | 1,948,160 bytes | Clock fix: tested in the game, no menu freezes. Cloth fix: tested with the game's own cloth code in an emulated CPU |
| `cb98ab8bd3f544bcf1fbeda8b963bf8c` | 1.00.47 (English retail disc) | 1,942,016 bytes | Same clock code as 1.00.52. The cloth fix does not apply |

The clock fix also accepts other versions if it finds the same code exactly once. Those versions are not
tested. Reports are welcome. The cloth fix applies only to version 1.00.52. On other versions, the window
shows `This build does not support the cloth fix`, and only the clock fix applies.

## Technical details
- Patch site in the tested version: file offset `0x157C08`, address `0x558808`. The bytes change from
  `0F 85` (`jne`) to `90 E9` (`nop; jmp`). Normally the game uses `QueryPerformanceCounter`, and it uses
  its `timeGetTime` clock only if that counter does not exist. After the patch, it always uses
  `timeGetTime`.
- The game clock is a 32-bit value, so it wraps around about every 61 minutes, also in the original game.
  At that moment, the game can lose at most one frame of game time. As far as I can tell, there's no visual or input feedback
  for this, no freezes or anything.
- The cloth fix adds two jumps in `CCloth::simulate` and 392 bytes of new code in free space at the end of
  the code section. Details, test results and source: [cloth/NOTES.md](cloth/NOTES.md).

## Credits and license
- Nocturne is a game by Terminal Reality. This project is not affiliated with Terminal Reality or any
  rights holder.
- License: MIT. See [LICENSE](LICENSE).

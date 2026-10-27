# Nocturne Clock Fix

*[Leer en español](README.es.md)*

A small patch for **Nocturne** (Terminal Reality, 1999). It removes the long menu freezes on modern PCs.

## The problem
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

## What this patch does, and what it does not do
- It changes 2 bytes in your `nocturne.exe`. After that, the game uses its other built-in clock
  (`timeGetTime`), which does not lose time.
- **It fixes only these timer freezes.** It does **not** make Nocturne run on modern versions of Windows
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

When the game runs but the menus freeze, apply this patch.

## Install
1. Download `NocturneClockFix-1.0.0.zip` from the
   [Releases page](https://github.com/vorvek/NocturneClockFix/releases).
2. Extract the zip. Copy these 3 files into the Nocturne folder (the folder that contains
   `nocturne.exe`):
   - `NocturneClockFix.ps1`
   - `Apply Clock Fix.cmd`
   - `Remove Clock Fix.cmd`
3. Double-click `Apply Clock Fix.cmd`.
4. Check that the window shows `Done.`. Then press a key to close it.
5. Start the game.

Before it writes, the patch saves the original file as `nocturne.exe.clockfix-backup`.

## Uninstall
Double-click `Remove Clock Fix.cmd`. You can also copy `nocturne.exe.clockfix-backup` over
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

## Tested version

| MD5 of `nocturne.exe` | Size | Result |
|---|---|---|
| `24acd9b17f6846225123a9d8354b09e1` | 1,948,160 bytes | Tested in the game: no menu freezes |

The patch also accepts other versions if it finds the same code exactly once. Those versions are not
tested. Reports are welcome.

## Technical details
- Patch site in the tested version: file offset `0x157C08`, address `0x558808`. The bytes change from
  `0F 85` (`jne`) to `90 E9` (`nop; jmp`). Normally the game uses `QueryPerformanceCounter`, and it uses
  its `timeGetTime` clock only if that counter does not exist. After the patch, it always uses
  `timeGetTime`.
- The game clock is a 32-bit value, so it wraps around about every 61 minutes, also in the original game.
  At that moment, the game can lose at most one frame of game time. It does not freeze.

## Credits and license
- Nocturne is a game by Terminal Reality. This project is not affiliated with Terminal Reality or any
  rights holder.
- License: MIT. See [LICENSE](LICENSE).

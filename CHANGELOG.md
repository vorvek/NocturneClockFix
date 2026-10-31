# Changelog

## 1.1.0 - 2026-10-31
- Adds the cloth fix on version 1.00.52: fixed 30 Hz cloth step, rest threshold for particles that barely
  move, and interpolation of the frames between two steps. One install applies both fixes.
- On other versions, the script applies the clock fix only.
- `-Undo` and `Remove Clock Fix.cmd` remove both fixes. `-Check` reports both states.
- Clock fix and cloth fix on `nocturne.exe` give MD5 `04878e5b3552b9d018398c952feef29a`.

## 1.0.0 - 2026-10-27
- First release. Forces Nocturne's `timeGetTime` clock to stop the menu and loading freezes on fast CPUs.
- Finds the patch site by a byte pattern and checks the jump target. Saves a backup. Supports `-Undo` and
  `-Check`.
- Tested in the game on `nocturne.exe` MD5 `24acd9b17f6846225123a9d8354b09e1`.

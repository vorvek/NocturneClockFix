<#
.SYNOPSIS
  Fixes the long menu and loading freezes of Nocturne (1999) on fast CPUs.

.DESCRIPTION
  Nocturne's clock drops the fraction of each time step. On a modern CPU a step is less than one clock
  unit, so the clock stops and the game spins at 100% CPU until Windows interrupts it. This script changes
  2 bytes in nocturne.exe so that the game uses its own timeGetTime clock, which does not lose time.

  The script finds the patch site by a byte pattern, checks the jump target, and saves a backup before it
  writes. It never downloads or ships any game file.

.PARAMETER GameDir
  The Nocturne folder (the one that contains nocturne.exe). Default: the folder of this script, then the
  current folder.

.PARAMETER Undo
  Restore the original 2 bytes.

.PARAMETER Check
  Only report whether nocturne.exe is patched. Change nothing.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File NocturneClockFix.ps1 -GameDir "C:\Games\Nocturne"
#>
param(
    [string]$GameDir,
    [switch]$Undo,
    [switch]$Check
)

$ErrorActionPreference = 'Stop'
$Version = '1.0.0'

# Builds that were tested in the real game. Other builds are patched only if the pattern matches once.
$KnownBuilds = @{
    '24ACD9B17F6846225123A9D8354B09E1' = 'nocturne.exe 1999-11-02 (1,948,160 bytes), unpatched'
    '2D094A32C4416E1A19F30C1AA8BB6067' = 'nocturne.exe 1999-11-02 (1,948,160 bytes), clock fix applied'
}

# call [QueryPerformanceFrequency] ; cmp eax,1 ; jne/jmp rel32 ; fild dword [...]
# $null = any byte. Index 9-10 holds 0F 85 (original jne) or 90 E9 (patched nop; jmp).
$Pattern = @(0xFF, 0x15, $null, $null, $null, $null, 0x83, 0xF8, 0x01, $null, $null, $null, $null, $null, $null, 0xDB, 0x05)
$SiteOffset = 9
$Original = [byte[]](0x0F, 0x85)
$Patched = [byte[]](0x90, 0xE9)
# The jump goes to the timeGetTime setup: mov ecx,1 ; push ecx ; mov [flag],ecx
$TargetBytes = [byte[]](0xB9, 0x01, 0x00, 0x00, 0x00, 0x51, 0x89, 0x0D)

function Find-Exe {
    $dirs = @()
    if ($GameDir) { $dirs += $GameDir } else { $dirs += $PSScriptRoot; $dirs += (Get-Location).Path }
    foreach ($d in $dirs) {
        if ($d -and (Test-Path -LiteralPath (Join-Path $d 'nocturne.exe'))) {
            return (Resolve-Path -LiteralPath (Join-Path $d 'nocturne.exe')).Path
        }
    }
    if ($GameDir) { throw "nocturne.exe not found in '$GameDir'." }
    throw "nocturne.exe not found. Copy this folder's files into the Nocturne folder, or use -GameDir `"<Nocturne folder>`"."
}

function Test-Bytes([byte[]]$Data, [int]$At, [byte[]]$Expected) {
    if ($At -lt 0 -or $At + $Expected.Length -gt $Data.Length) { return $false }
    for ($i = 0; $i -lt $Expected.Length; $i++) {
        if ($Data[$At + $i] -ne $Expected[$i]) { return $false }
    }
    return $true
}

function Find-Sites([byte[]]$Data) {
    $sites = @()
    $start = 0
    while ($true) {
        $p = [Array]::IndexOf($Data, [byte]0xFF, $start)
        if ($p -lt 0 -or $p + $Pattern.Length -gt $Data.Length) { break }
        $ok = $true
        for ($i = 1; $i -lt $Pattern.Length; $i++) {
            if ($null -ne $Pattern[$i] -and $Data[$p + $i] -ne $Pattern[$i]) { $ok = $false; break }
        }
        if ($ok) {
            $site = $p + $SiteOffset
            $isOriginal = Test-Bytes $Data $site $Original
            $isPatched = Test-Bytes $Data $site $Patched
            $rel = [BitConverter]::ToInt32($Data, $site + 2)
            # Original: jne at $site (6 bytes). Patched: jmp at $site+1 (5 bytes). Both end at $site+6.
            if (($isOriginal -or $isPatched) -and (Test-Bytes $Data ($site + 6 + $rel) $TargetBytes)) {
                $sites += [pscustomobject]@{ Offset = $site; Patched = $isPatched }
            }
        }
        $start = $p + 1
    }
    return , $sites
}

function Invoke-Fix {
    $exe = Find-Exe
    Write-Host "Game file: $exe"
    $md5 = (Get-FileHash -LiteralPath $exe -Algorithm MD5).Hash
    if ($KnownBuilds.ContainsKey($md5)) { Write-Host "Build:     $($KnownBuilds[$md5]) (tested)" }
    else { Write-Host "Build:     unknown (MD5 $md5). Not tested; the script patches it only if the pattern matches once." }

    $data = [IO.File]::ReadAllBytes($exe)
    $sites = Find-Sites $data
    if ($sites.Count -ne 1) {
        throw "Found $($sites.Count) matching sites (expected 1). This build is not supported. Nothing was changed."
    }
    $site = $sites[0]
    Write-Host ("Patch site: file offset 0x{0:X}, state: {1}" -f $site.Offset, $(if ($site.Patched) { 'patched' } else { 'original' }))

    if ($Check) { return }
    if ($Undo -and -not $site.Patched) { Write-Host 'The file is already original. Nothing to do.'; return }
    if (-not $Undo -and $site.Patched) { Write-Host 'The fix is already applied. Nothing to do.'; return }

    if (Get-Process -Name nocturne -ErrorAction SilentlyContinue) {
        throw 'Nocturne is running. Close the game, then run this script again.'
    }

    $backup = "$exe.clockfix-backup"
    if (-not $Undo -and -not (Test-Path -LiteralPath $backup)) {
        Copy-Item -LiteralPath $exe -Destination $backup
        Write-Host "Backup:    $backup"
    }

    $new = if ($Undo) { $Original } else { $Patched }
    [Array]::Copy($new, 0, $data, $site.Offset, $new.Length)
    $item = Get-Item -LiteralPath $exe
    $wasReadOnly = $item.IsReadOnly
    if ($wasReadOnly) { $item.IsReadOnly = $false }
    try {
        [IO.File]::WriteAllBytes($exe, $data)
    } catch [UnauthorizedAccessException] {
        throw 'Windows refused to write nocturne.exe. If the game is under Program Files, run this script as administrator.'
    } finally {
        if ($wasReadOnly) { $item.IsReadOnly = $true }
    }

    $verify = Find-Sites ([IO.File]::ReadAllBytes($exe))
    if ($verify.Count -ne 1 -or $verify[0].Patched -eq [bool]$Undo) { throw 'The write did not apply. Restore the backup.' }
    if ($Undo) { Write-Host 'Done. The original clock code is back.' } else { Write-Host 'Done. Nocturne now uses its timeGetTime clock.' }
    Write-Host ("New MD5:   {0}" -f (Get-FileHash -LiteralPath $exe -Algorithm MD5).Hash)
}

Write-Host "Nocturne Clock Fix $Version"
try {
    Invoke-Fix
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

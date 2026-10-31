<#
.SYNOPSIS
  Fixes the long menu and loading freezes of Nocturne (1999) on fast CPUs, and the restless cloth physics.

.DESCRIPTION
  Clock fix: Nocturne's clock drops the fraction of each time step. On a modern CPU a step is less than one
  clock unit, so the clock stops and the game spins at 100% CPU until Windows interrupts it. This script
  changes 2 bytes in nocturne.exe so that the game uses its own timeGetTime clock, which does not lose time.

  Cloth fix: the cloth solver tuning depends on the frame rate, and cloth never settles when the character
  stands still. This script adds a small routine to nocturne.exe. It runs cloth at a fixed 30 Hz, stops
  particles that barely move, and interpolates the frames between two steps.

  The script finds the clock patch site by a byte pattern, checks the jump target, and saves a backup before
  it writes. It applies the cloth fix only if all the code that it needs is at the expected place. On other
  builds it applies the clock fix only. It never downloads or ships any game file.

.PARAMETER GameDir
  The Nocturne folder (the one that contains nocturne.exe). Default: the folder of this script, then the
  current folder.

.PARAMETER Undo
  Remove both fixes.

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
$Version = '1.1.0'

# Builds that were tested. Other builds are patched only if the pattern matches once.
$KnownBuilds = @{
    '24ACD9B17F6846225123A9D8354B09E1' = 'nocturne.exe 1999-11-02 (1,948,160 bytes), unpatched'
    '2D094A32C4416E1A19F30C1AA8BB6067' = 'nocturne.exe 1999-11-02 (1,948,160 bytes), clock fix applied'
    '04878E5B3552B9D018398C952FEEF29A' = 'nocturne.exe 1999-11-02 (1,948,160 bytes), clock and cloth fixes applied'
}

# call [QueryPerformanceFrequency] ; cmp eax,1 ; jne/jmp rel32 ; fild dword [...]
# $null = any byte. Index 9-10 holds 0F 85 (original jne) or 90 E9 (patched nop; jmp).
$Pattern = @(0xFF, 0x15, $null, $null, $null, $null, 0x83, 0xF8, 0x01, $null, $null, $null, $null, $null, $null, 0xDB, 0x05)
$SiteOffset = 9
$Original = [byte[]](0x0F, 0x85)
$Patched = [byte[]](0x90, 0xE9)
# The jump goes to the timeGetTime setup: mov ecx,1 ; push ecx ; mov [flag],ecx
$TargetBytes = [byte[]](0xB9, 0x01, 0x00, 0x00, 0x00, 0x51, 0x89, 0x0D)

function ConvertFrom-Hex([string]$Hex) {
    $bytes = New-Object byte[] ($Hex.Length / 2)
    for ($i = 0; $i -lt $bytes.Length; $i++) { $bytes[$i] = [Convert]::ToByte($Hex.Substring($i * 2, 2), 16) }
    return , $bytes
}

# Cloth fix. Fixed file offsets of the 1.00.52 build; the source of the routine is in cloth\cave.s.
$ClothCaveOffset = 0x174020
$ClothCaveSize = 480
$ClothCave = ConvertFrom-Hex (@'
E905000000E98E00000081BFFC790300434C54317417C787FC790300434C5431A19C4D57008987007A0300EB5BD987007A03
00D84520D815984D5700DFE09E730BD99F007A0300E9C8000000D825984D5700D94520D81D984D5700DFE09E731BD99F007A
0300A1984D5700894520A1A04D5700898700AB0300EB0DDDD8A19C4D57008987007A03008B551C528D44240C50B88C714300
FFE08B8F040100008DB798030000D94520D80DA44D5700D8C885C97E5F837E74007550D906D8A6CC000000D8C8D94604D8A6
D0000000D8C8DEC1D94608D8A6D4000000D8C8DEC1D8D9DFE09E73258B86CC00000089068B86D00000008946048B86D40000
0089460831C089462489462889462C81C61C01000049EB9DDDD88B8F040100008B9F0C0100008DB798030000D987007A0300
D80DA04D570085C97E3831D2D90416837E74007510D8A416CC000000D8C9D88416CC000000D80D60B35900DB1C1383C20483
FA0C7CD681C61C01000083C30C49EBC4DDD8B8A0774300FFE0908988083D5F74083D0000F0410000403F
'@ -replace '\s', '')
$ClothHooks = @(
    @{ Offset = 0x36583; Original = (ConvertFrom-Hex '8B551C528D44240C50'); Patched = (ConvertFrom-Hex 'E998DA130090909090') }
    @{ Offset = 0x36B4C; Original = (ConvertFrom-Hex '8BB704010000'); Patched = (ConvertFrom-Hex 'E9D4D4130090') }
)
# Code and data that the routine uses: call after hook 1, exit of CCloth::simulate, float 256.0.
$ClothChecks = @(
    @{ Offset = 0x3658C; Bytes = (ConvertFrom-Hex 'E8') }
    @{ Offset = 0x36BA0; Bytes = (ConvertFrom-Hex '89EC5D5F5E5BC3') }
    @{ Offset = 0x199760; Bytes = (ConvertFrom-Hex '00008043') }
)

function Get-Md5([string]$Path) {
    $md5 = [Security.Cryptography.MD5]::Create()
    return [BitConverter]::ToString($md5.ComputeHash([IO.File]::ReadAllBytes($Path))).Replace('-', '')
}

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

# Returns 'original', 'patched' or 'unsupported'.
function Get-ClothState([byte[]]$Data) {
    foreach ($c in $ClothChecks) {
        if (-not (Test-Bytes $Data $c.Offset $c.Bytes)) { return 'unsupported' }
    }
    if ($ClothCaveOffset + $ClothCaveSize -gt $Data.Length) { return 'unsupported' }
    $isOriginal = $true
    $isPatched = Test-Bytes $Data $ClothCaveOffset $ClothCave
    foreach ($h in $ClothHooks) {
        if (-not (Test-Bytes $Data $h.Offset $h.Original)) { $isOriginal = $false }
        if (-not (Test-Bytes $Data $h.Offset $h.Patched)) { $isPatched = $false }
    }
    for ($i = 0; $i -lt $ClothCaveSize -and $isOriginal; $i++) {
        if ($Data[$ClothCaveOffset + $i] -ne 0) { $isOriginal = $false }
    }
    if ($isPatched) { return 'patched' }
    if ($isOriginal) { return 'original' }
    return 'unsupported'
}

function Set-ClothFix([byte[]]$Data, [bool]$Apply) {
    foreach ($h in $ClothHooks) {
        $new = if ($Apply) { $h.Patched } else { $h.Original }
        [Array]::Copy($new, 0, $Data, $h.Offset, $new.Length)
    }
    if ($Apply) { [Array]::Copy($ClothCave, 0, $Data, $ClothCaveOffset, $ClothCave.Length) }
    else { [Array]::Clear($Data, $ClothCaveOffset, $ClothCaveSize) }
}

function Invoke-Fix {
    $exe = Find-Exe
    Write-Host "Game file: $exe"
    $md5 = (Get-Md5 $exe)
    if ($KnownBuilds.ContainsKey($md5)) { Write-Host "Build:     $($KnownBuilds[$md5]) (tested)" }
    else { Write-Host "Build:     unknown (MD5 $md5). Not tested; the script patches it only if the pattern matches once." }

    $data = [IO.File]::ReadAllBytes($exe)
    $sites = Find-Sites $data
    if ($sites.Count -ne 1) {
        throw "Found $($sites.Count) matching sites (expected 1). This build is not supported. Nothing was changed."
    }
    $site = $sites[0]
    $cloth = Get-ClothState $data
    Write-Host ("Clock fix: file offset 0x{0:X}, state: {1}" -f $site.Offset, $(if ($site.Patched) { 'patched' } else { 'original' }))
    Write-Host "Cloth fix: state: $cloth"

    if ($Check) { return }
    if ($Undo) {
        $changeClock = $site.Patched
        $changeCloth = $cloth -eq 'patched'
        if (-not ($changeClock -or $changeCloth)) { Write-Host 'The file is already original. Nothing to do.'; return }
    } else {
        $changeClock = -not $site.Patched
        $changeCloth = $cloth -eq 'original'
        if ($cloth -eq 'unsupported') { Write-Host 'This build does not support the cloth fix. Only the clock fix applies.' }
        if (-not ($changeClock -or $changeCloth)) { Write-Host 'The fixes are already applied. Nothing to do.'; return }
    }

    if (Get-Process -Name nocturne -ErrorAction SilentlyContinue) {
        throw 'Nocturne is running. Close the game, then run this script again.'
    }

    $backup = "$exe.clockfix-backup"
    if (-not $Undo -and -not (Test-Path -LiteralPath $backup)) {
        Copy-Item -LiteralPath $exe -Destination $backup
        Write-Host "Backup:    $backup"
    }

    if ($changeClock) {
        $new = if ($Undo) { $Original } else { $Patched }
        [Array]::Copy($new, 0, $data, $site.Offset, $new.Length)
    }
    if ($changeCloth) { Set-ClothFix $data (-not $Undo) }

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

    $written = [IO.File]::ReadAllBytes($exe)
    $verify = Find-Sites $written
    if ($verify.Count -ne 1 -or $verify[0].Patched -eq [bool]$Undo) { throw 'The write did not apply. Restore the backup.' }
    if ($changeCloth -and (Get-ClothState $written) -ne $(if ($Undo) { 'original' } else { 'patched' })) {
        throw 'The write did not apply. Restore the backup.'
    }
    if ($Undo) { Write-Host 'Done. The original code is back.' }
    elseif ($cloth -eq 'unsupported') { Write-Host 'Done. Nocturne now uses its timeGetTime clock.' }
    else { Write-Host 'Done. Nocturne now uses its timeGetTime clock and the fixed cloth step.' }
    Write-Host ("New MD5:   {0}" -f (Get-Md5 $exe))
}

Write-Host "Nocturne Clock Fix $Version"
try {
    Invoke-Fix
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

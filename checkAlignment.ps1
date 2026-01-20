param(
  [Parameter(Mandatory = $true)]
  [string]$AarPath,

  # Optional: path to llvm-readelf.exe
  [string]$NdkReadelf = "$Env:ANDROID_NDK_HOME\toolchains\llvm\prebuilt\windows-x86_64\bin\llvm-readelf.exe",

  # Optional: if you already extracted the AAR somewhere, point here and we won't extract again
  [string]$ExtractedDir = ""
)

$ErrorActionPreference = "Stop"

function Get-Readelf {
  param([string]$PathHint)
  if ($PathHint -and (Test-Path $PathHint)) { return (Resolve-Path $PathHint).Path }
  $cand = "$Env:ANDROID_NDK_HOME\toolchains\llvm\prebuilt\windows-x86_64\bin\llvm-readelf.exe"
  if ($Env:ANDROID_NDK_HOME -and (Test-Path $cand)) { return (Resolve-Path $cand).Path }
  throw "Couldn't find llvm-readelf.exe. Set ANDROID_NDK_HOME or pass -NdkReadelf <path-to-llvm-readelf.exe>."
}

function Extract-Aar {
  param([string]$Src, [string]$Dst)
  if (-not (Test-Path $Src)) { throw "AAR not found: $Src" }
  if (Test-Path $Dst) { Remove-Item $Dst -Recurse -Force -ErrorAction SilentlyContinue }
  New-Item -ItemType Directory -Path $Dst | Out-Null

  $sevenZip = Get-Command 7z -ErrorAction SilentlyContinue
  if ($sevenZip) {
    Write-Host "Extracting with 7-Zip to: $Dst"
    & $sevenZip.Source "x" "-y" $Src "-o$Dst" | Out-Null
  } else {
    Write-Host "Extracting with Expand-Archive to: $Dst"
    Expand-Archive -Path $Src -DestinationPath $Dst -Force
  }
}

# ---- main ----
$readelf = Get-Readelf -PathHint $NdkReadelf

if ($ExtractedDir) {
  $root = (Resolve-Path $ExtractedDir).Path
  Write-Host "Using existing extracted directory: $root"
} else {
  $root = Join-Path $env:TEMP ("aar_so_check_" + [IO.Path]::GetFileNameWithoutExtension($AarPath) + "_" + [guid]::NewGuid())
  Extract-Aar -Src $AarPath -Dst $root
}

Write-Host "Searching for .so files under: $root"
$soFiles = Get-ChildItem -Path $root -Recurse -Filter *.so -File

if (-not $soFiles) {
  Write-Host "No .so files found under: $root"
  exit 1
}

$anyFail = $false
foreach ($so in $soFiles) {
  $out = & $readelf -l -W $so.FullName
  $loadLines = ($out | Select-String -Pattern '^\s*LOAD').Line
  if (-not $loadLines) {
    Write-Host "[WARN] $($so.FullName): no PT_LOAD segments found."
    continue
  }
  $ok = $true
  foreach ($line in $loadLines) {
    $cols = ($line -replace '\s+', ' ').Trim().Split(' ')
    $align = $cols[-1]  # e.g., 0x4000
    if ($align -ne '0x4000') { $ok = $false }
  }
  if ($ok) { Write-Host "[OK]   $($so.FullName) — PT_LOAD Align = 0x4000" }
  else     { Write-Host "[FAIL] $($so.FullName) — one or more PT_LOAD segments not 0x4000"; $anyFail = $true }
}

if ($anyFail) { exit 2 } else { exit 0 }

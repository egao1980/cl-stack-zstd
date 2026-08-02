# Build shared libzstd into lib/windows-amd64/.
# Requires: Visual Studio Build Tools (cmake/cl), curl.
# Usage: .\scripts\build-zstd.ps1
# Env: ZSTD_VERSION (default 1.5.7), DEST_DIR (optional)
$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ZstdVersion = if ($env:ZSTD_VERSION) { $env:ZSTD_VERSION } else { "1.5.7" }
$Os = "windows"
$Arch = "amd64"
$Out = if ($env:DEST_DIR) { $env:DEST_DIR } else { Join-Path $Root "lib\$Os-$Arch" }
$Build = Join-Path $Root "build\zstd-$ZstdVersion-$Os-$Arch"
$SrcTgz = Join-Path $Root "build\zstd-$ZstdVersion.tar.gz"
$SrcUrl = "https://github.com/facebook/zstd/releases/download/v$ZstdVersion/zstd-$ZstdVersion.tar.gz"

New-Item -ItemType Directory -Force -Path (Join-Path $Root "build") | Out-Null
New-Item -ItemType Directory -Force -Path $Out | Out-Null

if (-not (Test-Path $SrcTgz)) {
  Write-Host "==> download $SrcUrl"
  Invoke-WebRequest -Uri $SrcUrl -OutFile $SrcTgz
}

if (Test-Path $Build) { Remove-Item -Recurse -Force $Build }
New-Item -ItemType Directory -Force -Path $Build | Out-Null
tar -xzf $SrcTgz -C $Build --strip-components=1

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vswhere) {
  $vsDevCmd = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
    -property installationPath
  if ($vsDevCmd) {
    $devCmd = Join-Path $vsDevCmd "Common7\Tools\VsDevCmd.bat"
    if (Test-Path $devCmd) {
      Write-Host "==> enter VS x64 env via VsDevCmd.bat"
      cmd /c "`"$devCmd`" -arch=amd64 -host_arch=amd64 && set" | ForEach-Object {
        if ($_ -match '^(.*?)=(.*)$') { Set-Item -Path "env:$($matches[1])" -Value $matches[2] }
      }
    }
  }
}

if (-not (Get-Command cmake -ErrorAction SilentlyContinue)) {
  throw "cmake not found"
}

$Prefix = Join-Path $Build "prefix"
$CmakeBuild = Join-Path $Build "build"
$CmakeSrc = Join-Path $Build "build\cmake"
if (-not (Test-Path (Join-Path $CmakeSrc "CMakeLists.txt"))) {
  $CmakeSrc = $Build
}

Write-Host "==> cmake/build zstd $ZstdVersion -> $Out"
cmake -S $CmakeSrc -B $CmakeBuild `
  -DCMAKE_BUILD_TYPE=Release `
  -DCMAKE_INSTALL_PREFIX="$Prefix" `
  -DZSTD_BUILD_SHARED=ON `
  -DZSTD_BUILD_STATIC=OFF `
  -DZSTD_BUILD_PROGRAMS=OFF `
  -DZSTD_BUILD_TESTS=OFF `
  -DBUILD_SHARED_LIBS=ON
cmake --build $CmakeBuild --config Release -j
cmake --install $CmakeBuild --config Release

Write-Host "==> stage DLLs into $Out"
if (Test-Path $Out) { Remove-Item -Recurse -Force $Out }
New-Item -ItemType Directory -Force -Path $Out | Out-Null

$search = @(
  (Join-Path $Prefix "bin"),
  (Join-Path $Prefix "lib"),
  (Join-Path $CmakeBuild "lib\Release"),
  (Join-Path $CmakeBuild "Release"),
  $CmakeBuild
)
$names = @("libzstd.dll", "zstd.dll")
$copied = $false
foreach ($dir in $search) {
  if (-not (Test-Path $dir)) { continue }
  foreach ($name in $names) {
    $src = Join-Path $dir $name
    if (Test-Path $src) {
      Copy-Item $src (Join-Path $Out "libzstd.dll") -Force
      $copied = $true
      Write-Host "  copied $name -> libzstd.dll"
      break
    }
  }
  if ($copied) { break }
}

if (-not $copied) {
  Get-ChildItem -Recurse $Prefix -Filter *.dll -ErrorAction SilentlyContinue | Format-Table FullName
  Get-ChildItem -Recurse $CmakeBuild -Filter *.dll -ErrorAction SilentlyContinue | Format-Table FullName
  throw "libzstd.dll not found under $Prefix"
}

Write-Host "==> staged:"
Get-ChildItem $Out | Format-Table Name, Length
Write-Host "OK: zstd $ZstdVersion -> $Os/$Arch"

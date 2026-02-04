$ErrorActionPreference = 'Stop'

Write-Host 'Zide Windows bootstrap (vcpkg)'

# Paths
$vcpkgRoot = 'C:\dev\vcpkg-win'
$buildtrees = 'C:\Users\Docker\vcpkg-buildtrees'
$triplet = 'x64-windows'

# Disable binary caching to avoid incomplete cached packages
$env:VCPKG_BINARY_SOURCES = 'clear'

# Ensure buildtrees exists
if (-not (Test-Path $buildtrees)) {
  New-Item -ItemType Directory -Path $buildtrees | Out-Null
}

Push-Location $vcpkgRoot

# Remove relevant packages (classic mode; avoid manifest detection)
& "$vcpkgRoot\vcpkg.exe" remove sdl3 harfbuzz freetype lua --recurse --vcpkg-root $vcpkgRoot

# Clean partial artifacts
Remove-Item -Recurse -Force "$buildtrees\sdl3" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$buildtrees\harfbuzz" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$buildtrees\freetype" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$buildtrees\lua" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$vcpkgRoot\packages\sdl3_$triplet" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$vcpkgRoot\packages\harfbuzz_$triplet" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$vcpkgRoot\packages\freetype_$triplet" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$vcpkgRoot\packages\lua_$triplet" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$vcpkgRoot\installed\$triplet\share\sdl3" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$vcpkgRoot\installed\$triplet\share\harfbuzz" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$vcpkgRoot\installed\$triplet\share\freetype" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$vcpkgRoot\installed\$triplet\share\lua" -ErrorAction SilentlyContinue

# Reinstall with per-user buildtrees root
& "$vcpkgRoot\vcpkg.exe" install sdl3 freetype harfbuzz lua --triplet $triplet --x-buildtrees-root=$buildtrees --vcpkg-root $vcpkgRoot --clean-after-build

# Verify
& "$vcpkgRoot\vcpkg.exe" list --vcpkg-root $vcpkgRoot

# Sanity check for required libs
$harf = Get-ChildItem "$vcpkgRoot\installed\$triplet\lib" -Filter "*harf*.lib" -ErrorAction SilentlyContinue
if (-not $harf) {
  Write-Error "harfbuzz library not found in $vcpkgRoot\installed\$triplet\lib. Re-run with a clean cache."
}

Pop-Location

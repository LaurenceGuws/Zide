param(
  [string]$RootDir = "",
  [string[]]$Groups = @("terminals"),
  [string[]]$Only = @(),
  [switch]$NoDepth
)

$ErrorActionPreference = "Stop"

function Get-RepoRoot {
  $scriptDir = Split-Path -Parent $PSCommandPath
  return (Resolve-Path (Join-Path $scriptDir ".."))
}

function Ensure-Dir([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) {
    New-Item -ItemType Directory -Path $path | Out-Null
  }
}

function Should-Include([string]$name) {
  if ($Only.Count -eq 0) { return $true }
  foreach ($n in $Only) {
    if ($n -eq $name) { return $true }
  }
  return $false
}

function Clone-Repo([string]$destDir, [string]$name, [string]$url) {
  if (-not (Should-Include $name)) {
    return
  }

  $dest = Join-Path $destDir $name
  if (Test-Path -LiteralPath $dest) {
    Write-Host "skip $name (already exists)"
    return
  }

  $args = @("clone")
  if (-not $NoDepth) {
    $args += @("--depth", "1")
  }
  $args += @($url, $dest)

  Write-Host "clone $name -> $dest"
  try {
    & git @args | Out-Host
  } catch {
    Write-Warning "failed $url"
  }
}

function Clone-Group([string]$root, [string]$groupName, [object[]]$repos) {
  $destDir = Join-Path $root $groupName
  Ensure-Dir $destDir
  foreach ($repo in $repos) {
    Clone-Repo $destDir $repo.name $repo.url
  }
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  throw "git not found on PATH"
}

$repoRoot = Get-RepoRoot
if ([string]::IsNullOrWhiteSpace($RootDir)) {
  $RootDir = Join-Path $repoRoot "reference_repos"
}
Ensure-Dir $RootDir

# Keep this list in sync with scripts/setup_reference_repos.sh.
$TERMINAL_REPOS = @(
  @{ name = "kitty"; url = "https://github.com/kovidgoyal/kitty.git" },
  @{ name = "ghostty"; url = "https://github.com/ghostty-org/ghostty.git" },
  @{ name = "alacritty"; url = "https://github.com/alacritty/alacritty.git" },
  @{ name = "wezterm"; url = "https://github.com/wezterm/wezterm.git" },
  @{ name = "foot"; url = "https://github.com/r-c-f/foot.git" },
  @{ name = "rio"; url = "https://github.com/raphamorim/rio.git" },
  @{ name = "contour"; url = "https://github.com/contour-terminal/contour.git" },
  @{ name = "xterm_snapshots"; url = "https://github.com/xterm-x11/xterm-snapshots.git" },
  @{ name = "st"; url = "https://github.com/Shourai/st.git" },
  @{ name = "tabby"; url = "https://github.com/Eugeny/tabby.git" },
  @{ name = "hyper"; url = "https://github.com/vercel/hyper.git" },
  @{ name = "iterm2"; url = "https://github.com/gnachman/iTerm2.git" }
)

$EDITOR_REPOS = @(
  @{ name = "helix"; url = "https://github.com/helix-editor/helix.git" },
  @{ name = "neovim"; url = "https://github.com/neovim/neovim.git" },
  @{ name = "kakoune"; url = "https://github.com/mawww/kakoune.git" },
  @{ name = "lapce"; url = "https://github.com/lapce/lapce.git" },
  @{ name = "zed"; url = "https://github.com/zed-industries/zed.git" },
  @{ name = "xi-editor"; url = "https://github.com/xi-editor/xi-editor.git" },
  @{ name = "lite-xl"; url = "https://github.com/lite-xl/lite-xl.git" }
)

$TEXT_REPOS = @(
  @{ name = "scintilla"; url = "https://github.com/mirror/scintilla.git" }
)

$BACKEND_REPOS = @(
  @{ name = "libtsm"; url = "https://github.com/Aetf/libtsm.git" },
  @{ name = "gnome_vte"; url = "https://github.com/GNOME/vte.git" },
  @{ name = "libvterm"; url = "https://github.com/neovim/libvterm.git" },
  @{ name = "alacritty_vte"; url = "https://github.com/alacritty/vte.git" }
)

$FONT_REPOS = @(
  @{ name = "harfbuzz"; url = "https://github.com/harfbuzz/harfbuzz.git" },
  @{ name = "freetype"; url = "https://github.com/freetype/freetype.git" },
  @{ name = "graphite2"; url = "https://github.com/Distrotech/graphite2.git" },
  @{ name = "unicode_width"; url = "https://github.com/alacritty/unicode-width-16.git" },
  @{ name = "crossfont"; url = "https://github.com/alacritty/crossfont.git" }
)

$RENDER_REPOS = @(
  @{ name = "skia"; url = "https://github.com/google/skia.git" },
  @{ name = "pixman"; url = "https://gitlab.freedesktop.org/pixman/pixman.git" },
  @{ name = "wgpu"; url = "https://github.com/gfx-rs/wgpu.git" }
)

$groupsLower = @()
foreach ($g in $Groups) { $groupsLower += $g.ToLowerInvariant() }

if ($groupsLower -contains "terminals") { Clone-Group $RootDir "terminals" $TERMINAL_REPOS }
if ($groupsLower -contains "editors") { Clone-Group $RootDir "editors" $EDITOR_REPOS }
if ($groupsLower -contains "text") { Clone-Group $RootDir "text" $TEXT_REPOS }
if ($groupsLower -contains "backends") { Clone-Group $RootDir "backends" $BACKEND_REPOS }
if ($groupsLower -contains "fonts") { Clone-Group $RootDir "fonts" $FONT_REPOS }
if ($groupsLower -contains "rendering") { Clone-Group $RootDir "rendering" $RENDER_REPOS }

Write-Host "done."

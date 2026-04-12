#!/usr/bin/env python3
"""Build, deploy, and inspect the Zide Android terminal host."""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
import platform
import shlex
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.parse
import urllib.request
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import NoReturn


ROOT = Path(__file__).resolve().parents[1]
BRIDGE_DIR = ROOT / "android" / "terminal-host"
PACKAGE_NAME = "dev.zide.terminal"
ACTIVITY_NAME = f"{PACKAGE_NAME}/.ZideTerminalActivity"
LEGACY_PACKAGE_NAMES = ("dev.zide.androidbootstrap",)
NDK_VERSION = os.environ.get("ZIDE_ANDROID_NDK_VERSION", "27.1.12297006")
ANDROID_API = "29"
USERLAND_CACHE_DIR = ROOT / ".cache" / "android-userland"
USERLAND_PACKAGE_CACHE_DIR = USERLAND_CACHE_DIR / "packages"
USERLAND_ARTIFACT_CACHE_DIR = USERLAND_CACHE_DIR / "artifacts"
USERLAND_RELEASE_API = "https://api.github.com/repos/termux/termux-packages/releases/latest"
USERLAND_ASSET_NAME = "bootstrap-aarch64.zip"
USERLAND_RELEASE_DESCRIPTOR = (
    ROOT / "android" / "terminal-host" / "app" / "src" / "main" / "assets" / "userland_release.json"
)
TERMUX_MAIN_BASE_URL = "https://packages.termux.dev/apt/termux-main/"
TERMUX_MAIN_PACKAGES_URL = TERMUX_MAIN_BASE_URL + "dists/stable/main/binary-aarch64/Packages"
REMOTE_APP_FILES_DIR = f"/data/data/{PACKAGE_NAME}/files"
REMOTE_APP_PACKAGE_DIR = f"/data/user/0/{PACKAGE_NAME}"
REMOTE_USERLAND_PREFIX = f"{REMOTE_APP_FILES_DIR}/usr"
REMOTE_USERLAND_HOME = f"{REMOTE_APP_FILES_DIR}/home"
REMOTE_USERLAND_TMP = f"/data/user/0/{PACKAGE_NAME}/tmp"
REMOTE_USERLAND_APT_CONF_PARTS = f"/data/user/0/{PACKAGE_NAME}/aptc"
REMOTE_USERLAND_DPKG_ETC = f"/data/user/0/{PACKAGE_NAME}/dpkg"
REMOTE_USERLAND_DPKG_DB = f"/data/user/0/{PACKAGE_NAME}/dpkgdb"
REMOTE_USERLAND_STAMP = f"{REMOTE_APP_FILES_DIR}/.zide-userland-bootstrap.json"
REMOTE_STAGE_TAR = f"/data/local/tmp/{PACKAGE_NAME.replace('.', '_')}_userland_stage.tar"
USERLAND_HARDCODED_TERMUX_PREFIX = b"/data/data/com.termux/files/usr"
USERLAND_HARDCODED_TERMUX_PREFIX_TEXT = USERLAND_HARDCODED_TERMUX_PREFIX.decode("utf-8")
USERLAND_HARDCODED_TERMUX_TMP = b"/data/data/com.termux/files/usr/tmp"
USERLAND_HARDCODED_TERMUX_APT_CONF_PARTS = b"/data/data/com.termux/files/usr/etc/apt/apt.conf.d"
USERLAND_HARDCODED_TERMUX_DPKG_ETC = b"/data/data/com.termux/files/usr/etc/dpkg"
USERLAND_HARDCODED_TERMUX_DPKG_DB = b"/data/data/com.termux/files/usr/var/lib/dpkg"
COMMAND_HELP: dict[str, str] = {
    "native": "Build the Zig Android shared library (.so) into jniLibs.",
    "apk": "Build the debug APK with Gradle.",
    "install": "Install the current debug APK on the connected device.",
    "launch": "Launch the terminal host activity on the connected device.",
    "deploy": "Run native + apk + install + launch.",
    "clean": "Run Gradle clean for android/terminal-host.",
    "reinstall": "Uninstall current + legacy package names, then install + launch.",
    "logcat": "Print filtered Android logs for the terminal host lane.",
    "doctor": "Print resolved toolchain paths and run adb version.",
    "userland-fetch-ref": "Download the latest upstream aarch64 bootstrap zip on Linux for inspection/staging.",
    "userland-inspect": "Inspect a local bootstrap archive/tree, or the cached upstream reference if none is provided.",
    "userland-stage": "Stage a bootstrap archive/tree into the Android app sandbox, defaulting to the cached upstream reference.",
    "userland-stage-artifact": "Stage a published Android prefix archive manifest into the app sandbox.",
    "userland-state": "Print the currently staged Android userland state from the device.",
    "userland-stage-packages": "Dev-provider path: stage relocated Termux packages into the app sandbox.",
    "userland-bash-version": "Run the staged app-private Bash under run-as and print its version banner.",
    "userland-smoke-baseline": "Run the curated staged-userland smoke: Bash, Git, ripgrep, Neovim, htop, gotop, zide-pm.",
    "userland-nvim-manual-check": "Print the exact in-app Neovim validation steps for the current Android terminal lane.",
    "userland-apt-update": "Probe apt-get update against the staged userland with the current relocation overrides.",
    "userland-apt-install": "Install packages into the staged app-private userland with the current relocation overrides.",
    "help": "Show this help.",
}

ACTIVE_VARIANT = "debug"


def current_variant() -> str:
    return ACTIVE_VARIANT


def gradle_variant_name() -> str:
    variant = current_variant()
    if variant not in ("debug", "profile", "release"):
        die(f"unsupported Android variant: {variant}")
    return variant


def apk_path() -> Path:
    variant = gradle_variant_name()
    return BRIDGE_DIR / "app" / "build" / "outputs" / "apk" / variant / f"app-{variant}.apk"


def zig_optimize_flag() -> str:
    variant = current_variant()
    if variant == "debug":
        return "Debug"
    if variant in ("profile", "release"):
        return "ReleaseFast"
    die(f"unsupported Android variant for Zig optimize mode: {variant}")


@dataclass(frozen=True)
class BootstrapInspection:
    source: Path
    format_name: str
    has_bash: bool
    has_apt: bool
    has_nvim: bool
    has_btop: bool
    symlink_count: int
    hardcoded_termux_hits: list[str]


@dataclass(frozen=True)
class TermuxPackage:
    name: str
    version: str
    filename: str
    depends: tuple[str, ...]


@dataclass(frozen=True)
class UserlandArtifact:
    name: str
    version: str
    url: str
    sha256: str
    size: int
    archive_root: str
    provider: str
    hardcoded_termux_policy: str
    runtime_support_links: tuple[tuple[str, str], ...]


@dataclass(frozen=True)
class InstalledUserlandState:
    installed: bool
    format_name: str
    artifact: str
    version: str
    provider: str
    shell_exists: bool
    launch_ready: bool


def userland_release_descriptor() -> dict[str, str]:
    payload = json.loads(USERLAND_RELEASE_DESCRIPTOR.read_text(encoding="utf-8"))
    manifest_url = payload.get("manifest_url")
    artifact_name = payload.get("artifact_name")
    artifact_version = payload.get("artifact_version")
    provider = payload.get("provider")
    if not all(isinstance(value, str) and value for value in (manifest_url, artifact_name, artifact_version, provider)):
        die(f"invalid userland release descriptor: {USERLAND_RELEASE_DESCRIPTOR}")
    return {
        "manifest_url": manifest_url,
        "artifact_name": artifact_name,
        "artifact_version": artifact_version,
        "provider": provider,
    }


def die(message: str) -> NoReturn:
    print(message, file=sys.stderr)
    raise SystemExit(1)


def run(args: list[str | os.PathLike[str]], *, cwd: Path | None = None) -> None:
    printable = " ".join(str(arg) for arg in args)
    if cwd is not None:
        print(f"+ cd {cwd} && {printable}", flush=True)
    else:
        print(f"+ {printable}", flush=True)
    subprocess.run([str(arg) for arg in args], cwd=cwd, check=True)


def is_url(value: str) -> bool:
    parsed = urllib.parse.urlparse(value)
    return parsed.scheme in ("http", "https")


def github_token() -> str | None:
    for name in ("GH_TOKEN", "GITHUB_TOKEN"):
        value = os.environ.get(name)
        if value:
            return value
    gh = shutil.which("gh")
    if gh is None:
        return None
    result = subprocess.run(
        [gh, "auth", "token"],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        return None
    token = result.stdout.strip()
    return token or None


def url_request(url: str) -> urllib.request.Request:
    headers = {"User-Agent": "zide-android-terminal-host"}
    parsed = urllib.parse.urlparse(url)
    if parsed.hostname == "github.com":
        token = github_token()
        if token is not None:
            headers["Authorization"] = f"Bearer {token}"
    return urllib.request.Request(url, headers=headers)


def read_url(url: str, *, timeout: int = 120) -> bytes:
    with urllib.request.urlopen(url_request(url), timeout=timeout) as response:
        return response.read()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify_file_size_and_sha256(path: Path, *, size: int, sha256: str) -> bool:
    if not path.is_file():
        return False
    if size >= 0 and path.stat().st_size != size:
        return False
    return sha256_file(path) == sha256


def sdk_candidates() -> list[str]:
    candidates: list[str] = []
    for name in ("ANDROID_SDK_ROOT", "ANDROID_HOME"):
        value = os.environ.get(name)
        if value:
            candidates.append(value)
    candidates.append(str(Path.home() / ".local" / "share" / "zide-android-sdk"))
    candidates.append("/opt/android-sdk")
    return candidates


def sdk_root(*, require_ndk: bool = False) -> Path:
    fallback: Path | None = None
    for candidate in sdk_candidates():
        if not candidate:
            continue
        path = Path(candidate)
        if not path.is_dir():
            continue
        if fallback is None:
            fallback = path.resolve()
        if require_ndk and not (path / "ndk" / NDK_VERSION).is_dir():
            continue
        resolved = path.resolve()
        os.environ["ANDROID_HOME"] = str(resolved)
        os.environ["ANDROID_SDK_ROOT"] = str(resolved)
        return resolved
    if require_ndk:
        searched = ", ".join(str(Path(candidate) / "ndk" / NDK_VERSION) for candidate in sdk_candidates() if candidate)
        die(f"missing Android NDK {NDK_VERSION}; searched {searched}")
    if fallback is not None:
        os.environ["ANDROID_HOME"] = str(fallback)
        os.environ["ANDROID_SDK_ROOT"] = str(fallback)
        return fallback
    die("missing Android SDK: set ANDROID_HOME or ANDROID_SDK_ROOT")


def adb_path(sdk: Path) -> Path:
    suffix = ".exe" if os.name == "nt" else ""
    adb = sdk / "platform-tools" / f"adb{suffix}"
    if not adb.is_file():
        die(f"missing adb: {adb}")
    return adb


def connected_device_serials(adb: Path) -> list[str]:
    result = subprocess.run(
        [str(adb), "devices"],
        check=True,
        capture_output=True,
        text=True,
    )
    serials: list[str] = []
    for line in result.stdout.splitlines()[1:]:
        stripped = line.strip()
        if not stripped:
            continue
        parts = stripped.split()
        if len(parts) >= 2 and parts[1] == "device":
            serials.append(parts[0])
    return serials


def adb_target_args(adb: Path) -> list[str]:
    explicit_serial = os.environ.get("ZIDE_ANDROID_SERIAL") or os.environ.get("ANDROID_SERIAL")
    if explicit_serial:
        return [str(adb), "-s", explicit_serial]

    serials = connected_device_serials(adb)
    if len(serials) <= 1:
        return [str(adb)]

    usb_serials = [serial for serial in serials if ":" not in serial]
    if len(usb_serials) == 1:
        return [str(adb), "-s", usb_serials[0]]

    joined = ", ".join(serials)
    die(
        "multiple adb targets detected; set ZIDE_ANDROID_SERIAL or ANDROID_SERIAL "
        f"to one of: {joined}"
    )


def gradle_wrapper() -> Path:
    wrapper = BRIDGE_DIR / ("gradlew.bat" if os.name == "nt" else "gradlew")
    if not wrapper.is_file():
        die(f"missing Gradle wrapper: {wrapper}")
    return wrapper


def ndk_prebuilt_name() -> str:
    system = platform.system().lower()
    machine = platform.machine().lower()
    if system == "linux":
        return "linux-x86_64"
    if system == "darwin":
        return "darwin-x86_64"
    if system == "windows":
        return "windows-x86_64"
    die(f"unsupported host for Android NDK toolchain: {platform.system()} {machine}")


def android_clang(sdk: Path) -> Path:
    toolchain = sdk / "ndk" / NDK_VERSION / "toolchains" / "llvm" / "prebuilt" / ndk_prebuilt_name()
    suffix = ".cmd" if os.name == "nt" else ""
    clang = toolchain / "bin" / f"aarch64-linux-android{ANDROID_API}-clang{suffix}"
    if not clang.is_file():
        die(
            f"missing Android clang linker: {clang}\n"
            f"install NDK {NDK_VERSION} into {sdk} before building the bridge"
        )
    return clang


def android_sysroot(sdk: Path) -> Path:
    return android_clang(sdk).parents[1] / "sysroot"


def zig_path() -> str:
    zig = shutil.which("zig")
    if zig is None:
        die("missing zig on PATH")
    return zig


def userland_release_metadata() -> tuple[str, str, int]:
    with urllib.request.urlopen(url_request(USERLAND_RELEASE_API), timeout=30) as response:
        payload = json.load(response)
    assets = payload.get("assets")
    if not isinstance(assets, list):
        die("unexpected GitHub release payload: missing assets")
    for asset in assets:
        if not isinstance(asset, dict):
            continue
        name = asset.get("name")
        url = asset.get("browser_download_url")
        size = asset.get("size")
        if name == USERLAND_ASSET_NAME and isinstance(url, str) and isinstance(size, int):
            tag_name = payload.get("tag_name")
            if not isinstance(tag_name, str):
                die("unexpected GitHub release payload: missing tag_name")
            return tag_name, url, size
    die(f"latest Termux bootstrap release does not include {USERLAND_ASSET_NAME}")


def fetch_reference_bootstrap(output_override: Path | None) -> Path:
    tag_name, url, size = userland_release_metadata()
    target = output_override if output_override is not None else USERLAND_CACHE_DIR / f"{tag_name}-{USERLAND_ASSET_NAME}"
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.is_file() and target.stat().st_size == size:
        print(f"reused {target}", flush=True)
        return target

    with urllib.request.urlopen(url_request(url), timeout=120) as source, target.open("wb") as out_file:
        while True:
            chunk = source.read(1024 * 1024)
            if not chunk:
                break
            out_file.write(chunk)
    if target.stat().st_size != size:
        die(f"downloaded bootstrap has wrong size: expected {size}, got {target.stat().st_size}")
    print(f"downloaded {target}", flush=True)
    return target


def fetch_termux_package_index() -> dict[str, TermuxPackage]:
    cache_path = USERLAND_PACKAGE_CACHE_DIR / "Packages"
    cache_path.parent.mkdir(parents=True, exist_ok=True)
    if not cache_path.is_file():
        with urllib.request.urlopen(url_request(TERMUX_MAIN_PACKAGES_URL), timeout=60) as response, cache_path.open("wb") as out_file:
            shutil.copyfileobj(response, out_file)

    text = cache_path.read_text(encoding="utf-8")
    packages: dict[str, TermuxPackage] = {}
    for block in text.split("\n\n"):
        fields: dict[str, str] = {}
        current_key: str | None = None
        for line in block.splitlines():
            if not line:
                continue
            if line.startswith(" ") and current_key is not None:
                fields[current_key] += "\n" + line[1:]
                continue
            if ":" not in line:
                continue
            key, value = line.split(":", 1)
            current_key = key
            fields[key] = value.strip()

        name = fields.get("Package")
        version = fields.get("Version")
        filename = fields.get("Filename")
        if name is None or version is None or filename is None:
            continue
        packages[name] = TermuxPackage(
            name=name,
            version=version,
            filename=filename,
            depends=parse_dependency_names(fields.get("Depends", "")),
        )
    return packages


def parse_dependency_names(raw_depends: str) -> tuple[str, ...]:
    names: list[str] = []
    for raw_part in raw_depends.split(","):
        alternatives = raw_part.strip().split("|")
        if not alternatives:
            continue
        candidate = alternatives[0].strip()
        if not candidate:
            continue
        name = candidate.split()[0].split(":")[0]
        if name and name not in names:
            names.append(name)
    return tuple(names)


def resolve_termux_package_closure(requested: list[str]) -> list[TermuxPackage]:
    if not requested:
        die("package staging requires at least one package name")

    index = fetch_termux_package_index()
    resolved: list[TermuxPackage] = []
    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(name: str) -> None:
        if name in visited:
            return
        if name in visiting:
            die(f"dependency cycle while resolving Termux package: {name}")
        package = index.get(name)
        if package is None:
            die(f"Termux main package not found: {name}")
        visiting.add(name)
        for dependency in package.depends:
            visit(dependency)
        visiting.remove(name)
        visited.add(name)
        resolved.append(package)

    for name in requested:
        visit(name)
    return resolved


def download_termux_package(package: TermuxPackage) -> Path:
    target = USERLAND_PACKAGE_CACHE_DIR / Path(package.filename).name
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.is_file():
        return target

    url = TERMUX_MAIN_BASE_URL + package.filename
    with urllib.request.urlopen(url_request(url), timeout=120) as response, target.open("wb") as out_file:
        shutil.copyfileobj(response, out_file)
    return target


def deb_member_payload(archive: Path, wanted_prefix: bytes) -> bytes:
    data = archive.read_bytes()
    if not data.startswith(b"!<arch>\n"):
        die(f"unsupported deb archive header: {archive}")

    offset = 8
    while offset + 60 <= len(data):
        header = data[offset : offset + 60]
        offset += 60
        name = header[0:16].decode("utf-8", errors="replace").strip()
        size_text = header[48:58].decode("ascii", errors="replace").strip()
        try:
            size = int(size_text)
        except ValueError:
            die(f"invalid deb member size in {archive}: {size_text}")
        payload = data[offset : offset + size]
        offset += size
        if offset % 2:
            offset += 1
        normalized_name = name.rstrip("/")
        if normalized_name.encode("utf-8").startswith(wanted_prefix):
            return payload
    die(f"missing {wanted_prefix.decode('utf-8')} member in {archive}")


def termux_usr_relative_path(member_name: str) -> str | None:
    normalized = member_name[2:] if member_name.startswith("./") else member_name
    termux_root = "data/data/com.termux/files/usr/"
    if normalized == termux_root.rstrip("/"):
        return ""
    if normalized.startswith(termux_root):
        return normalized[len(termux_root) :]
    return None


def extract_package_usr_payload(package_archive: Path, prefix_root: Path) -> int:
    data_payload = deb_member_payload(package_archive, b"data.tar")
    extracted = 0
    with tarfile.open(fileobj=io.BytesIO(data_payload), mode="r:*") as bundle:
        for member in bundle.getmembers():
            relative_name = termux_usr_relative_path(member.name)
            if relative_name is None or relative_name == "":
                continue
            target = safe_package_output_path(prefix_root, relative_name)
            if member.isdir():
                target.mkdir(parents=True, exist_ok=True)
                if member.mode:
                    os.chmod(target, member.mode & 0o7777)
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            if target.exists() or target.is_symlink():
                if target.is_dir() and not target.is_symlink():
                    shutil.rmtree(target)
                else:
                    target.unlink()
            if member.issym():
                os.symlink(member.linkname, target)
                extracted += 1
                continue
            if member.islnk():
                linked_relative = termux_usr_relative_path(member.linkname)
                if linked_relative is None:
                    continue
                linked_target = safe_package_output_path(prefix_root, linked_relative)
                os.link(linked_target, target)
                extracted += 1
                continue
            if member.isfile():
                source = bundle.extractfile(member)
                if source is None:
                    continue
                with source, target.open("wb") as out_file:
                    shutil.copyfileobj(source, out_file)
                if member.mode:
                    os.chmod(target, member.mode & 0o7777)
                extracted += 1
    return extracted


def archive_from_args(archive_arg: Path | None) -> Path:
    if archive_arg is not None:
        path = archive_arg.expanduser()
        if not path.exists():
            die(f"bootstrap archive/tree does not exist: {path}")
        return path.resolve()
    return fetch_reference_bootstrap(None)


def safe_child_path(root: Path, relative_name: str) -> Path:
    child = (root / relative_name).resolve()
    if not child.is_relative_to(root.resolve()):
        die(f"archive entry escapes extraction root: {relative_name}")
    return child


def safe_package_output_path(root: Path, relative_name: str) -> Path:
    relative = Path(relative_name)
    if relative.is_absolute() or ".." in relative.parts:
        die(f"package entry escapes extraction root: {relative_name}")
    return root / relative


def extract_zip_with_symlinks(archive: Path, out_dir: Path) -> None:
    with zipfile.ZipFile(archive) as bundle:
        symlink_lines: list[str] = []
        try:
            symlink_lines = bundle.read("SYMLINKS.txt").decode("utf-8").splitlines()
        except KeyError:
            symlink_lines = []

        for info in bundle.infolist():
            name = info.filename
            if not name or name.endswith("/") or name == "SYMLINKS.txt":
                continue
            target = safe_child_path(out_dir, name)
            target.parent.mkdir(parents=True, exist_ok=True)
            with bundle.open(info) as src, target.open("wb") as dst:
                shutil.copyfileobj(src, dst)
            mode = (info.external_attr >> 16) & 0o7777
            if mode != 0:
                os.chmod(target, mode)

        for raw_line in symlink_lines:
            line = raw_line.strip()
            if not line:
                continue
            if "←" not in line:
                die(f"unsupported SYMLINKS.txt entry: {raw_line}")
            target_text, link_text = line.split("←", 1)
            relative_link = link_text[2:] if link_text.startswith("./") else link_text
            link_path = safe_child_path(out_dir, relative_link)
            link_path.parent.mkdir(parents=True, exist_ok=True)
            if link_path.exists() or link_path.is_symlink():
                if link_path.is_dir() and not link_path.is_symlink():
                    shutil.rmtree(link_path)
                else:
                    link_path.unlink()
            os.symlink(target_text, link_path)


def extract_tar_archive(archive: Path, out_dir: Path) -> None:
    with tarfile.open(archive) as bundle:
        for member in bundle.getmembers():
            safe_child_path(out_dir, member.name)
        bundle.extractall(out_dir)


def extract_userland_artifact_archive(archive: Path, out_dir: Path) -> Path:
    extracted_root = out_dir / "artifact"
    extracted_root.mkdir(parents=True, exist_ok=True)
    with tarfile.open(archive, mode="r:*") as bundle:
        for member in bundle.getmembers():
            safe_child_path(extracted_root, member.name)
        bundle.extractall(extracted_root)

    usr_root = extracted_root / "usr"
    if not usr_root.is_dir():
        die(f"userland artifact archive does not contain usr/ root: {archive}")
    if not (usr_root / "bin" / "bash").is_file():
        die(f"userland artifact archive does not contain usr/bin/bash: {archive}")
    return extracted_root


def normalize_prefix_root(extracted_root: Path) -> Path:
    usr_root = extracted_root / "usr"
    if usr_root.is_dir() and not (extracted_root / "bin").exists():
        return usr_root
    return extracted_root


def extract_prefix_root(source: Path, work_dir: Path) -> tuple[Path, str]:
    extracted_root = work_dir / "extracted"
    extracted_root.mkdir(parents=True, exist_ok=True)

    if source.is_dir():
        shutil.copytree(source, extracted_root, symlinks=True, dirs_exist_ok=True)
        return normalize_prefix_root(extracted_root), "directory"

    if zipfile.is_zipfile(source):
        extract_zip_with_symlinks(source, extracted_root)
        return normalize_prefix_root(extracted_root), "zip"

    if tarfile.is_tarfile(source):
        extract_tar_archive(source, extracted_root)
        return normalize_prefix_root(extracted_root), "tar"

    die(f"unsupported bootstrap archive format: {source}")


def file_contains_bytes(path: Path, needle: bytes) -> bool:
    overlap = b""
    with path.open("rb") as handle:
        while True:
            chunk = handle.read(1024 * 1024)
            if not chunk:
                return False
            haystack = overlap + chunk
            if needle in haystack:
                return True
            if len(needle) > 1:
                overlap = haystack[-(len(needle) - 1) :]
            else:
                overlap = b""


def inspect_prefix_root(prefix_root: Path, source: Path, format_name: str) -> BootstrapInspection:
    all_files = [path for path in prefix_root.rglob("*") if path.is_file()]
    all_symlinks = [path for path in prefix_root.rglob("*") if path.is_symlink()]
    hardcoded_hits: list[str] = []
    for path in all_files:
        if file_contains_bytes(path, USERLAND_HARDCODED_TERMUX_PREFIX):
            hardcoded_hits.append(path.relative_to(prefix_root).as_posix())

    return BootstrapInspection(
        source=source,
        format_name=format_name,
        has_bash=(prefix_root / "bin" / "bash").exists(),
        has_apt=(prefix_root / "bin" / "apt").exists(),
        has_nvim=(prefix_root / "bin" / "nvim").exists(),
        has_btop=(prefix_root / "bin" / "btop").exists(),
        symlink_count=len(all_symlinks),
        hardcoded_termux_hits=sorted(hardcoded_hits),
    )


def relocate_text_prefixes(prefix_root: Path) -> int:
    rewrites = 0
    for path in prefix_root.rglob("*"):
        if not path.is_file():
            continue
        data = path.read_bytes()
        if USERLAND_HARDCODED_TERMUX_PREFIX not in data or b"\x00" in data:
            continue
        try:
            text = data.decode("utf-8")
        except UnicodeDecodeError:
            continue
        replaced = text.replace(USERLAND_HARDCODED_TERMUX_PREFIX_TEXT, REMOTE_USERLAND_PREFIX)
        if replaced == text:
            continue
        path.write_text(replaced, encoding="utf-8")
        rewrites += 1
    return rewrites


def relocate_symlink_prefixes(prefix_root: Path) -> int:
    rewrites = 0
    for path in prefix_root.rglob("*"):
        if not path.is_symlink():
            continue
        target = os.readlink(path)
        if not target.startswith(USERLAND_HARDCODED_TERMUX_PREFIX_TEXT):
            continue
        replacement = REMOTE_USERLAND_PREFIX + target[len(USERLAND_HARDCODED_TERMUX_PREFIX_TEXT) :]
        path.unlink()
        os.symlink(replacement, path)
        rewrites += 1
    return rewrites


def replace_fixed_width_path(data: bytes, source: bytes, target: bytes) -> tuple[bytes, bool]:
    if len(target) > len(source):
        die(f"replacement path is longer than compiled path: {target.decode('utf-8')}")
    next_data = data.replace(source, target + (b"\x00" * (len(source) - len(target))))
    slash_source = source + b"/"
    slash_target = target + b"/"
    if len(slash_target) <= len(slash_source):
        next_data = next_data.replace(
            slash_source,
            slash_target + (b"\x00" * (len(slash_source) - len(slash_target))),
        )
    return next_data, next_data != data


def patch_compiled_userland_paths(prefix_root: Path) -> int:
    rewrites = 0
    replacements = [
        (USERLAND_HARDCODED_TERMUX_TMP, REMOTE_USERLAND_TMP.encode("utf-8")),
        (USERLAND_HARDCODED_TERMUX_APT_CONF_PARTS, REMOTE_USERLAND_APT_CONF_PARTS.encode("utf-8")),
        (USERLAND_HARDCODED_TERMUX_DPKG_ETC, REMOTE_USERLAND_DPKG_ETC.encode("utf-8")),
        (USERLAND_HARDCODED_TERMUX_DPKG_DB, REMOTE_USERLAND_DPKG_DB.encode("utf-8")),
    ]
    for path in [
        prefix_root / "lib" / "libapt-pkg.so",
        prefix_root / "bin" / "dpkg",
        prefix_root / "bin" / "dpkg-deb",
        prefix_root / "bin" / "dpkg-query",
        prefix_root / "bin" / "dpkg-split",
        prefix_root / "bin" / "dpkg-statoverride",
    ]:
        if not path.is_file():
            continue
        data = path.read_bytes()
        next_data = data
        path_rewrites = 0
        for source, target in replacements:
            next_data, changed = replace_fixed_width_path(next_data, source, target)
            path_rewrites += int(changed)
        if next_data != data:
            path.write_bytes(next_data)
            rewrites += path_rewrites
    return rewrites


def print_inspection(inspection: BootstrapInspection) -> None:
    print(f"source={inspection.source}", flush=True)
    print(f"format={inspection.format_name}", flush=True)
    print(f"has_bash={inspection.has_bash}", flush=True)
    print(f"has_apt={inspection.has_apt}", flush=True)
    print(f"has_nvim={inspection.has_nvim}", flush=True)
    print(f"has_btop={inspection.has_btop}", flush=True)
    print(f"symlink_count={inspection.symlink_count}", flush=True)
    print(f"hardcoded_termux_prefix_hits={len(inspection.hardcoded_termux_hits)}", flush=True)
    for hit in inspection.hardcoded_termux_hits[:20]:
        print(f"  hit={hit}", flush=True)
    if len(inspection.hardcoded_termux_hits) > 20:
        print(f"  ... {len(inspection.hardcoded_termux_hits) - 20} more", flush=True)


def build_userland_stage_tar(prefix_root: Path, inspection: BootstrapInspection, out_tar: Path) -> None:
    staging_root = out_tar.parent / "staging"
    staging_root.mkdir(parents=True, exist_ok=True)

    stamp_path = staging_root / ".zide-userland-bootstrap.json"
    stamp_payload = {
        "source": str(inspection.source),
        "format": inspection.format_name,
        "has_bash": inspection.has_bash,
        "has_apt": inspection.has_apt,
        "has_nvim": inspection.has_nvim,
        "has_btop": inspection.has_btop,
        "hardcoded_termux_prefix_hits": len(inspection.hardcoded_termux_hits),
    }
    stamp_path.write_text(json.dumps(stamp_payload, indent=2) + "\n", encoding="utf-8")

    with tarfile.open(out_tar, "w") as bundle:
        bundle.add(prefix_root, arcname="usr", recursive=True)
        bundle.add(stamp_path, arcname=".zide-userland-bootstrap.json")


def build_userland_artifact_stage_tar(
    artifact_root: Path,
    artifact: UserlandArtifact,
    manifest_source: str,
    out_tar: Path,
) -> None:
    staging_root = out_tar.parent / "artifact-staging"
    staging_root.mkdir(parents=True, exist_ok=True)

    stamp_path = staging_root / ".zide-userland-bootstrap.json"
    stamp_payload = {
        "source": manifest_source,
        "format": "android-prefix-artifact",
        "artifact": artifact.name,
        "version": artifact.version,
        "provider": artifact.provider,
        "archive_root": artifact.archive_root,
        "hardcoded_termux_policy": artifact.hardcoded_termux_policy,
        "has_bash": (artifact_root / "usr" / "bin" / "bash").is_file(),
        "has_apt": (artifact_root / "usr" / "bin" / "apt").is_file(),
        "has_nvim": (artifact_root / "usr" / "bin" / "nvim").is_file(),
        "has_btop": (artifact_root / "usr" / "bin" / "btop").is_file(),
    }
    stamp_path.write_text(json.dumps(stamp_payload, indent=2) + "\n", encoding="utf-8")

    with tarfile.open(out_tar, "w") as bundle:
        bundle.add(artifact_root / "usr", arcname="usr", recursive=True)
        bundle.add(stamp_path, arcname=".zide-userland-bootstrap.json")


def run_remote_shell(adb: Path, command: str, *, check: bool = True, capture_output: bool = False) -> subprocess.CompletedProcess[str]:
    printable = f"{adb} shell {command}"
    print(f"+ {printable}", flush=True)
    return subprocess.run(
        [*adb_target_args(adb), "shell", command],
        check=check,
        capture_output=capture_output,
        text=True,
    )


def build_userland_remote_command(command: str) -> str:
    exports = " ".join(
        [
            f"PREFIX={shlex.quote(REMOTE_USERLAND_PREFIX)}",
            f"HOME={shlex.quote(REMOTE_USERLAND_HOME)}",
            f"TMPDIR={shlex.quote(REMOTE_USERLAND_TMP)}",
            f"LD_LIBRARY_PATH={shlex.quote(REMOTE_USERLAND_PREFIX + '/lib')}",
            f"PATH={shlex.quote(REMOTE_USERLAND_PREFIX + '/bin:/system/bin')}",
            f"SHELL={shlex.quote(REMOTE_USERLAND_PREFIX + '/bin/bash')}",
            f"SSL_CERT_FILE={shlex.quote(REMOTE_USERLAND_PREFIX + '/etc/tls/cert.pem')}",
            f"CURL_CA_BUNDLE={shlex.quote(REMOTE_USERLAND_PREFIX + '/etc/tls/cert.pem')}",
            f"VIMRUNTIME={shlex.quote(REMOTE_USERLAND_PREFIX + '/share/nvim/runtime')}",
            f"XDG_CONFIG_HOME={shlex.quote(REMOTE_USERLAND_HOME + '/.config')}",
            f"XDG_DATA_HOME={shlex.quote(REMOTE_USERLAND_HOME + '/.local/share')}",
            f"XDG_STATE_HOME={shlex.quote(REMOTE_USERLAND_HOME + '/.local/state')}",
            "TERM=xterm-256color",
            "COLORTERM=truecolor",
        ]
    )
    payload = f"export {exports}; {command}"
    return f"run-as {PACKAGE_NAME} sh -c {shlex.quote(payload)}"


def userland_apt_options() -> str:
    prefix = REMOTE_USERLAND_PREFIX
    return " ".join(
        [
            f"-o Dir={shlex.quote(prefix)}",
            f"-o Dir::Etc={shlex.quote(prefix + '/etc/apt')}",
            f"-o Dir::Etc::parts={shlex.quote(prefix + '/etc/apt/apt.conf.d')}",
            f"-o Dir::Etc::sourcelist={shlex.quote(prefix + '/etc/apt/sources.list')}",
            f"-o Dir::Etc::sourceparts={shlex.quote(prefix + '/etc/apt/sources.list.d')}",
            f"-o Dir::State={shlex.quote(prefix + '/var/lib/apt')}",
            f"-o Dir::State::status={shlex.quote(prefix + '/var/lib/dpkg/status')}",
            f"-o Dir::Cache={shlex.quote(prefix + '/var/cache/apt')}",
            f"-o Dir::Cache::archives={shlex.quote(prefix + '/var/cache/apt/archives')}",
            f"-o Dir::Bin::Methods={shlex.quote(prefix + '/lib/apt/methods')}",
            f"-o Dir::Bin::apt-key={shlex.quote(prefix + '/bin/apt-key')}",
            f"-o Dir::Bin::dpkg={shlex.quote(prefix + '/bin/dpkg')}",
            f"-o Dir::Log={shlex.quote(prefix + '/var/log/apt')}",
            f"-o DPkg::Path={shlex.quote(prefix + '/bin:/system/bin')}",
            f"-o Acquire::https::CaInfo={shlex.quote(prefix + '/etc/tls/cert.pem')}",
        ]
    )


def userland_package_manager_prelude() -> str:
    prefix = shlex.quote(REMOTE_USERLAND_PREFIX)
    return " ".join(
        [
            "mkdir -p",
            f"{prefix}/etc/apt/preferences.d",
            f"{prefix}/var/cache/apt/archives/partial",
            f"{prefix}/var/lib/apt/lists/partial",
            f"{prefix}/var/log/apt",
            f"{prefix}/var/lib/dpkg/updates",
            f"{prefix}/var/lib/dpkg/info",
            f"{prefix}/tmp",
            f"{shlex.quote(REMOTE_USERLAND_HOME)}/.config",
            f"{shlex.quote(REMOTE_USERLAND_HOME)}/.local/share",
            f"{shlex.quote(REMOTE_USERLAND_HOME)}/.local/state",
        ]
    )


def userland_fetch_ref(output_override: Path | None) -> None:
    fetch_reference_bootstrap(output_override.expanduser().resolve() if output_override is not None else None)


def userland_inspect(source_arg: Path | None) -> None:
    source = archive_from_args(source_arg)
    with tempfile.TemporaryDirectory(prefix="zide-userland-inspect-") as work_name:
        work_dir = Path(work_name)
        prefix_root, format_name = extract_prefix_root(source, work_dir)
        inspection = inspect_prefix_root(prefix_root, source, format_name)
        print_inspection(inspection)
        if inspection.hardcoded_termux_hits:
            print(
                "note=upstream bootstrap still contains com.termux-prefixed binaries; "
                "bash has been validated manually under dev.zide.terminal, but apt still "
                "needs relocation config or a cleaner artifact",
                flush=True,
            )


def userland_stage(source_arg: Path | None) -> None:
    source = archive_from_args(source_arg)
    adb = adb_path(sdk_root())
    with tempfile.TemporaryDirectory(prefix="zide-userland-stage-") as work_name:
        work_dir = Path(work_name)
        prefix_root, format_name = extract_prefix_root(source, work_dir)
        inspection = inspect_prefix_root(prefix_root, source, format_name)
        print_inspection(inspection)
        if not inspection.has_bash:
            die("bootstrap artifact does not contain bin/bash")
        stage_prepared_userland(adb, prefix_root, inspection, work_dir)


def userland_stage_packages(source_arg: Path | None, packages: list[str]) -> None:
    source = archive_from_args(source_arg)
    adb = adb_path(sdk_root())
    package_closure = resolve_termux_package_closure(packages)
    print("package_closure=" + ",".join(package.name for package in package_closure), flush=True)
    with tempfile.TemporaryDirectory(prefix="zide-userland-stage-packages-") as work_name:
        work_dir = Path(work_name)
        prefix_root, format_name = extract_prefix_root(source, work_dir)
        base_inspection = inspect_prefix_root(prefix_root, source, format_name)
        print_inspection(base_inspection)
        if not base_inspection.has_bash:
            die("bootstrap artifact does not contain bin/bash")

        extracted_files = 0
        for package in package_closure:
            package_archive = download_termux_package(package)
            count = extract_package_usr_payload(package_archive, prefix_root)
            extracted_files += count
            print(f"merged_package={package.name} version={package.version} files={count}", flush=True)

        inspection = inspect_prefix_root(prefix_root, source, f"{format_name}+packages")
        print(f"merged_package_count={len(package_closure)}", flush=True)
        print(f"merged_package_files={extracted_files}", flush=True)
        stage_prepared_userland(adb, prefix_root, inspection, work_dir)


def read_userland_manifest(source: str) -> tuple[dict[str, object], str]:
    if is_url(source):
        payload = read_url(source, timeout=120)
        return json.loads(payload.decode("utf-8")), source

    path = Path(source).expanduser().resolve()
    if not path.is_file():
        die(f"userland artifact manifest does not exist: {path}")
    return json.loads(path.read_text(encoding="utf-8")), str(path)


def manifest_artifact_url(manifest_source: str, artifact_url: str) -> str:
    if is_url(artifact_url):
        return artifact_url
    if is_url(manifest_source):
        return urllib.parse.urljoin(manifest_source, artifact_url)
    return str((Path(manifest_source).parent / artifact_url).resolve())


def android_prefix_artifact_from_manifest(manifest: dict[str, object]) -> UserlandArtifact:
    if manifest.get("schema_version") != 1:
        die("unsupported userland artifact manifest schema_version")
    if manifest.get("project") != "zide-mobile-pm":
        die("userland artifact manifest is not from zide-mobile-pm")
    if manifest.get("platform") != "android":
        die("userland artifact manifest platform is not android")

    raw_artifacts = manifest.get("artifacts")
    if not isinstance(raw_artifacts, list):
        die("userland artifact manifest missing artifacts")
    candidates = [artifact for artifact in raw_artifacts if isinstance(artifact, dict) and artifact.get("kind") == "android-prefix-archive"]
    if len(candidates) != 1:
        die(f"userland artifact manifest must contain exactly one android-prefix-archive, found {len(candidates)}")
    artifact = candidates[0]
    metadata = artifact.get("metadata")
    if not isinstance(metadata, dict):
        die("android-prefix-archive missing metadata")

    package_name = metadata.get("package_name")
    prefix = metadata.get("prefix")
    archive_root = metadata.get("archive_root")
    provider = metadata.get("provider")
    hardcoded_policy = metadata.get("hardcoded_termux_policy")
    runtime_support_links = parse_runtime_support_links(metadata.get("runtime_support_links"))
    if package_name != PACKAGE_NAME:
        die(f"userland artifact package_name mismatch: {package_name!r}")
    if prefix != REMOTE_USERLAND_PREFIX:
        die(f"userland artifact prefix mismatch: {prefix!r}")
    if archive_root != "usr":
        die(f"userland artifact archive_root must be usr, got {archive_root!r}")
    if not isinstance(provider, str) or not provider:
        die("userland artifact missing provider metadata")

    name = artifact.get("name")
    version = artifact.get("version")
    url = artifact.get("url")
    sha256 = artifact.get("sha256")
    size = artifact.get("size")
    if not all(isinstance(value, str) and value for value in (name, version, url, sha256)):
        die("android-prefix-archive missing name/version/url/sha256")
    if not isinstance(size, int):
        die("android-prefix-archive size must be an integer")
    if not isinstance(hardcoded_policy, str):
        hardcoded_policy = "unknown"

    return UserlandArtifact(
        name=name,
        version=version,
        url=url,
        sha256=sha256,
        size=size,
        archive_root=archive_root,
        provider=provider,
        hardcoded_termux_policy=hardcoded_policy,
        runtime_support_links=runtime_support_links,
    )


def parse_runtime_support_links(raw: object) -> tuple[tuple[str, str], ...]:
    if raw is None or raw == "":
        return ()
    if not isinstance(raw, str):
        die("runtime_support_links metadata must be a string")
    links: list[tuple[str, str]] = []
    for entry in raw.split(","):
        if not entry:
            continue
        source, separator, target = entry.partition("=>")
        if separator != "=>":
            die(f"invalid runtime support link entry: {entry!r}")
        if not source.startswith(REMOTE_APP_PACKAGE_DIR + "/") or not target.startswith(REMOTE_APP_PACKAGE_DIR + "/"):
            die(f"runtime support link escapes app package dir: {entry!r}")
        links.append((source, target))
    return tuple(links)


def runtime_support_link_command(artifact: UserlandArtifact) -> str:
    commands: list[str] = []
    for source, target in artifact.runtime_support_links:
        commands.append(
            "mkdir -p {parent} && rm -f {source} && ln -s {target} {source}".format(
                parent=shlex.quote(str(Path(source).parent)),
                source=shlex.quote(source),
                target=shlex.quote(target),
            )
        )
    return " && ".join(commands)


def remote_userland_state(adb: Path) -> InstalledUserlandState:
    stamp_result = run_remote_shell(
        adb,
        f"run-as {PACKAGE_NAME} sh -c "
        + shlex.quote(f"if [ -f {REMOTE_USERLAND_STAMP} ]; then cat {REMOTE_USERLAND_STAMP}; fi"),
        capture_output=True,
        check=False,
    )
    shell_result = run_remote_shell(
        adb,
        f"run-as {PACKAGE_NAME} sh -c "
        + shlex.quote(
            f"if [ -f {REMOTE_USERLAND_PREFIX}/bin/bash ]; then echo true; else echo false; fi"
        ),
        capture_output=True,
        check=False,
    )
    shell_exists = shell_result.stdout.strip() == "true"
    stamp_text = stamp_result.stdout.strip()
    if not stamp_text:
        return InstalledUserlandState(
            installed=False,
            format_name="",
            artifact="",
            version="",
            provider="",
            shell_exists=shell_exists,
            launch_ready=False,
        )
    try:
        stamp = json.loads(stamp_text)
    except json.JSONDecodeError:
        return InstalledUserlandState(
            installed=True,
            format_name="invalid-stamp",
            artifact="",
            version="",
            provider="",
            shell_exists=shell_exists,
            launch_ready=False,
        )
    has_bash = bool(stamp.get("has_bash", False))
    return InstalledUserlandState(
        installed=True,
        format_name=str(stamp.get("format", "")),
        artifact=str(stamp.get("artifact", "")),
        version=str(stamp.get("version", "")),
        provider=str(stamp.get("provider", "")),
        shell_exists=shell_exists,
        launch_ready=has_bash and shell_exists,
    )


def fetch_userland_artifact(manifest_source: str, artifact: UserlandArtifact) -> Path:
    url = manifest_artifact_url(manifest_source, artifact.url)
    cache_name = f"{artifact.name}-{artifact.version}-{artifact.sha256[:12]}.tar.gz"
    target = USERLAND_ARTIFACT_CACHE_DIR / cache_name
    target.parent.mkdir(parents=True, exist_ok=True)
    if verify_file_size_and_sha256(target, size=artifact.size, sha256=artifact.sha256):
        print(f"reused {target}", flush=True)
        return target

    if is_url(url):
        print(f"download {url}", flush=True)
        with urllib.request.urlopen(url_request(url), timeout=300) as response, target.open("wb") as out_file:
            shutil.copyfileobj(response, out_file)
    else:
        source = Path(url)
        if not source.is_file():
            die(f"userland artifact archive does not exist: {source}")
        shutil.copy2(source, target)

    if not verify_file_size_and_sha256(target, size=artifact.size, sha256=artifact.sha256):
        if target.is_file():
            target.unlink()
        die(f"userland artifact verification failed: {target}")
    return target


def userland_state() -> None:
    adb = adb_path(sdk_root())
    state = remote_userland_state(adb)
    print(f"installed={state.installed}", flush=True)
    print(f"format={state.format_name}", flush=True)
    print(f"artifact={state.artifact}", flush=True)
    print(f"version={state.version}", flush=True)
    print(f"provider={state.provider}", flush=True)
    print(f"shell_exists={state.shell_exists}", flush=True)
    print(f"launch_ready={state.launch_ready}", flush=True)


def userland_stage_artifact(manifest_source: str, *, force: bool = False) -> None:
    manifest, resolved_manifest_source = read_userland_manifest(manifest_source)
    artifact = android_prefix_artifact_from_manifest(manifest)
    archive = fetch_userland_artifact(resolved_manifest_source, artifact)
    adb = adb_path(sdk_root())
    installed_state = remote_userland_state(adb)

    print(f"installed_before={installed_state.installed}", flush=True)
    print(f"installed_format={installed_state.format_name}", flush=True)
    print(f"installed_artifact={installed_state.artifact}", flush=True)
    print(f"installed_version={installed_state.version}", flush=True)
    print(f"installed_provider={installed_state.provider}", flush=True)
    print(f"installed_launch_ready={installed_state.launch_ready}", flush=True)

    already_current = (
        installed_state.launch_ready
        and installed_state.format_name == "android-prefix-artifact"
        and installed_state.artifact == artifact.name
        and installed_state.version == artifact.version
        and installed_state.provider == artifact.provider
    )
    if already_current and not force:
        print("artifact_stage=already-current", flush=True)
        print(f"staged_prefix={REMOTE_USERLAND_PREFIX}", flush=True)
        print(f"artifact={artifact.name}", flush=True)
        print(f"artifact_version={artifact.version}", flush=True)
        print(f"artifact_provider={artifact.provider}", flush=True)
        print(f"artifact_hardcoded_termux_policy={artifact.hardcoded_termux_policy}", flush=True)
        return

    with tempfile.TemporaryDirectory(prefix="zide-userland-artifact-") as work_name:
        work_dir = Path(work_name)
        artifact_root = extract_userland_artifact_archive(archive, work_dir)
        stage_tar = work_dir / "userland-artifact-stage.tar"
        build_userland_artifact_stage_tar(artifact_root, artifact, resolved_manifest_source, stage_tar)
        install_userland_stage_tar(adb, stage_tar, artifact)

    print("artifact_stage=restaged", flush=True)
    print(f"staged_prefix={REMOTE_USERLAND_PREFIX}", flush=True)
    print(f"artifact={artifact.name}", flush=True)
    print(f"artifact_version={artifact.version}", flush=True)
    print(f"artifact_provider={artifact.provider}", flush=True)
    print(f"artifact_hardcoded_termux_policy={artifact.hardcoded_termux_policy}", flush=True)


def stage_prepared_userland(
    adb: Path,
    prefix_root: Path,
    inspection: BootstrapInspection,
    work_dir: Path,
) -> None:
    text_rewrites = relocate_text_prefixes(prefix_root)
    symlink_rewrites = relocate_symlink_prefixes(prefix_root)
    binary_path_rewrites = patch_compiled_userland_paths(prefix_root)

    stage_tar = work_dir / "userland-stage.tar"
    build_userland_stage_tar(prefix_root, inspection, stage_tar)
    install_userland_stage_tar(adb, stage_tar, None)
    print(f"staged_prefix={REMOTE_USERLAND_PREFIX}", flush=True)
    print(f"text_prefix_rewrites={text_rewrites}", flush=True)
    print(f"symlink_prefix_rewrites={symlink_rewrites}", flush=True)
    print(f"binary_path_rewrites={binary_path_rewrites}", flush=True)
    if inspection.hardcoded_termux_hits:
        print(
            "note=staged upstream bootstrap contains com.termux-prefixed binaries; "
            "plain-text shebang/config paths were rewritten, but binary relocation "
            "and package-manager cleanup are still incomplete",
            flush=True,
        )


def install_userland_stage_tar(adb: Path, stage_tar: Path, artifact: UserlandArtifact | None) -> None:
    run([*adb_target_args(adb), "push", stage_tar, REMOTE_STAGE_TAR])
    run_remote_shell(
        adb,
        " ".join(
            [
                f"run-as {PACKAGE_NAME} sh -c",
                shlex.quote(
                    "rm -rf {prefix} {stamp} && "
                    "mkdir -p {files} {home} {tmp} && "
                    "cd {files} && "
                    "toybox tar -xf {remote} && "
                    "rm -f {apt_conf_parts} {dpkg_etc} {dpkg_db} && "
                    "ln -s {prefix}/etc/apt/apt.conf.d {apt_conf_parts} && "
                    "ln -s {prefix}/etc/dpkg {dpkg_etc} && "
                    "ln -s {prefix}/var/lib/dpkg {dpkg_db} && "
                    "{runtime_links}"
                    "{runtime_link_separator}"
                    "chmod 700 {home} {tmp}"
                ).format(
                    prefix=REMOTE_USERLAND_PREFIX,
                    stamp=REMOTE_USERLAND_STAMP,
                    files=REMOTE_APP_FILES_DIR,
                    home=REMOTE_USERLAND_HOME,
                    tmp=REMOTE_USERLAND_TMP,
                    apt_conf_parts=REMOTE_USERLAND_APT_CONF_PARTS,
                    dpkg_etc=REMOTE_USERLAND_DPKG_ETC,
                    dpkg_db=REMOTE_USERLAND_DPKG_DB,
                    runtime_links=runtime_support_link_command(artifact) if artifact else "",
                    runtime_link_separator=" && " if artifact and artifact.runtime_support_links else "",
                    remote=REMOTE_STAGE_TAR,
                ),
            ]
        ),
    )
    run_remote_shell(adb, f"rm -f {shlex.quote(REMOTE_STAGE_TAR)}")


def userland_bash_version() -> None:
    adb = adb_path(sdk_root())
    result = run_remote_shell(
        adb,
        build_userland_remote_command(f"{shlex.quote(REMOTE_USERLAND_PREFIX + '/bin/bash')} --version | head -20"),
        capture_output=True,
    )
    print(result.stdout, end="")


def userland_smoke_baseline() -> None:
    adb = adb_path(sdk_root())
    bash = shlex.quote(REMOTE_USERLAND_PREFIX + "/bin/bash")
    command = (
        f"{bash} --noprofile --norc -lc "
        + shlex.quote(
            "set -e; "
            "bash --version | head -1; "
            "git --version; "
            "rg --version | head -1; "
            "nvim --headless +qall; "
            "htop --version | head -1; "
            "gotop --version | head -1; "
            "zide-pm doctor; "
            "zide-pm list-available"
        )
    )
    result = run_remote_shell(
        adb,
        build_userland_remote_command(command),
        capture_output=True,
    )
    print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)


def userland_nvim_manual_check() -> None:
    print(
        """AN-A1 Neovim manual check

In-app commands:
  1. nvim test.txt
  2. i
  3. type a short line
  4. <Esc>
  5. :wq

What to verify:
  - alternate screen opens and clears cleanly
  - text remains legible on the GLES terminal surface
  - IME input reaches Neovim insert mode correctly
  - Esc leaves insert mode
  - arrow keys / assist-bar navigation move as expected
  - Ctrl-based actions needed for a tiny edit are usable enough
  - IME open/close and rotation do not corrupt the visible viewport
  - product scroll behavior does not snap/fight during normal editor use
  - pinch zoom is usable enough for testing, even if not yet Termux-quality

Record as concrete blockers only:
  - rendering corruption
  - broken alternate-screen behavior
  - missing editor input/navigation needed for the flow above
  - viewport/IME behavior that makes the edit flow fail
""",
        end="",
    )


def userland_apt_update() -> None:
    adb = adb_path(sdk_root())
    command = (
        f"{userland_package_manager_prelude()} && "
        f"{shlex.quote(REMOTE_USERLAND_PREFIX + '/bin/apt-get')} {userland_apt_options()} update 2>&1 | head -120"
    )
    result = run_remote_shell(
        adb,
        build_userland_remote_command(command),
        capture_output=True,
        check=False,
    )
    print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)


def userland_apt_install(packages: list[str]) -> None:
    if not packages:
        die("userland-apt-install requires at least one package name")
    adb = adb_path(sdk_root())
    package_args = " ".join(shlex.quote(package) for package in packages)
    log_path = f"{REMOTE_APP_FILES_DIR}/zide_userland_apt_install.log"
    command = (
        f"{userland_package_manager_prelude()} && "
        f"{shlex.quote(REMOTE_USERLAND_PREFIX + '/bin/apt-get')} "
        f"{userland_apt_options()} install -y {package_args} > {shlex.quote(log_path)} 2>&1; "
        "status=$?; "
        f"tail -200 {shlex.quote(log_path)}; "
        "exit $status"
    )
    result = run_remote_shell(
        adb,
        build_userland_remote_command(command),
        capture_output=True,
        check=False,
    )
    print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)
    if result.returncode != 0:
        raise SystemExit(result.returncode)


def native() -> None:
    sdk = sdk_root(require_ndk=True)
    sysroot = android_sysroot(sdk)
    out_dir = BRIDGE_DIR / "app" / "src" / "main" / "jniLibs" / "arm64-v8a"
    out_lib = out_dir / "libzide_android_bridge.so"
    built_lib = ROOT / "zig-out" / "lib" / "libzide_android_bridge.so"
    out_dir.mkdir(parents=True, exist_ok=True)

    run(
        [
            zig_path(),
            "build",
            "android-terminal-host-bridge",
            "-Dtarget=aarch64-linux-android",
            "-Dmode=terminal",
            "-Doptimize=" + zig_optimize_flag(),
            "--sysroot",
            sysroot,
        ]
    )
    if not built_lib.is_file():
        die(f"missing built Android bridge library: {built_lib}")
    shutil.copy2(built_lib, out_lib)
    print(f"built {out_lib}", flush=True)


def apk() -> None:
    sdk_root()
    variant = gradle_variant_name()
    task = f":app:assemble{variant.capitalize()}"
    run([gradle_wrapper(), task], cwd=BRIDGE_DIR)


def clean() -> None:
    sdk_root()
    run([gradle_wrapper(), "clean"], cwd=BRIDGE_DIR)


def install() -> None:
    adb = adb_path(sdk_root())
    run([*adb_target_args(adb), "install", "-r", apk_path()])


def launch() -> None:
    adb = adb_path(sdk_root())
    run([*adb_target_args(adb), "shell", "am", "start", "-n", ACTIVITY_NAME])


def reinstall() -> None:
    adb = adb_path(sdk_root())
    uninstall_legacy_packages(adb)
    subprocess.run([str(adb), "uninstall", PACKAGE_NAME], check=False)
    install()
    launch()


def deploy() -> None:
    native()
    apk()
    uninstall_legacy_packages(adb_path(sdk_root()))
    install()
    launch()


def logcat() -> None:
    adb = adb_path(sdk_root())
    run([*adb_target_args(adb), "logcat", "-d", "-s", "ZideAndroidTerminal:I", "AndroidRuntime:E", "*:S"])


def uninstall_legacy_packages(adb: Path) -> None:
    adb_args = adb_target_args(adb)
    for package_name in LEGACY_PACKAGE_NAMES:
        listing = subprocess.run(
            [*adb_args, "shell", "pm", "list", "packages", package_name],
            check=False,
            capture_output=True,
            text=True,
        )
        if f"package:{package_name}" in listing.stdout:
            subprocess.run([*adb_args, "uninstall", package_name], check=False)


def doctor() -> None:
    sdk = sdk_root()
    adb = adb_path(sdk)
    wrapper = gradle_wrapper()
    ndk_sdk = sdk_root(require_ndk=True)
    print(f"ROOT={ROOT}", flush=True)
    print(f"BRIDGE_DIR={BRIDGE_DIR}", flush=True)
    print(f"ANDROID_TOOL_SDK_ROOT={sdk}", flush=True)
    print(f"ADB={adb}", flush=True)
    print(f"GRADLEW={wrapper}", flush=True)
    print(f"ANDROID_VARIANT={current_variant()}", flush=True)
    print(f"APK_PATH={apk_path()}", flush=True)
    print(f"ZIG_OPTIMIZE={zig_optimize_flag()}", flush=True)
    print(f"NDK_VERSION={NDK_VERSION}", flush=True)
    print(f"NDK_SDK_ROOT={ndk_sdk}", flush=True)
    print(f"ANDROID_CLANG={android_clang(ndk_sdk)}", flush=True)
    print(f"ANDROID_SYSROOT={android_sysroot(ndk_sdk)}", flush=True)
    run([adb, "version"])


def main() -> None:
    release_descriptor = userland_release_descriptor()
    command_names = list(COMMAND_HELP.keys())
    commands_help = "\n".join(f"  {name:<18} {COMMAND_HELP[name]}" for name in command_names)
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=f"commands:\n{commands_help}",
    )
    parser.add_argument(
        "command",
        nargs="?",
        default="help",
        choices=command_names,
        metavar="{" + ",".join(command_names) + "}",
        help="Operation to execute (default: help).",
    )
    parser.add_argument(
        "packages",
        nargs="*",
        help="Package names for userland-stage-packages or userland-apt-install.",
    )
    parser.add_argument(
        "--archive",
        type=Path,
        help="Bootstrap archive/tree for userland-inspect or userland-stage. Defaults to the cached latest upstream reference.",
    )
    parser.add_argument(
        "--manifest",
        default=release_descriptor["manifest_url"],
        help=(
            "Published Android prefix manifest URL/path for userland-stage-artifact. "
            "Defaults to the checked-in Android release descriptor under android/terminal-host."
        ),
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Force restaging for userland-stage-artifact even if the same artifact is already staged.",
    )
    parser.add_argument(
        "--variant",
        default="debug",
        choices=("debug", "profile", "release"),
        help="Android app build/deploy variant and matching Zig optimize mode (default: debug).",
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="Download destination for userland-fetch-ref.",
    )
    args = parser.parse_args()
    global ACTIVE_VARIANT
    ACTIVE_VARIANT = args.variant

    commands = {
        "native": native,
        "apk": apk,
        "install": install,
        "launch": launch,
        "deploy": deploy,
        "clean": clean,
        "reinstall": reinstall,
        "logcat": logcat,
        "doctor": doctor,
        "userland-fetch-ref": lambda: userland_fetch_ref(args.output),
        "userland-inspect": lambda: userland_inspect(args.archive),
        "userland-stage": lambda: userland_stage(args.archive),
        "userland-stage-artifact": lambda: userland_stage_artifact(args.manifest, force=args.force),
        "userland-state": userland_state,
        "userland-stage-packages": lambda: userland_stage_packages(args.archive, args.packages),
        "userland-bash-version": userland_bash_version,
        "userland-smoke-baseline": userland_smoke_baseline,
        "userland-nvim-manual-check": userland_nvim_manual_check,
        "userland-apt-update": userland_apt_update,
        "userland-apt-install": lambda: userland_apt_install(args.packages),
        "help": parser.print_help,
    }
    commands[args.command]()


if __name__ == "__main__":
    main()

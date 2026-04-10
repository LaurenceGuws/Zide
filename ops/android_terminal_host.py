#!/usr/bin/env python3
"""Build, deploy, and inspect the Zide Android terminal host."""

from __future__ import annotations

import argparse
import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path
from typing import NoReturn


ROOT = Path(__file__).resolve().parents[1]
BRIDGE_DIR = ROOT / "android" / "terminal-host"
APK_PATH = BRIDGE_DIR / "app" / "build" / "outputs" / "apk" / "debug" / "app-debug.apk"
PACKAGE_NAME = "dev.zide.terminal"
ACTIVITY_NAME = f"{PACKAGE_NAME}/.ZideTerminalActivity"
LEGACY_PACKAGE_NAMES = ("dev.zide.androidbootstrap",)
NDK_VERSION = os.environ.get("ZIDE_ANDROID_NDK_VERSION", "27.1.12297006")
ANDROID_API = "29"


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


def zig_path() -> str:
    zig = shutil.which("zig")
    if zig is None:
        die("missing zig on PATH")
    return zig


def native() -> None:
    sdk = sdk_root(require_ndk=True)
    clang = android_clang(sdk)
    toolchain = clang.parents[1]
    sysroot = toolchain / "sysroot"
    obj_path = BRIDGE_DIR / "app" / "build" / "native" / "android_bridge_exports.o"
    stb_obj_path = BRIDGE_DIR / "app" / "build" / "native" / "stb_image.o"
    out_dir = BRIDGE_DIR / "app" / "src" / "main" / "jniLibs" / "arm64-v8a"
    out_lib = out_dir / "libzide_android_bridge.so"

    obj_path.parent.mkdir(parents=True, exist_ok=True)
    out_dir.mkdir(parents=True, exist_ok=True)

    run(
        [
            zig_path(),
            "build-obj",
            "-target",
            f"aarch64-linux-android.{ANDROID_API}",
            "-lc",
            "--sysroot",
            sysroot,
            "-isystem",
            sysroot / "usr" / "include",
            "-isystem",
            sysroot / "usr" / "include" / "aarch64-linux-android",
            "-I",
            ROOT / "vendor",
            ROOT / "src" / "android_bridge_exports.zig",
            f"-femit-bin={obj_path}",
        ]
    )
    run(
        [
            clang,
            f"--sysroot={sysroot}",
            "-fPIC",
            "-I",
            ROOT / "vendor",
            "-c",
            ROOT / "src" / "c" / "stb_image.c",
            "-o",
            stb_obj_path,
        ]
    )
    run(
        [
            clang,
            "-shared",
            "-Wl,--no-undefined",
            obj_path,
            stb_obj_path,
            "-landroid",
            "-lEGL",
            "-lGLESv2",
            "-lm",
            "-o",
            out_lib,
        ]
    )
    print(f"built {out_lib}", flush=True)


def apk() -> None:
    sdk_root()
    run([gradle_wrapper(), ":app:assembleDebug"], cwd=BRIDGE_DIR)


def clean() -> None:
    sdk_root()
    run([gradle_wrapper(), "clean"], cwd=BRIDGE_DIR)


def install() -> None:
    adb = adb_path(sdk_root())
    run([adb, "install", "-r", APK_PATH])


def launch() -> None:
    adb = adb_path(sdk_root())
    run([adb, "shell", "am", "start", "-n", ACTIVITY_NAME])


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
    run([adb, "logcat", "-d", "-s", "ZideAndroidTerminal:I", "AndroidRuntime:E", "*:S"])


def uninstall_legacy_packages(adb: Path) -> None:
    for package_name in LEGACY_PACKAGE_NAMES:
        listing = subprocess.run(
            [str(adb), "shell", "pm", "list", "packages", package_name],
            check=False,
            capture_output=True,
            text=True,
        )
        if f"package:{package_name}" in listing.stdout:
            subprocess.run([str(adb), "uninstall", package_name], check=False)


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
    print(f"NDK_VERSION={NDK_VERSION}", flush=True)
    print(f"NDK_SDK_ROOT={ndk_sdk}", flush=True)
    print(f"ANDROID_CLANG={android_clang(ndk_sdk)}", flush=True)
    run([adb, "version"])


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "command",
        nargs="?",
        default="help",
        choices=[
            "native",
            "apk",
            "install",
            "launch",
            "deploy",
            "clean",
            "reinstall",
            "logcat",
            "doctor",
            "help",
        ],
    )
    args = parser.parse_args()

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
        "help": parser.print_help,
    }
    commands[args.command]()


if __name__ == "__main__":
    main()

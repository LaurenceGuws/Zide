#!/usr/bin/env python3
import os
import platform
import subprocess
import sys
from pathlib import Path


def host_tag() -> str:
    system = platform.system().lower()
    machine = platform.machine().lower()
    if system == "windows":
        return "windows-x86_64"
    if system == "linux":
        return "linux-aarch64" if machine in ("aarch64", "arm64") else "linux-x86_64"
    if system == "darwin":
        return "darwin-arm64" if machine in ("arm64", "aarch64") else "darwin-x86_64"
    raise SystemExit(f"Unsupported host platform for Android NDK lookup: {system}/{machine}")


def resolve_android_cc(clang_bin: Path, arch: str, api: str) -> Path:
    base = {
        "aarch64": f"aarch64-linux-android{api}-clang",
        "x86_64": f"x86_64-linux-android{api}-clang",
        "armv7": f"armv7a-linux-androideabi{api}-clang",
    }.get(arch)
    if base is None:
        raise SystemExit(f"Unsupported Android arch: {arch}")
    candidates = [clang_bin / f"{base}.cmd", clang_bin / f"{base}.exe", clang_bin / base]
    for candidate in candidates:
        if candidate.exists():
            return candidate
    raise SystemExit(f"Android clang not found for {arch}: expected one of {', '.join(str(c) for c in candidates)}")


def find_ndk_root() -> Path | None:
    env = os.environ
    candidates: list[Path] = []
    if env.get("ANDROID_NDK_ROOT"):
        candidates.append(Path(env["ANDROID_NDK_ROOT"]))
    if env.get("ANDROID_SDK_ROOT"):
        candidates.append(Path(env["ANDROID_SDK_ROOT"]) / "ndk")
    if env.get("ANDROID_HOME"):
        candidates.append(Path(env["ANDROID_HOME"]) / "ndk")
    home = Path.home()
    candidates.append(home / ".local" / "android-sdk" / "ndk")
    candidates.append(home / "Android" / "Sdk" / "ndk")

    for candidate in candidates:
        if not candidate.exists():
            continue
        if (candidate / "toolchains").is_dir():
            return candidate
        children = sorted((p for p in candidate.iterdir() if p.is_dir()), key=lambda p: p.name)
        if children:
            newest = children[-1]
            if (newest / "toolchains").is_dir():
                return newest
    return None


def main() -> int:
    if len(sys.argv) < 6:
        raise SystemExit("Usage: build_pack.py <language> <version> <os> <arch> <repo_path> [location] [files...]")

    lang, version, os_name, arch, repo_path = sys.argv[1:6]
    location = sys.argv[6] if len(sys.argv) >= 7 else ""
    files = sys.argv[7:] if len(sys.argv) >= 8 else []

    root = Path(__file__).resolve().parents[1]
    work = root / "work"
    zig_cache = Path(os.environ.get("ZIG_GLOBAL_CACHE_DIR", str(work / "zig-cache")))
    os.environ["ZIG_GLOBAL_CACHE_DIR"] = str(zig_cache)

    ext_map = {
        "linux": "so",
        "android": "so",
        "macos": "dylib",
        "windows": "dll",
    }
    target_map = {
        ("linux", "x86_64"): "x86_64-linux-gnu",
        ("linux", "aarch64"): "aarch64-linux-gnu",
        ("android", "x86_64"): "x86_64-linux-android",
        ("android", "aarch64"): "aarch64-linux-android",
        ("android", "armv7"): "arm-linux-androideabi",
        ("macos", "x86_64"): "x86_64-macos",
        ("macos", "aarch64"): "aarch64-macos",
        ("windows", "x86_64"): "x86_64-windows-gnu",
    }

    if os_name not in ext_map:
        raise SystemExit(f"Unsupported OS: {os_name}")
    target = target_map.get((os_name, arch))
    if target is None:
        raise SystemExit(f"Unsupported target: {os_name}/{arch}")

    out_dir = root / "dist" / lang / version
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{lang}_{version}_{os_name}_{arch}.{ext_map[os_name]}"

    base_dir = Path(repo_path)
    if location:
        base_dir = base_dir / location

    sources = [work / "tree-sitter" / "lib" / "src" / "lib.c"]
    if files:
        sources.extend(base_dir / file for file in files)
    else:
        sources.append(base_dir / "src" / "parser.c")
        scanner_c = base_dir / "src" / "scanner.c"
        if scanner_c.exists():
            sources.append(scanner_c)

    cflags = ["-std=c11"]
    if os_name != "windows":
        cflags.extend(["-D_POSIX_C_SOURCE=200809L", "-D_DEFAULT_SOURCE", "-D_GNU_SOURCE"])

    include_args = [
        "-I",
        str(work / "tree-sitter" / "lib" / "include"),
        "-I",
        str(work / "tree-sitter" / "lib" / "src"),
        "-I",
        str(base_dir / "src"),
    ]

    if os_name == "android":
        android_api = os.environ.get("ANDROID_API", "29")
        ndk_root = find_ndk_root()
        if ndk_root is None:
            raise SystemExit("ANDROID_NDK_ROOT not set and no NDK found under ANDROID_HOME/ndk")
        clang_bin = ndk_root / "toolchains" / "llvm" / "prebuilt" / host_tag() / "bin"
        android_cc = resolve_android_cc(clang_bin, arch, android_api)
        cmd = [
            str(android_cc),
            "-shared",
            "-fPIC",
            "-O2",
            "-o",
            str(out_path),
            *include_args,
            *cflags,
            *(str(source) for source in sources),
        ]
    else:
        cmd = [
            "zig",
            "build-lib",
            "-dynamic",
            "-OReleaseFast",
            "-target",
            target,
            f"-femit-bin={out_path}",
            *include_args,
            "-lc",
            "-cflags",
            *cflags,
            "--",
            *(str(source) for source in sources),
        ]

    subprocess.check_call(cmd)
    print(f"Built {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

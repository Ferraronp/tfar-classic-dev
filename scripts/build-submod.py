#!/usr/bin/env python3
"""Build only TFAR Classic Fixes; no Arma install, LFS or TS sources needed."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import zipfile

REPO = Path(__file__).resolve().parent.parent
SOURCE = REPO / "submod"
STAGE = REPO / "dist/submod-stage"
OUTPUT = REPO / "dist/submod"
PREFIX = "tfar_classic_fixes"
MOD_NAME = "@tfar_classic_fixes"
FUNCTIONS = {
    "activeSwRadio", "currentUnit", "getRadioOwnerId", "haveSWRadio",
    "onCurrentUnitChanged", "onSwDialogOpen", "processPlayerPositions",
    "processRespawn", "radioReplaceProcess", "radioToRequestCount",
    "radiosList", "requestRadios", "sendFrequencyInfo",
}


def check_delimiters(path: Path) -> None:
    """Catch truncated SQF/config strings, comments and mismatched delimiters."""
    text = path.read_text(encoding="utf-8-sig")
    stack = []
    pairs = {"}": "{", "]": "[", ")": "("}
    quote = comment = None
    line = 1
    index = 0
    while index < len(text):
        char = text[index]
        following = text[index:index + 2]
        if char == "\n":
            line += 1
            if comment == "line":
                comment = None
        if comment:
            if comment == "block" and following == "*/":
                comment = None
                index += 2
            else:
                index += 1
            continue
        if quote:
            if char == quote:
                if index + 1 < len(text) and text[index + 1] == quote:
                    index += 2
                    continue
                quote = None
            index += 1
            continue
        if following in ("//", "/*"):
            comment = "line" if following == "//" else "block"
            index += 2
            continue
        if char in ("\"", "'"):
            quote = char
        elif char in "{[(":
            stack.append((char, line))
        elif char in "}])":
            if not stack or stack[-1][0] != pairs[char]:
                raise ValueError(f"{path}:{line}: unmatched {char}")
            stack.pop()
        index += 1
    if quote or comment == "block" or stack:
        raise ValueError(f"{path}: unclosed string, comment or delimiter {stack[-3:]}")


def validate_sources() -> None:
    addon = SOURCE / "addons/fixes"
    config = (addon / "config.cpp").read_text(encoding="utf-8")
    if (addon / "$PBOPREFIX$").read_text(encoding="utf-8").strip() != PREFIX:
        raise ValueError("Unexpected PBO prefix")
    if not re.search(r'requiredAddons\[\]\s*=\s*\{[^}]*"task_force_radio"', config):
        raise ValueError("Missing dependency on original TFAR")
    for function in FUNCTIONS:
        if f"\\{PREFIX}\\functions\\fn_{function}.sqf" not in config:
            raise ValueError(f"Missing function override: {function}")
    files = {p.stem[3:] for p in (addon / "functions").glob("fn_*.sqf")}
    expected = FUNCTIONS | {"init"}
    if files != expected:
        raise ValueError(f"Unexpected or missing function files: {files ^ expected}")
    for path in addon.rglob("*"):
        if not path.is_file():
            continue
        if path.suffix.lower() not in (".sqf", ".cpp", ".toml") and path.name != "$PBOPREFIX$":
            raise ValueError(f"Unexpected addon payload: {path}")
        if path.suffix.lower() in (".sqf", ".cpp"):
            check_delimiters(path)
            if re.search(r"^\s*#include", path.read_text(encoding="utf-8"), re.MULTILINE):
                raise ValueError(f"Unexpected dependency on source includes: {path}")
    for name in ("README.md", "LICENSE.md", "AUTHORS.md", "mod.cpp"):
        if not (SOURCE / name).is_file():
            raise ValueError(f"Missing release file: {name}")
    print(f"Validated {len(files)} SQF functions and original-TFAR dependency")


def pbo_contents(path: Path) -> tuple[dict[str, str], dict[str, bytes]]:
    """Read stored PBO entries to verify the release, not just source files."""
    data = path.read_bytes()
    offset = 0

    def cstring() -> str:
        nonlocal offset
        end = data.index(b"\0", offset)
        value = data[offset:end].decode("utf-8")
        offset = end + 1
        return value

    properties = {}
    entries = []
    while True:
        name = cstring()
        method, _, _, _, size = struct.unpack_from("<5I", data, offset)
        offset += 20
        if not name:
            if method:
                while True:
                    key = cstring()
                    if not key:
                        break
                    properties[key] = cstring()
                continue
            break
        if method:
            raise ValueError(f"Compressed PBO entry cannot be verified: {name}")
        entries.append((name.replace("\\", "/"), size))
    contents = {}
    for name, size in entries:
        if offset + size > len(data):
            raise ValueError(f"Truncated PBO entry: {name}")
        if name in contents:
            raise ValueError(f"Duplicate PBO entry: {name}")
        contents[name] = data[offset:offset + size]
        offset += size
    return properties, contents


def build(hemtt: str) -> Path:
    validate_sources()
    binary = shutil.which(hemtt)
    if not binary:
        raise RuntimeError("HEMTT not found; install it from https://hemtt.dev/installation/")
    for directory in (STAGE, OUTPUT):
        if directory.exists():
            shutil.rmtree(directory)
    shutil.copytree(SOURCE, STAGE)
    OUTPUT.mkdir(parents=True)
    parsed_config = STAGE / "config-check.json"
    subprocess.run([
        binary, "utils", "config", "convert",
        str(STAGE / "addons/fixes/config.cpp"), str(parsed_config),
    ], check=True)
    parsed = json.loads(parsed_config.read_text(encoding="utf-8"))
    radio = parsed["CfgFunctions"]["TFAR"]["Radio"]
    if set(radio) != FUNCTIONS:
        raise ValueError("Parsed config changes unexpected TFAR functions or category attributes")
    for name in FUNCTIONS:
        if radio[name]["file"] != f"\\{PREFIX}\\functions\\fn_{name}.sqf":
            raise ValueError(f"Parsed config has incorrect function path: {name}")
    if parsed["CfgFunctions"]["TFARCF"]["Lifecycle"]["init"]["postInit"] != 1:
        raise ValueError("Submod startup function is not registered for postInit")
    log = STAGE / "hemtt-release.log"
    with log.open("w", encoding="utf-8") as stream:
        result = subprocess.run(
            [binary, "release", "--no-bin", "--no-archive"],
            cwd=STAGE, stdout=stream, stderr=subprocess.STDOUT, check=False,
        )
    print("\n".join(log.read_text(encoding="utf-8", errors="replace").splitlines()[-45:]))
    if result.returncode:
        raise RuntimeError(f"HEMTT failed with exit code {result.returncode}; log: {log}")
    release = STAGE / ".hemttout/release"
    pbos = list(release.rglob("*.pbo"))
    keys = list(release.rglob("*.bikey"))
    signatures = list(release.rglob("*.bisign"))
    if len(pbos) != 1 or pbos[0].name != PREFIX + ".pbo":
        raise ValueError(f"Release must contain only {PREFIX}.pbo: {pbos}")
    if len(keys) != 1 or len(signatures) != 1:
        raise ValueError("Expected exactly one public key and PBO signature")
    properties, contents = pbo_contents(pbos[0])
    if properties.get("prefix") != PREFIX:
        raise ValueError(f"Incorrect packed PBO prefix: {properties}")
    required = {"config.cpp"} | {f"functions/fn_{name}.sqf" for name in FUNCTIONS | {"init"}}
    if not required.issubset(contents):
        raise ValueError(f"Missing packed files: {required - contents.keys()}")
    for name in required:
        if contents[name] != (SOURCE / "addons/fixes" / name).read_bytes():
            raise ValueError(f"Packed source differs from checkout: {name}")
    subprocess.run([binary, "utils", "verify", str(pbos[0]), str(keys[0])], check=True)

    mod = OUTPUT / MOD_NAME
    addons = mod / "addons"
    public_keys = mod / "keys"
    addons.mkdir(parents=True)
    public_keys.mkdir()
    for path in (pbos[0], signatures[0]):
        shutil.copy2(path, addons / path.name)
    shutil.copy2(keys[0], public_keys / keys[0].name)
    for name in ("README.md", "LICENSE.md", "AUTHORS.md", "mod.cpp"):
        shutil.copy2(SOURCE / name, mod / name)
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip()
    (mod / "BUILD.json").write_text(json.dumps({
        "version": "1.0.0", "commit": commit, "addon": PREFIX,
        "requires": ["CBA_A3", "TFAR Classic 0.9.12"],
        "teamspeak_plugin_included": False,
    }, indent=2) + "\n", encoding="utf-8")
    archive = OUTPUT / "tfar-classic-fixes.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as packaged:
        for path in sorted(mod.rglob("*")):
            if path.is_file():
                packaged.write(path, path.relative_to(OUTPUT).as_posix())
    hashes = []
    for path in sorted(mod.rglob("*")) + [archive]:
        if path.is_file():
            hashes.append(f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(OUTPUT).as_posix()}")
    (OUTPUT / "SHA256SUMS.txt").write_text("\n".join(hashes) + "\n", encoding="utf-8")
    print(f"Built and verified {archive} ({archive.stat().st_size} bytes), commit {commit}")
    return archive


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--hemtt", default="hemtt")
    parser.add_argument("--check-only", action="store_true", help="Validate sources without HEMTT")
    args = parser.parse_args()
    if args.check_only:
        validate_sources()
    else:
        build(args.hemtt)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"Submod build failed: {error}", file=sys.stderr)
        sys.exit(1)

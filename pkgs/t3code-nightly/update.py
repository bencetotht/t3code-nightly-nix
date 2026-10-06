#!/usr/bin/env python3
"""Pin a complete upstream nightly; Nix verifies these hashes when fetching."""

import argparse
import base64
import json
import os
from pathlib import Path
import re
import tempfile
from urllib.request import Request, urlopen


API = "https://api.github.com/repos/pingdotgg/t3code/releases"
TARGETS = {
    "x86_64-linux": ("amd64", "x64"),
    "aarch64-linux": ("arm64", "arm64"),
}


def fetch(url):
    headers = {"User-Agent": "t3code-nightly-nix-updater"}
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if token and url.startswith("https://api.github.com/"):
        headers["Authorization"] = f"Bearer {token}"
    with urlopen(Request(url, headers=headers), timeout=60) as response:
        return response.read()


def release_sources(release):
    tag = release["tag_name"]
    if release["draft"] or not re.fullmatch(r"v\d+\.\d+\.\d+-nightly\.\d{8}\.\d+", tag):
        return None
    version = tag.removeprefix("v")
    assets = {asset["name"]: asset for asset in release["assets"]}
    names = {
        system: {
            "desktop": f"T3-Code-{version}-{deb_arch}.deb",
            "cli": f"t3-{version}-linux-{cli_arch}.tar.gz",
        }
        for system, (deb_arch, cli_arch) in TARGETS.items()
    }
    required = {name for target in names.values() for name in target.values()}
    if not required.union({"SHA256SUMS"}).issubset(assets):
        return None
    checksums = {}
    for line in fetch(assets["SHA256SUMS"]["browser_download_url"]).decode().splitlines():
        digest, name = line.split(maxsplit=1)
        if not re.fullmatch(r"[0-9a-fA-F]{64}", digest):
            raise ValueError("Invalid upstream SHA256SUMS digest")
        checksums[name.lstrip("*")] = digest
    sources = {}
    for system, target in names.items():
        sources[system] = {}
        for kind, name in target.items():
            api_digest = assets[name].get("digest")
            # SHA256SUMS covers CLI archives; GitHub supplies desktop digests.
            digest = checksums.get(name)
            if digest and api_digest and api_digest != f"sha256:{digest}":
                raise ValueError(f"GitHub and SHA256SUMS disagree for {name}")
            if digest is None:
                if not api_digest or not re.fullmatch(r"sha256:[0-9a-fA-F]{64}", api_digest):
                    raise ValueError(f"No SHA-256 digest available for {name}")
                digest = api_digest.removeprefix("sha256:")
            sources[system][kind] = {
                "url": assets[name]["browser_download_url"],
                "hash": "sha256-" + base64.b64encode(bytes.fromhex(digest)).decode(),
            }
    return {"version": version, "sources": sources}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", help="Pin a specific vX.Y.Z-nightly.YYYYMMDD.N tag")
    parser.add_argument("--output", type=Path, default=Path("pkgs/t3code-nightly/sources.json"))
    args = parser.parse_args()
    if not args.output.parent.is_dir():
        parser.error("Run from the flake root, or supply --output with an existing directory")
    selected = None
    if args.tag:
        selected = release_sources(json.loads(fetch(f"{API}/tags/{args.tag}")))
    else:
        for page in range(1, 11):
            releases = json.loads(fetch(f"{API}?per_page=100&page={page}"))
            # GitHub lists by creation time; choose by publication time instead.
            releases.sort(key=lambda release: release.get("published_at") or "", reverse=True)
            for release in releases:
                selected = release_sources(release)
                if selected:
                    break
            if selected or not releases:
                break
    if not selected:
        parser.error("No complete nightly with desktop and CLI assets for both Linux architectures")
    contents = json.dumps(selected, indent=2) + "\n"
    if args.output.exists() and args.output.read_text() == contents:
        print(f"Already pinned to {selected['version']}")
        return
    # Replace only after all four artifacts and checksums have been validated.
    with tempfile.NamedTemporaryFile(mode="w", dir=args.output.parent, delete=False) as temporary:
        temporary.write(contents)
        temporary_path = Path(temporary.name)
    temporary_path.chmod(0o644)
    temporary_path.replace(args.output)
    print(f"Pinned T3 Code nightly {selected['version']} in {args.output}")


if __name__ == "__main__":
    main()

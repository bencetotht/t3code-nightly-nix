# t3code-nightly-nix

Nix flake packaging the official [T3 Code](https://t3.codes) nightly builds
(desktop app + standalone CLI) for `x86_64-linux` and `aarch64-linux`.

> **Disclaimer:** this is an unofficial, community-maintained packaging repo.
> All credit for T3 Code goes to the [T3 Code](https://github.com/pingdotgg/t3code)
> developers and the team at [Ping](https://ping.gg). This flake only repackages
> their official release binaries for Nix and is not affiliated with or endorsed
> by them. Please report app bugs upstream; packaging issues belong here.

## Usage

```bash
nix run github:bencetotht/t3code-nightly-nix          # desktop
nix run github:bencetotht/t3code-nightly-nix#t3       # CLI
```

As a flake input:

```nix
inputs.t3code-nightly.url = "github:bencetotht/t3code-nightly-nix";
# then either
environment.systemPackages = [ inputs.t3code-nightly.packages.${system}.t3code-nightly ];
# or
nixpkgs.overlays = [ inputs.t3code-nightly.overlays.default ];  # provides pkgs.t3code-nightly
```

The package provides `t3code-desktop` (alias `t3code-nightly`), `t3` (alias
`t3-nightly`) and a **T3 Code (Nightly)** desktop entry.

## Updates

Nightlies are pinned in `pkgs/t3code-nightly/sources.json`, independently of
nixpkgs, with SHA-256 hashes for the four Linux artifacts. The
[Update nightly](.github/workflows/update.yml) workflow runs daily, builds the
new pin and pushes it to `main`. Trigger it manually with:

```bash
gh workflow run update.yml                                   # newest nightly
gh workflow run update.yml -f tag=v0.0.46-nightly.20261005.2702
```

Or locally from the repository root:

```bash
nix run .#update                 # optionally: -- --tag vX.Y.Z-nightly.YYYYMMDD.N
nix build
```

The updater skips drafts, stable/preview releases and releases missing any of
the four Linux artifacts. CLI hashes come from upstream `SHA256SUMS`, desktop
hashes from GitHub release asset metadata; Nix verifies the downloaded bytes.
Set `GH_TOKEN` if the unauthenticated GitHub API rate limit is hit.

The Nix store is immutable, so the desktop auto-updater and `t3 update` cannot
replace this installation — update the pin instead.

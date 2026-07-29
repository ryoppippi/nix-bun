# nix-bun

A Nix flake that provides pre-built Bun binaries from official GitHub releases.

This flake downloads upstream release archives directly from `oven-sh/bun`.

## Getting Started

```bash
# Run the latest version
nix run github:ryoppippi/nix-bun

# Run a specific version
nix run 'github:ryoppippi/nix-bun#"1.3.12"'

# Run explicit package attributes
nix run github:ryoppippi/nix-bun#bun

# Run the latest canary build
nix run github:ryoppippi/nix-bun#canary
```

## Features

- ✅ Automatic updates via GitHub Actions
- ✅ Canary builds from Bun's rolling `canary` tag
- ✅ Multi-platform support: Linux (x86_64, aarch64) and macOS (x86_64, aarch64)
- ✅ Direct downloads from official Bun GitHub releases
- ✅ SHA256 verification using release asset digests
- ✅ Flake and non-flake support
- ✅ Binary cache via [Cachix](https://app.cachix.org/cache/ryoppippi) for faster builds

## Why Use This Flake?

`nixpkgs` already provides Bun, but this flake tracks the official pre-built release binaries directly from upstream.

Use this if you want:

- the exact binaries published by the Bun project
- faster packaging updates driven by GitHub Releases
- simple installation without rebuilding Bun from source

## Binary Cache (Cachix)

This flake provides pre-built binaries via [Cachix](https://app.cachix.org/cache/ryoppippi). Using the binary cache avoids rebuilding packages locally and significantly speeds up installation.

### Setup Cachix

**Option 1: Using Cachix CLI**

```bash
cachix use ryoppippi
```

**Option 2: Manual Configuration**

Add to your Nix configuration:

```nix
# NixOS (configuration.nix)
nix.settings = {
  substituters = [ "https://ryoppippi.cachix.org" ];
  trusted-public-keys = [ "ryoppippi.cachix.org-1:b2LbtWNvJeL/qb1B6TYOMK+apaCps4SCbzlPRfSQIms=" ];
};

# Or in ~/.config/nix/nix.conf
# extra-substituters = https://ryoppippi.cachix.org
# extra-trusted-public-keys = ryoppippi.cachix.org-1:b2LbtWNvJeL/qb1B6TYOMK+apaCps4SCbzlPRfSQIms=
```

**Option 3: In your flake.nix**

```nix
{
  nixConfig = {
    extra-substituters = [ "https://ryoppippi.cachix.org" ];
    extra-trusted-public-keys = [ "ryoppippi.cachix.org-1:b2LbtWNvJeL/qb1B6TYOMK+apaCps4SCbzlPRfSQIms=" ];
  };
}
```

**Option 4: Using devenv**

```nix
{
  cachix.pull = [ "ryoppippi" ];
}
```

## Usage

### Quick Start

```bash
nix run github:ryoppippi/nix-bun

nix shell github:ryoppippi/nix-bun
bun --version
```

### With Flakes

Add the input to your flake:

```nix
{
  inputs = {
    nix-bun.url = "github:ryoppippi/nix-bun";
  };
}
```

Then use `nix-bun.packages.${system}.default` directly, or add the overlay and reference `pkgs.bun`.

The flake provides both direct package outputs and overlay attributes:

- `nix-bun.packages.${system}.bun`
- `pkgs.bun`
- `pkgs.bun-bin`

#### Add to devShell

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-bun.url = "github:ryoppippi/nix-bun";
  };

  outputs = { nixpkgs, nix-bun, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = [
              nix-bun.packages.${system}.default
            ];
          };
        }
      );
    };
}
```

#### Using the overlay

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-bun.url = "github:ryoppippi/nix-bun";
  };

  outputs = { nixpkgs, nix-bun, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ nix-bun.overlays.default ];
          };
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.bun
            ];
          };
        }
      );
    };
}
```

#### Add to devenv

```bash
devenv inputs add nix-bun github:ryoppippi/nix-bun
```

```yaml
inputs:
  nix-bun:
    url: github:ryoppippi/nix-bun
```

```nix
{ pkgs, inputs, ... }:
{
  packages = [
    inputs.nix-bun.packages.${pkgs.system}.default
  ];

  cachix.pull = [ "ryoppippi" ];
}
```

### Without Flakes

```nix
let
  nix-bun = import (builtins.fetchTarball {
    url = "https://github.com/ryoppippi/nix-bun/archive/main.tar.gz";
  });
  pkgs = import <nixpkgs> {
    overlays = [ nix-bun.overlays.default ];
  };
in
  pkgs.bun
```

## Version Pinning

You can install a specific version of Bun by using versioned package attributes:

```nix
nix-bun.packages.${system}."1.3.12"
nix-bun.packages.${system}.default
```

```bash
nix run 'github:ryoppippi/nix-bun#"1.3.12"'
```

All tracked versions are available in the [`versions/`](./versions) directory.

## Canary

The `canary` attribute tracks Bun's [rolling `canary` release](https://github.com/oven-sh/bun/releases/tag/canary), built from `main`:

```bash
nix run github:ryoppippi/nix-bun#canary
nix shell github:ryoppippi/nix-bun#canary
```

```nix
nix-bun.packages.${system}.canary
```

Two caveats apply because `canary` is a rolling tag rather than an immutable release:

- Upstream replaces the assets on every build, so the pinned hashes in [`versions/canary.json`](./versions/canary.json) go stale within hours. A build against outdated hashes fails with a hash mismatch — refresh the flake input (`nix flake update nix-bun`) to pick up the latest hourly update.
- Canary binaries report the unreleased base version (for example `1.4.0`), so the package version carries the snapshot date instead: `1.4.0-unstable-2026-07-29`. Use `bun --revision` to identify the exact commit.

`canary` is never selected as the default package; `default` and `bun` always point at the latest stable release.

## How It Works

1. `update.ts` queries the official GitHub Releases API.
2. It reads release asset digests and converts them to SRI hashes.
3. GitHub Actions updates `versions/*.json`.
4. The flake installs the upstream release archive and exposes `bun`.

For `canary`, the version reported by the binaries cannot be derived from the tag, so it is read from `package.json` on Bun's `main` branch.

For x86_64 Linux and macOS, this flake uses Bun's `-baseline` assets for broader CPU compatibility.

## Supported Platforms

- `x86_64-linux`
- `aarch64-linux`
- `x86_64-darwin`
- `aarch64-darwin`

## Development

Development tooling is separated into `dev/flake.nix` to keep the consumer flake minimal.

### Setup development environment

**Option 1: Using direnv**

```bash
direnv allow
```

**Option 2: Manual**

```bash
nix develop ./dev
```

### Update sources manually

```bash
nix develop ./dev
./update.ts
```

### Test the build

```bash
nix build
./result/bin/bun --version
```

### Run checks manually

```bash
nix fmt ./dev
nix flake check ./dev
```

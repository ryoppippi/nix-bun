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
```

## Features

- ✅ Automatic updates via GitHub Actions
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

## How It Works

1. `update.ts` queries the official GitHub Releases API.
2. It reads release asset digests and converts them to SRI hashes.
3. GitHub Actions updates `versions/*.json`.
4. The flake installs the upstream release archive and exposes `bun`.

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

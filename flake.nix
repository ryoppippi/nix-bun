{
  description = "Bun CLI binaries from official GitHub releases.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
    }:
    let
      systems = import ./systems.nix;
      forAllSystems = nixpkgs.lib.genAttrs systems;

      versionFiles = builtins.readDir ./versions;
      versionNames = builtins.map (f: nixpkgs.lib.removeSuffix ".json" f) (
        builtins.filter (f: nixpkgs.lib.hasSuffix ".json" f) (builtins.attrNames versionFiles)
      );
      # "canary" tracks a rolling prerelease tag, so it is not comparable with
      # the semver releases and must never be selected as the default package.
      releaseNames = builtins.filter (v: v != "canary") versionNames;
      latestVersion = builtins.head (builtins.sort (a: b: builtins.compareVersions a b > 0) releaseNames);
      latestSourcesFile = ./versions/${latestVersion + ".json"};

      mkBun = pkgs: sourcesFile: pkgs.callPackage ./package.nix { inherit sourcesFile; };
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
          };

          versionedPackages = builtins.listToAttrs (
            builtins.map (version: {
              name = version;
              value = mkBun pkgs ./versions/${version + ".json"};
            }) versionNames
          );
        in
        {
          bun = mkBun pkgs latestSourcesFile;
          default = self.packages.${system}.bun;
        }
        // versionedPackages
      );

      # Build from the consumer's `final` rather than `self.packages`: the latter
      # instantiates this flake's own nixpkgs, which every overlay user would
      # then evaluate a second time.
      overlays.default = final: _prev: {
        bun = mkBun final latestSourcesFile;
      };
    };
}

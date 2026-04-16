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
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      versionFiles = builtins.readDir ./versions;
      versionNames = builtins.map (f: nixpkgs.lib.removeSuffix ".json" f) (
        builtins.filter (f: nixpkgs.lib.hasSuffix ".json" f) (builtins.attrNames versionFiles)
      );
      latestVersion = builtins.head (builtins.sort (a: b: builtins.compareVersions a b > 0) versionNames);
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
          };

          mkBun = sourcesFile: pkgs.callPackage ./package.nix { inherit sourcesFile; };

          versionedPackages = builtins.listToAttrs (
            builtins.map (version: {
              name = version;
              value = mkBun ./versions/${version + ".json"};
            }) versionNames
          );

          latestSourcesFile = ./versions/${latestVersion + ".json"};
        in
        {
          bun = mkBun latestSourcesFile;
          default = self.packages.${system}.bun;
        }
        // versionedPackages
      );

      overlays.default = _final: prev: {
        bun = self.packages.${prev.stdenv.hostPlatform.system}.bun;
      };
    };
}

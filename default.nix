{
  pkgs,
  sourcesFile ? (
    let
      inherit (pkgs) lib;
      versionFiles = builtins.readDir ./versions;
      versionNames = builtins.map (f: lib.removeSuffix ".json" f) (
        builtins.filter (f: lib.hasSuffix ".json" f) (builtins.attrNames versionFiles)
      );
      # "canary" tracks a rolling prerelease tag, so it is not comparable with
      # the semver releases and must never be selected as the default package.
      releaseNames = builtins.filter (v: v != "canary") versionNames;
      latestVersion = builtins.head (builtins.sort (a: b: builtins.compareVersions a b > 0) releaseNames);
    in
    ./versions/${latestVersion + ".json"}
  ),
  ...
}:
pkgs.callPackage ./package.nix { inherit sourcesFile; }

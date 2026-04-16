{
  lib,
  stdenv,
  fetchurl,
  unzip,
  autoPatchelfHook,
  zlib,
  sourcesFile,
}:
let
  sourcesData = lib.importJSON sourcesFile;
  inherit (sourcesData) version;
  sources = sourcesData.platforms;

  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation rec {
  pname = "bun";
  inherit version;

  src = fetchurl {
    inherit (source) url hash;
  };

  nativeBuildInputs = [ unzip ] ++ lib.optionals stdenv.isLinux [ autoPatchelfHook ];

  buildInputs = lib.optionals stdenv.isLinux [
    stdenv.cc.cc.lib
    zlib
  ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    unzip -q "$src"
    install -Dm755 bun-*/bun "$out/bin/bun"
    ln -s "$out/bin/bun" "$out/bin/bunx"

    runHook postInstall
  '';

  dontStrip = true;

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    version_output="$($out/bin/bun --version)"
    if [ "$version_output" != "${version}" ]; then
      echo "ERROR: expected version ${version}, got $version_output"
      exit 1
    fi

    bunx_version_output="$($out/bin/bunx --version)"
    if [ "$bunx_version_output" != "${version}" ]; then
      echo "ERROR: expected bunx version ${version}, got $bunx_version_output"
      exit 1
    fi

    runHook postInstallCheck
  '';

  passthru = {
    updateScript = ./update.ts;
  };

  meta = with lib; {
    inherit version;
    description = "Fast JavaScript runtime, package manager, test runner, and bundler";
    homepage = "https://bun.sh";
    downloadPage = "https://github.com/oven-sh/bun/releases";
    changelog = "https://github.com/oven-sh/bun/releases";
    license = licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "bun";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    maintainers = [ ];
  };
}

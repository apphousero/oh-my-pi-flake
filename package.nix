{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
}:

let
  pname = "oh-my-pi";
  version = "17.2.12";

  sources = {
    x86_64-linux = {
      asset = "omp-linux-x64";
      hash = "sha256-bHUzG/CdWp6UM71ZKz7pk9dRoV1bdFDBozTMBoSZbzA=";
    };
    aarch64-linux = {
      asset = "omp-linux-arm64";
      hash = "sha256-8Xbt+BdNslKr4apuhN8oThuDuN1+80rH+veISl4XKkw=";
    };
    x86_64-darwin = {
      asset = "omp-darwin-x64";
      hash = "sha256-7eUWJYc7t+WSAHEevkS3dZGaGLRv6SeZWkH5MVqclqo=";
    };
    aarch64-darwin = {
      asset = "omp-darwin-arm64";
      hash = "sha256-q0/yTIujrm/Z1LVJaclPRAjMMWZ19VNHKa5QLYyX33Q=";
    };
  };

  inherit (stdenvNoCC.hostPlatform) system;

  source =
    sources.${system}
      or (throw "oh-my-pi: no prebuilt binary for system '${system}'; supported: ${lib.concatStringsSep ", " (lib.attrNames sources)}");
in
stdenvNoCC.mkDerivation {
  inherit pname version;

  src = fetchurl {
    url = "https://github.com/can1357/oh-my-pi/releases/download/v${version}/${source.asset}";
    inherit (source) hash;
  };

  dontUnpack = true;
  dontStrip = true;
  dontPatchELF = true;

  nativeBuildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [ autoPatchelfHook ];

  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/bin/omp
    runHook postInstall
  '';

  doInstallCheck = true;

  installCheckPhase = ''
    runHook preInstallCheck
    export HOME=$(mktemp -d)
    actual=$($out/bin/omp --version)
    if [ "$actual" != "omp/${version}" ]; then
      echo "version mismatch: expected 'omp/${version}', got '$actual'" >&2
      exit 1
    fi
    $out/bin/omp --smoke-test
    runHook postInstallCheck
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "AI coding agent for the terminal";
    homepage = "https://github.com/can1357/oh-my-pi";
    downloadPage = "https://github.com/can1357/oh-my-pi/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "omp";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = lib.attrNames sources;
  };
}

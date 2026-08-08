{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
}:

let
  pname = "oh-my-pi";
  version = "17.2.10";

  sources = {
    x86_64-linux = {
      asset = "omp-linux-x64";
      hash = "sha256-T+VksjSCzWJ2caJBeEJJjJey9ytfijpO+4CU5iPfejM=";
    };
    aarch64-linux = {
      asset = "omp-linux-arm64";
      hash = "sha256-yTXV0l62d6Ylk0+B9LIbD/BbZEAP656Q8C8O/jlnY4Y=";
    };
    x86_64-darwin = {
      asset = "omp-darwin-x64";
      hash = "sha256-IGR/4Zqy5HRRZVXbXIE/XZrv/FVuRWzfnuiQB8ipi+8=";
    };
    aarch64-darwin = {
      asset = "omp-darwin-arm64";
      hash = "sha256-43+j1NPusVtx1bRk/eUfkT45CXikjcM7TFJ7ju1yN8Y=";
    };
  };

  inherit (stdenvNoCC.hostPlatform) system;

  source =
    sources.${system}
      or (throw "oh-my-pi: no prebuilt binary for system '${system}'; supported: ${
        lib.concatStringsSep ", " (lib.attrNames sources)
      }");
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

  meta = {
    description = "AI coding agent for the terminal";
    homepage = "https://github.com/can1357/oh-my-pi";
    downloadPage = "https://github.com/can1357/oh-my-pi/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "omp";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = lib.attrNames sources;
    maintainers = [ ];
  };
}

{
  lib,
  pkgs,
  runCommand,
  hello,
  hmModule,
}:

let
  stubHomeManager = {
    options.home = {
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
      };
      file = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options.source = lib.mkOption { type = lib.types.path; };
          }
        );
        default = { };
      };
    };
    config._module.args.pkgs = pkgs;
  };

  eval =
    module:
    (lib.evalModules {
      modules = [
        stubHomeManager
        hmModule
        module
      ];
    }).config;

  disabled = eval { programs.oh-my-pi.package = hello; };

  bare = eval {
    programs.oh-my-pi = {
      enable = true;
      package = hello;
    };
  };

  configured = eval {
    programs.oh-my-pi = {
      enable = true;
      package = hello;
      settings = {
        theme.dark = "titanium";
        cycleOrder = [
          "smol"
          "default"
        ];
      };
    };
  };

  configFile = configured.home.file.".omp/agent/config.yml".source;
in
runCommand "oh-my-pi-module-test"
  {
    inherit configFile;
    disabledPackages = builtins.length disabled.home.packages;
    disabledFiles = builtins.length (builtins.attrNames disabled.home.file);
    barePackage = lib.getExe' (builtins.head bare.home.packages) "hello";
    bareFiles = builtins.length (builtins.attrNames bare.home.file);
  }
  ''
    [ "$disabledPackages" = 0 ] || { echo "disabled module still installs packages"; exit 1; }
    [ "$disabledFiles" = 0 ] || { echo "disabled module still manages files"; exit 1; }

    [ "$barePackage" = "${lib.getExe' hello "hello"}" ] || { echo "wrong package installed"; exit 1; }
    [ "$bareFiles" = 0 ] || { echo "empty settings must leave config.yml unmanaged"; exit 1; }

    grep -q '^  dark: titanium$' "$configFile" || { echo "nested settings not rendered"; cat "$configFile"; exit 1; }
    grep -q '^- smol$' "$configFile" || { echo "list settings not rendered"; cat "$configFile"; exit 1; }

    touch $out
  ''

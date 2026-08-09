{
  description = "oh-my-pi (omp), an AI coding agent for the terminal: package, overlay, and Home Manager module";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: {
        oh-my-pi = pkgs.callPackage ./package.nix { };
        default = self.packages.${pkgs.stdenv.hostPlatform.system}.oh-my-pi;
      });

      checks = forAllSystems (pkgs: {
        package = self.packages.${pkgs.stdenv.hostPlatform.system}.oh-my-pi;

        module = pkgs.callPackage ./tests/module.nix { };

        formatting =
          pkgs.runCommand "check-formatting"
            {
              nativeBuildInputs = [ pkgs.nixfmt ];
            }
            ''
              nixfmt --check $(find ${self} -name '*.nix')
              touch $out
            '';
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);

      apps = forAllSystems (pkgs: rec {
        update = {
          type = "app";
          program = lib.getExe (
            pkgs.writeShellApplication {
              name = "oh-my-pi-update";
              runtimeInputs = with pkgs; [
                bash
                cacert
                coreutils
                curl
                gawk
                gnused
                jq
              ];
              text = ''exec ${./update.sh} "$@"'';
            }
          );
          meta.description = "Rewrite package.nix for the latest upstream release";
        };
        default = update;
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            curl
            deadnix
            jq
            nil
            nixfmt
            statix
          ];
        };
      });

      homeManagerModules.default = import ./module.nix;

      overlays.default = final: _prev: {
        oh-my-pi = final.callPackage ./package.nix { };
      };
    };
}

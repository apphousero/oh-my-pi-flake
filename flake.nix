{
  description = "oh-my-pi AI coding agent - Nix flake for Home Manager integration";

  inputs.nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system: rec {
        oh-my-pi = nixpkgs.legacyPackages.${system}.callPackage ./package.nix { };
        default = oh-my-pi;
      });

      devShells = forAllSystems (system: {
        default = nixpkgs.legacyPackages.${system}.mkShell {
          packages = [ self.packages.${system}.default ];
        };
      });

      homeManagerModules.default = import ./module.nix;

      overlays.default = final: _prev: {
        oh-my-pi = final.callPackage ./package.nix { };
      };
    };
}

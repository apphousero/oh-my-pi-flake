{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.services.oh-my-pi;
in
{
  options.services.oh-my-pi = {
    enable = lib.mkEnableOption "oh-my-pi AI coding agent";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.oh-my-pi or (pkgs.callPackage ./package.nix { });
      defaultText = lib.literalExpression "pkgs.oh-my-pi";
      description = "The oh-my-pi package to use";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];
  };
}

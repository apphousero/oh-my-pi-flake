{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.programs.oh-my-pi;
  yaml = pkgs.formats.yaml { };
in
{
  options.programs.oh-my-pi = {
    enable = lib.mkEnableOption "oh-my-pi, an AI coding agent for the terminal";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.oh-my-pi or (pkgs.callPackage ./package.nix { });
      defaultText = lib.literalExpression "pkgs.oh-my-pi, or this flake's package when the overlay is not applied";
      description = "The oh-my-pi package to install. Provides the `omp` binary.";
    };

    settings = lib.mkOption {
      inherit (yaml) type;
      default = { };
      example = lib.literalExpression ''
        {
          theme.dark = "titanium";
          defaultThinkingLevel = "high";
          tools.approvalMode = "write";
        }
      '';
      description = ''
        Global `omp` settings, written to {file}`~/.omp/agent/config.yml`.

        Left empty, the file is not managed and `omp` owns it. Set it, and the
        file becomes a read-only store symlink: {command}`omp config set` and
        the interactive `/settings` panel can no longer persist changes.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    home.file = lib.mkIf (cfg.settings != { }) {
      ".omp/agent/config.yml".source = yaml.generate "omp-config.yml" cfg.settings;
    };
  };
}

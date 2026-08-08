# `Oh My Pi` flake

Packages [oh-my-pi](https://github.com/can1357/oh-my-pi/) (an AI-powered coding agent for the terminal) for NixOS and Home Manager.

Inspired by [omp-flake](https://github.com/clairesrc/omp-flake).

## Try it

```console
$ nix run github:apphousero/omp -- --version
```

## Flake input

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    omp = {
      url = "github:apphousero/omp";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
```

The `follows` line is optional: the Home Manager module and the overlay build
against your own `pkgs`, so this flake's `nixpkgs` pin only affects
`nix build`/`nix run`/`nix develop` on this repo directly.

## Home Manager module

```nix
{ inputs, ... }:
{
  imports = [ inputs.omp.homeManagerModules.default ];

  services.oh-my-pi.enable = true;
}
```

Exposes `services.oh-my-pi.package` if you need to override the derivation; the
binary is installed as `omp`.

## Without the module

```nix
{ inputs, pkgs, ... }:
{
  home.packages = [ inputs.omp.packages.${pkgs.stdenv.hostPlatform.system}.default ];
}
```

## Overlay

An overlay adds `pkgs.oh-my-pi` — it is not a module, so it goes in
`nixpkgs.overlays`, not `imports`.

```nix
{ inputs, pkgs, ... }:
{
  nixpkgs.overlays = [ inputs.omp.overlays.default ];

  home.packages = [ pkgs.oh-my-pi ];
}
```

With Home Manager as a NixOS module and `home-manager.useGlobalPkgs = true`, set
the overlay on the system `nixpkgs.overlays` instead.

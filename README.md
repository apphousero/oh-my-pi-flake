# `Oh My Pi` flake

Packages [oh-my-pi](https://github.com/can1357/oh-my-pi/) (an AI-powered coding agent for the terminal) as a Nix
package, an overlay, and a Home Manager module. The binary is installed as `omp`.

Prebuilt upstream release binaries, hash-pinned — this flake does not compile `omp` from source.

Inspired by [omp-flake](https://github.com/clairesrc/omp-flake).

## Try it

```console
$ nix run github:apphousero/oh-my-pi-flake -- --version
```

## Flake input

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    omp = {
      url = "github:apphousero/oh-my-pi-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
```

The `follows` line is optional: the Home Manager module and the overlay build against your own `pkgs`, so this
flake's `nixpkgs` pin only affects `nix build`/`nix run`/`nix develop` on this repo directly.

## Home Manager module

```nix
{ inputs, ... }:
{
  imports = [ inputs.omp.homeManagerModules.default ];

  programs.oh-my-pi.enable = true;
}
```

### Declarative settings

`programs.oh-my-pi.settings` is written to `~/.omp/agent/config.yml`, the global settings file. Any key from
`omp config list` works; nesting maps onto dotted setting paths.

```nix
{
  programs.oh-my-pi = {
    enable = true;
    settings = {
      theme.dark = "titanium";
      defaultThinkingLevel = "high";
      tools.approvalMode = "write";
    };
  };
}
```

Leave `settings` unset and the file stays unmanaged. Set it and the file becomes a read-only store symlink, so
`omp config set` and the interactive `/settings` panel can no longer persist changes — that is the trade for
declarative config, not a bug. Project-local `<repo>/.omp/config.yml` still overrides it.

`programs.oh-my-pi.package` overrides the derivation.

## Without the module

```nix
{ inputs, pkgs, ... }:
{
  home.packages = [ inputs.omp.packages.${pkgs.stdenv.hostPlatform.system}.default ];
}
```

## Overlay

An overlay adds `pkgs.oh-my-pi` — it is not a module, so it goes in `nixpkgs.overlays`, not `imports`. This is also
the NixOS path; there is no NixOS module, because a system-wide install is one line.

```nix
{ inputs, pkgs, ... }:
{
  nixpkgs.overlays = [ inputs.omp.overlays.default ];

  environment.systemPackages = [ pkgs.oh-my-pi ]; # or home.packages under Home Manager
}
```

With Home Manager as a NixOS module and `home-manager.useGlobalPkgs = true`, set the overlay on the system
`nixpkgs.overlays`.

## Updating the pinned release

`update.sh` rewrites `version` and every asset hash in `package.nix` from the release's published
`SHA256SUMS.txt` — no multi-hundred-megabyte prefetch:

```console
$ nix run .#update           # latest release
$ nix run .#update -- 17.2.9 # a specific one
```

A scheduled workflow runs it daily, builds the result on every supported system, and only then opens a PR.

## Checks

`nix flake check` builds the package (its `installCheck` asserts `omp --version` and runs `omp --smoke-test`),
evaluates the Home Manager module against a stub, and verifies formatting. `nix fmt` formats the tree; `nix develop`
provides the Nix toolchain.

CI runs the same `nix flake check` on `x86_64-linux`, `aarch64-linux`, and `aarch64-darwin`. `x86_64-darwin` is not
supported — nixpkgs is retiring the platform; use Rosetta.

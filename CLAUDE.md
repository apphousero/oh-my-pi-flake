# omp

Nix flake packaging [`can1357/oh-my-pi`](https://github.com/can1357/oh-my-pi) (`omp`) as a package, an overlay, and a Home Manager module. That repo is the source of releases and assets; for questions about how `omp` itself works, consult [deepwiki.com/can1357/oh-my-pi](https://deepwiki.com/can1357/oh-my-pi) rather than the official docs.

| File | Purpose |
| --- | --- |
| `package.nix` | The derivation. Version and per-platform asset hashes live here. |
| `flake.nix` | Outputs: `packages`, `checks`, `formatter`, `apps.update`, `devShells`, `overlays.default`, `homeManagerModules.default`. |
| `module.nix` | Home Manager module: `programs.oh-my-pi.{enable,package,settings}`. |
| `tests/module.nix` | Evaluates `module.nix` against a stub Home Manager and asserts the rendered `config.yml`. |
| `update.sh` | Rewrites version + hashes in `package.nix`. Exposed as `nix run .#update`. |

There is no NixOS module by design: the overlay plus `environment.systemPackages` is the whole story, and a second `enable`/`package` module would add API surface for nothing.

## Packaging model: prebuilt binaries, not a source build

`package.nix` fetches the official per-platform release asset and runs `autoPatchelfHook` on it. It does **not** compile from source.

Do not "restore" the source build. It was removed deliberately, and each of these was reproduced before the decision:

1. Upstream deleted the root `build:native` script. Natives now build through `packages/natives run build`, which drives **Bazel** (`scripts/bazel-natives.ts`), downloading hermetic zig and Rust toolchains at build time.
2. The cargo fallback (`packages/natives run build:bindings`) is broken outside Bazel. `audiopus_sys` installs `libopus.a` to `<prefix>/lib64` while its `build.rs` links `<prefix>/lib`. Upstream fixes this only inside their Bazel toolchain, via `bazel/patches/audiopus-sys-libdir.patch`.
3. `pi-natives` uses `#![feature(alloc_error_hook)]`, so it needs the exact nightly pinned in upstream `rust-toolchain.toml`, not `rust-bin.nightly.latest`.
4. Blocking: upstream requires Bun `>= 1.3.14`; nixpkgs ships `1.3.13`. A binary compiled with `1.3.13` embeds that runtime and refuses to start with `error: Bun runtime must be >= 1.3.14`. A source build cannot produce a working `omp` without also vendoring a Bun derivation.

Two consequences worth preserving:

- The derivation is pure. There is no `__noChroot`, so **`--option sandbox relaxed` is not needed**. If you ever find yourself adding `__noChroot` back, something has gone wrong.
- `flake.nix` has no `rust-overlay` input. Do not re-add one.

## Updating to a new version

Run the script. It is idempotent and safe to run on an already-current tree:

```sh
nix run .#update            # latest release
nix run .#update -- 17.2.9  # a specific version
```

It resolves the tag, downloads the release's `SHA256SUMS.txt` (a few hundred bytes), converts the hex digests to SRI with `basenc`, and rewrites `version` plus all four `hash` fields in `package.nix`. A missing asset name is a hard error that prints the release's actual asset list — upstream has renamed assets before.

Do **not** go back to `nix store prefetch-file` on the four assets: that downloads roughly 600 MB to recompute digests upstream already publishes. The published sums were verified byte-identical to the previously hand-prefetched hashes.

`.github/workflows/update.yml` runs this daily, and opens a PR when `package.nix` changes. `.github/workflows/check.yml` then runs `nix flake check` on all four systems.

The `musl`, `windows`, and `browser-relay-extension` assets are intentionally unpackaged.

### Verifying a bump

```sh
nix flake check -L                              # package build + module test + formatting
nix build .#oh-my-pi --no-link --rebuild        # reproducibility
nix run .#oh-my-pi -- --version                 # expect omp/<version>
```

`nix flake check` is meaningful here only because `checks.<system>.package` aliases the real derivation. A wrong hash fails at fetch time with `hash mismatch`; a wrong asset name fails with a 404; a stale `version` fails the `installCheck` assertion. All three surface immediately.

`nix flake check` covers the host system only. `--all-systems` tries to *build* the others and will fail off-platform; to check that the other systems still evaluate, use `nix eval .#packages.<system>.oh-my-pi.drvPath`.

For a full end-to-end check that the package composes into a system closure, build a throwaway NixOS `system-path` with the overlay applied. That is the derivation that fails first in a real `nixos-rebuild`.

## Gotchas

- **`installCheck` needs a writable `HOME`.** `omp` extracts its embedded native addon to `$HOME/.omp/natives/<version>/` on first run. Without `export HOME=$(mktemp -d)` the check dies on `EACCES ... '/homeless-shelter'`. Keep that line.
- **The extracted `.node` is not patchelf'd.** It is unpacked at runtime, after the build, so `autoPatchelfHook` never sees it. This is fine only because it links nothing beyond glibc. If a future release makes that addon depend on more libraries, it will fail at runtime while the build still passes; a wrapper setting `LD_LIBRARY_PATH` would then be required.
- **Untracked files are invisible to `nix flake check`.** The flake source is the git tree, so a new file must be `git add`-ed before `checks` can see it — otherwise `./tests/module.nix` and friends fail with "path does not exist".
- **`programs.oh-my-pi.settings` fights `omp config set`.** A managed `~/.omp/agent/config.yml` is a read-only store symlink; runtime persistence then fails. That is why the option defaults to `{}` and leaves the file unmanaged.
- **`x86_64-darwin` is being retired by nixpkgs, and the symptom depends on the pin.** On `nixos-26.05` it evaluates and only emits a deprecation warning. On nixpkgs 26.11 and later the platform is gone and evaluating that system is a hard error. This is why the input is pinned to a stable branch rather than `nixos-unstable`. The entry is kept because the upstream asset exists; CI marks that matrix leg `continue-on-error`.
- **Do not add `stdenv.cc.cc.libgcc`** to `buildInputs`. It was tested and is unnecessary; glibc arrives via stdenv.
- **Hashes are SRI (`sha256-...`), not raw hex.** `update.sh` handles the conversion.

## Style

Per the user's global instruction: no comments in Nix source. If one is genuinely unavoidable, keep it to a single line. Explanatory context belongs in this file or in the commit message. Run `nix fmt` before committing; `checks.formatting` enforces it.
